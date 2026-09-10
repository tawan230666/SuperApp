import express from "express";
import { z } from "zod";
import { transaction, type PoolClient } from "@tipkhun/database";
import { authenticate, audit, HttpError } from "@tipkhun/auth";
import {
  persistedMinorSchema as minor,
  investmentPlanSchema as planSchema,
  persistedRiskProfileSchema as profileSchema,
} from "@tipkhun/contracts";
export { minor, planSchema, profileSchema };
const planSelect =
  'SELECT p.id AS "planId", v.id AS "versionId",v.version,v.capital_minor AS "capitalMinor",v.daily_loss_limit_minor AS "dailyLossLimitMinor",v.risk_per_trade_minor AS "riskPerTradeMinor",v.max_trades AS "maxTrades",v.effective_at AS "effectiveAt" FROM investment_plans p JOIN plan_versions v ON v.plan_id=p.id WHERE p.user_id=$1 ORDER BY v.version DESC LIMIT 1';
export async function currentPlan(c: PoolClient, userId: string) {
  return (await c.query(planSelect, [userId])).rows[0] ?? null;
}
async function lockOwner(c: PoolClient, id: string) {
  await c.query("SELECT id FROM users WHERE id=$1 FOR UPDATE", [id]);
}
export async function snapshot(c: PoolClient, userId: string) {
  await c.query("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ");
  await lockOwner(c, userId);
  const p = await currentPlan(c, userId);
  if (!p) throw new HttpError(404, "Create your first risk plan");
  const a = await c.query(
    "SELECT count(*)::int AS count,coalesce(bool_or(emergency_stop),false) AS stopped FROM accounts WHERE user_id=$1 AND environment IN ('simulation','paper')",
    [userId],
  );
  if (!a.rows[0].count) throw new HttpError(409, "Simulation account required");
  const t = await c.query(
    "SELECT coalesce(sum(GREATEST(-t.net_pnl_minor,0)),0)::text AS used,count(*)::int AS trades FROM trades t JOIN accounts a ON a.id=t.account_id WHERE a.user_id=$1 AND a.environment IN ('simulation','paper') AND t.created_at >= date_trunc('day',now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC'",
    [userId],
  );
  const r = await c.query(
    "SELECT coalesce(sum(o.requested_risk_minor),0)::text AS reserved,count(*)::int AS pending FROM orders o JOIN accounts a ON a.id=o.account_id WHERE a.user_id=$1 AND a.environment IN ('simulation','paper') AND o.state NOT IN ('FILLED','CANCELLED','REJECTED','EXPIRED','filled','cancelled','rejected','expired')",
    [userId],
  );
  const pos = await c.query(
    "SELECT count(*)::int AS count FROM positions p JOIN accounts a ON a.id=p.account_id WHERE a.user_id=$1 AND a.environment IN ('simulation','paper') AND p.state NOT IN ('CLOSED','closed')",
    [userId],
  );
  const profile = (
    await c.query(
      "SELECT max_positions,max_drawdown_bps FROM risk_profiles WHERE user_id=$1",
      [userId],
    )
  ).rows[0];
  if (!profile?.max_positions)
    throw new HttpError(409, "Complete your risk profile");
  const equityResult = await c.query(
    `WITH ledger AS (SELECT t.id,t.created_at,sum(t.net_pnl_minor) OVER (ORDER BY t.created_at,t.id) AS pnl FROM trades t JOIN accounts a ON a.id=t.account_id WHERE a.user_id=$1 AND a.environment IN ('simulation','paper')) SELECT coalesce((SELECT pnl FROM ledger ORDER BY created_at DESC,id DESC LIMIT 1),0)::text AS pnl,coalesce(max(pnl),0)::text AS peak FROM ledger`,
    [userId],
  );
  const capital = BigInt(p.capitalMinor),
    equity = capital + BigInt(equityResult.rows[0].pnl),
    peakPnl = BigInt(equityResult.rows[0].peak),
    peak = capital + (peakPnl > 0n ? peakPnl : 0n);
  const drawdownReached =
    (peak - equity) * 10000n >= peak * BigInt(profile.max_drawdown_bps);
  const used = BigInt(t.rows[0].used),
    reserved = BigInt(r.rows[0].reserved),
    limit = BigInt(p.dailyLossLimitMinor);
  const budget = equity < limit ? equity : limit;
  const remaining = budget - used - reserved;
  const tradesUsed = t.rows[0].trades + r.rows[0].pending;
  return {
    ...p,
    equityMinor: equity.toString(),
    drawdownReached,
    riskUsedMinor: used.toString(),
    riskReservedMinor: reserved.toString(),
    riskRemainingMinor: (remaining > 0n ? remaining : 0n).toString(),
    tradesUsed,
    tradesRemaining: Math.max(0, p.maxTrades - tradesUsed),
    emergencyStop: a.rows[0].stopped,
    positionsUsed: pos.rows[0].count,
    maxPositions: profile.max_positions,
    status:
      a.rows[0].stopped ||
      drawdownReached ||
      pos.rows[0].count >= profile.max_positions ||
      remaining <= 0n ||
      tradesUsed >= p.maxTrades
        ? "STOPPED"
        : "ACTIVE",
  };
}
export function riskRoutes(): express.Router {
  const router = express.Router();
  router.use(authenticate());
  router.get("/risk/profile", async (_req, res) => {
    const profile = await transaction(
      async (c) =>
        (
          await c.query(
            'SELECT risk_tolerance_bps AS "riskTolerance",daily_loss_limit_minor AS "dailyLossLimit",risk_per_trade_minor AS "riskPerTrade",max_trades AS "maxTrades",max_positions AS "maxPositions",max_drawdown_bps AS "maxDrawdown" FROM risk_profiles WHERE user_id=$1',
            [res.locals.identity.id],
          )
        ).rows[0] ?? null,
    );
    res.json(profile);
  });
  router.put("/risk/profile", async (req, res) => {
    const d = profileSchema.parse(req.body),
      id = res.locals.identity.id;
    await transaction(async (c) => {
      await lockOwner(c, id);
      const savedProfile = await c.query(
        "INSERT INTO risk_profiles(user_id,risk_tolerance_bps,daily_loss_limit_minor,risk_per_trade_minor,max_trades,max_positions,max_drawdown_bps) VALUES($1,$2,$3,$4,$5,$6,$7) ON CONFLICT(user_id) DO UPDATE SET risk_tolerance_bps=$2,daily_loss_limit_minor=$3,risk_per_trade_minor=$4,max_trades=$5,max_positions=$6,max_drawdown_bps=$7,updated_at=now() RETURNING id",
        [
          id,
          d.riskTolerance,
          d.dailyLossLimit,
          d.riskPerTrade,
          d.maxTrades,
          d.maxPositions,
          d.maxDrawdown,
        ],
      );
      await audit(
        c,
        id,
        "RISK_PROFILE_UPDATED",
        "RiskProfile",
        savedProfile.rows[0].id,
        res.locals.requestId,
      );
    });
    res.json(d);
  });
  router.get("/plans/current", async (_req, res) =>
    res.json(await transaction((c) => currentPlan(c, res.locals.identity.id))),
  );
  async function save(
    req: express.Request,
    res: express.Response,
    create: boolean,
  ) {
    const d = planSchema.parse(req.body),
      id = res.locals.identity.id;
    const saved = await transaction(async (c) => {
      await lockOwner(c, id);
      const existing = await currentPlan(c, id);
      if (create && existing) throw new HttpError(409, "Plan already exists");
      if (!create && !existing) throw new HttpError(404, "Plan not found");
      const planId =
        existing?.planId ??
        (
          await c.query(
            "INSERT INTO investment_plans(user_id) VALUES($1) RETURNING id",
            [id],
          )
        ).rows[0].id;
      const version = (existing?.version ?? 0) + 1;
      await c.query(
        "INSERT INTO plan_versions(plan_id,version,capital_minor,daily_loss_limit_minor,risk_per_trade_minor,max_trades,effective_at) VALUES($1,$2,$3,$4,$5,$6,now())",
        [
          planId,
          version,
          d.capitalMinor,
          d.dailyLossLimitMinor,
          d.riskPerTradeMinor,
          d.maxTrades,
        ],
      );
      await audit(
        c,
        id,
        create ? "PLAN_CREATED" : "PLAN_VERSION_CREATED",
        "InvestmentPlan",
        planId,
        res.locals.requestId,
      );
      return currentPlan(c, id);
    });
    res.status(create ? 201 : 200).json(saved);
  }
  router.post("/plans", (req, res) => save(req, res, true));
  router.put("/plans/current", (req, res) => save(req, res, false));
  router.get("/risk/status", async (_req, res) =>
    res.json(await transaction((c) => snapshot(c, res.locals.identity.id))),
  );
  return router;
}
export async function authoritativeCheck(
  userId: string,
  proposedRiskMinor: string,
) {
  return transaction(async (c) => {
    const s = await snapshot(c, userId);
    let reason: string | null = null;
    if (s.emergencyStop) reason = "Emergency stop is active";
    else if (BigInt(s.riskUsedMinor) >= BigInt(s.dailyLossLimitMinor))
      reason = "Daily loss limit reached";
    else if (s.drawdownReached) reason = "Maximum drawdown reached";
    else if (s.tradesRemaining <= 0) reason = "Maximum trades reached";
    else if (s.positionsUsed >= s.maxPositions)
      reason = "Maximum positions reached";
    else if (BigInt(proposedRiskMinor) > BigInt(s.riskPerTradeMinor))
      reason = "Proposed risk exceeds per-trade limit";
    else if (BigInt(proposedRiskMinor) > BigInt(s.riskRemainingMinor))
      reason = "Proposed risk exceeds remaining budget";
    return {
      approved: reason === null,
      reason,
      riskRemainingMinor: s.riskRemainingMinor,
      tradesRemaining: s.tradesRemaining,
      status: reason === null ? "ACTIVE" : "STOPPED",
      planVersion: s.version,
      mode: "simulation",
      executionAuthorized: false,
    };
  });
}
