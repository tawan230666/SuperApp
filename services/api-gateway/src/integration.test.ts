import { beforeAll, afterAll, describe, it, expect } from "vitest";
import request from "supertest";
import { randomUUID } from "node:crypto";
import { pool, transaction, migrations } from "@tipkhun/database";
import { hashToken } from "@tipkhun/auth";
import { app } from "./server.js";
const integration = process.env.RUN_DB_TESTS === "1" ? describe : describe.skip;
integration(
  "PostgreSQL authentication and authoritative risk integration",
  () => {
    const email = `a-${randomUUID()}@example.test`,
      otherEmail = `b-${randomUUID()}@example.test`,
      password = "Test-password-1234";
    let access = "",
      refresh = "",
      otherAccess = "",
      userId = "",
      otherId = "";
    const plan = {
      capitalMinor: "35000",
      dailyLossLimitMinor: "1750",
      riskPerTradeMinor: "500",
      maxTrades: 3,
    };
    const profile = {
      riskTolerance: 500,
      dailyLossLimit: "1750",
      riskPerTrade: "500",
      maxTrades: 3,
      maxPositions: 2,
      maxDrawdown: 1000,
    };
    const own = (method: "get" | "put" | "post", path: string) =>
      request(app)[method](path).set("Authorization", `Bearer ${access}`);
    beforeAll(async () => {
      expect(
        new URL(process.env.DATABASE_URL!).pathname.endsWith("_test"),
      ).toBe(true);
      await pool.query("SELECT 1");
    });
    afterAll(async () => {
      await pool.end();
    });
    it("migrations are repeatable without modifying applied history", async () => {
      const first = await migrations(true);
      const second = await migrations(true);
      expect(second).toEqual(first);
      expect(second.every((m) => m.status === "applied")).toBe(true);
    });
    it("register persists user with hashed password and audit", async () => {
      const r = await request(app)
        .post("/api/v1/auth/register")
        .send({ email, password });
      expect(r.status).toBe(201);
      userId = r.body.user.id;
      expect(JSON.stringify(r.body)).not.toContain("password");
      const q = await pool.query(
        "SELECT password_hash FROM users WHERE id=$1",
        [userId],
      );
      expect(q.rows[0].password_hash).toMatch(/^\$2/);
      expect(
        (
          await pool.query(
            "SELECT id FROM audit_logs WHERE user_id=$1 AND action='USER_REGISTERED'",
            [userId],
          )
        ).rowCount,
      ).toBe(1);
    });
    it("duplicate email rejected", async () => {
      expect(
        (
          await request(app)
            .post("/api/v1/auth/register")
            .send({ email: email.toUpperCase(), password })
        ).status,
      ).toBe(409);
    });
    it("invalid email rejected", async () => {
      expect(
        (
          await request(app)
            .post("/api/v1/auth/register")
            .send({ email: "bad", password })
        ).status,
      ).toBe(400);
    });
    it("weak password rejected", async () => {
      expect(
        (
          await request(app)
            .post("/api/v1/auth/register")
            .send({ email, password: "weak" })
        ).status,
      ).toBe(400);
    });
    it("client cannot assign admin role", async () => {
      expect(
        (
          await request(app)
            .post("/api/v1/auth/register")
            .send({ email, password, role: "admin" })
        ).status,
      ).toBe(400);
    });
    it("correct login and me", async () => {
      const r = await request(app)
        .post("/api/v1/auth/login")
        .send({ email, password });
      expect(r.status).toBe(200);
      access = r.body.accessToken;
      refresh = r.body.refreshToken;
      expect((await own("get", "/api/v1/me")).body.id).toBe(userId);
    });
    it("wrong password rejected", async () => {
      expect(
        (
          await request(app)
            .post("/api/v1/auth/login")
            .send({ email, password: "Wrong-password-123" })
        ).status,
      ).toBe(401);
    });
    it("missing bearer rejected", async () => {
      expect((await request(app).get("/api/v1/me")).status).toBe(401);
    });
    it("invalid bearer rejected", async () => {
      expect(
        (
          await request(app)
            .get("/api/v1/me")
            .set("Authorization", `Bearer ${"a".repeat(43)}`)
        ).status,
      ).toBe(401);
    });
    it("creates risk profile", async () => {
      expect(
        (await own("put", "/api/v1/risk/profile").send(profile)).status,
      ).toBe(200);
      expect((await own("get", "/api/v1/risk/profile")).body).toEqual(profile);
    });
    it("creates plan and rejects duplicate current plan", async () => {
      expect((await own("post", "/api/v1/plans").send(plan)).status).toBe(201);
      expect((await own("post", "/api/v1/plans").send(plan)).status).toBe(409);
    });
    it("computes real snapshot", async () => {
      const r = await own("get", "/api/v1/risk/status");
      expect(r.status).toBe(200);
      expect(r.body).toMatchObject({
        capitalMinor: "35000",
        riskUsedMinor: "0",
        riskReservedMinor: "0",
        riskRemainingMinor: "1750",
        tradesRemaining: 3,
      });
    });
    it("risk service loads authoritative plan", async () => {
      const r = await own("post", "/api/v1/risk/check").send({
        proposedRiskMinor: "100",
      });
      expect(r.status).toBe(200);
      expect(r.body.approved).toBe(true);
      expect(r.body.executionAuthorized).toBe(false);
    });
    it("cannot override server limits", async () => {
      expect(
        (
          await own("post", "/api/v1/risk/check").send({
            proposedRiskMinor: "100",
            capitalMinor: "999999",
            riskUsedMinor: "0",
          })
        ).status,
      ).toBe(400);
      expect(
        (
          await own("post", "/api/v1/risk/check").send({
            proposedRiskMinor: "501",
          })
        ).body.approved,
      ).toBe(false);
    });
    it("new plan version retains old immutable history", async () => {
      const r = await own("put", "/api/v1/plans/current").send({
        ...plan,
        riskPerTradeMinor: "400",
      });
      expect(r.body.version).toBe(2);
      const rows = await pool.query(
        "SELECT v.* FROM plan_versions v JOIN investment_plans p ON p.id=v.plan_id WHERE p.user_id=$1 ORDER BY version",
        [userId],
      );
      expect(rows.rowCount).toBe(2);
      expect(rows.rows[0].risk_per_trade_minor).toBe("500");
      await expect(
        pool.query("UPDATE plan_versions SET max_trades=50 WHERE id=$1", [
          rows.rows[0].id,
        ]),
      ).rejects.toThrow("immutable");
    });
    it("transaction rollback preserves data", async () => {
      const e = `rollback-${randomUUID()}@example.test`;
      await expect(
        transaction(async (c) => {
          await c.query(
            "INSERT INTO users(email,password_hash) VALUES($1,'test-hash')",
            [e],
          );
          throw new Error("rollback");
        }),
      ).rejects.toThrow("rollback");
      expect(
        (await pool.query("SELECT id FROM users WHERE email=$1", [e])).rowCount,
      ).toBe(0);
    });
    it("database duplicate constraint exists", async () => {
      await expect(
        pool.query(
          "INSERT INTO users(email,password_hash) VALUES($1,'test-hash')",
          [email],
        ),
      ).rejects.toMatchObject({ code: "23505" });
    });
    it("other user cannot access or mutate owner resources", async () => {
      const r = await request(app)
        .post("/api/v1/auth/register")
        .send({ email: otherEmail, password });
      otherId = r.body.user.id;
      const l = await request(app)
        .post("/api/v1/auth/login")
        .send({ email: otherEmail, password });
      otherAccess = l.body.accessToken;
      expect(
        (
          await request(app)
            .get(`/api/v1/plans/current?userId=${userId}`)
            .set("Authorization", `Bearer ${otherAccess}`)
        ).body,
      ).toBe(null);
      expect(
        (
          await request(app)
            .put("/api/v1/risk/profile")
            .set("Authorization", `Bearer ${otherAccess}`)
            .send({ ...profile, userId })
        ).status,
      ).toBe(400);
      for (const resource of [
        "plans",
        "trades",
        "accounts",
        "allocations",
        "portfolio",
        "risk/profile",
      ])
        expect(
          (
            await request(app)
              .get(`/api/v1/${resource}/${userId}`)
              .set("Authorization", `Bearer ${otherAccess}`)
          ).status,
        ).toBe(404);
    });
    it("emergency stop is authoritative", async () => {
      await pool.query(
        "UPDATE accounts SET emergency_stop=true WHERE user_id=$1",
        [userId],
      );
      expect(
        (
          await own("post", "/api/v1/risk/check").send({
            proposedRiskMinor: "100",
          })
        ).body.reason,
      ).toBe("Emergency stop is active");
      await pool.query(
        "UPDATE accounts SET emergency_stop=false WHERE user_id=$1",
        [userId],
      );
    });
    it("daily loss and trade exhaustion loaded from owned trades", async () => {
      await pool.query(
        "INSERT INTO trades(account_id,net_pnl_minor,mode) SELECT id,-1750,'simulation' FROM accounts WHERE user_id=$1",
        [userId],
      );
      expect(
        (
          await own("post", "/api/v1/risk/check").send({
            proposedRiskMinor: "100",
          })
        ).body.reason,
      ).toBe("Daily loss limit reached");
      expect(
        (
          await request(app)
            .get("/api/v1/risk/status")
            .set("Authorization", `Bearer ${otherAccess}`)
        ).status,
      ).toBe(404);
    });
    it("exhausted trades stop risk on a separate account", async () => {
      await request(app)
        .put("/api/v1/risk/profile")
        .set("Authorization", `Bearer ${otherAccess}`)
        .send(profile);
      await request(app)
        .post("/api/v1/plans")
        .set("Authorization", `Bearer ${otherAccess}`)
        .send({ ...plan, maxTrades: 1 });
      await pool.query(
        "INSERT INTO trades(account_id,net_pnl_minor,mode) SELECT id,0,'simulation' FROM accounts WHERE user_id=$1",
        [otherId],
      );
      expect(
        (
          await request(app)
            .post("/api/v1/risk/check")
            .set("Authorization", `Bearer ${otherAccess}`)
            .send({ proposedRiskMinor: "100" })
        ).body.reason,
      ).toBe("Maximum trades reached");
    });
    it("refresh rotates and stores only hashes", async () => {
      const r = await request(app)
        .post("/api/v1/auth/refresh")
        .send({ refreshToken: refresh });
      expect(r.status).toBe(200);
      expect(r.body.refreshToken).not.toBe(refresh);
      refresh = r.body.refreshToken;
      access = r.body.accessToken;
      expect(
        (
          await pool.query("SELECT hash FROM auth_tokens WHERE hash=$1", [
            hashToken(refresh),
          ])
        ).rowCount,
      ).toBe(1);
    });
    it("expired access rejected", async () => {
      await pool.query(
        "UPDATE auth_tokens SET expires_at=now()-interval '1 second' WHERE hash=$1",
        [hashToken(access)],
      );
      expect((await own("get", "/api/v1/me")).status).toBe(401);
      const r = await request(app)
        .post("/api/v1/auth/refresh")
        .send({ refreshToken: refresh });
      access = r.body.accessToken;
      refresh = r.body.refreshToken;
    });
    it("logout revokes access and refresh immediately", async () => {
      expect((await own("post", "/api/v1/auth/logout")).status).toBe(204);
      expect((await own("get", "/api/v1/me")).status).toBe(401);
      expect(
        (
          await request(app)
            .post("/api/v1/auth/refresh")
            .send({ refreshToken: refresh })
        ).status,
      ).toBe(401);
    });
    it("refresh replay revokes family", async () => {
      const l = await request(app)
        .post("/api/v1/auth/login")
        .send({ email, password });
      const old = l.body.refreshToken;
      const rotated = await request(app)
        .post("/api/v1/auth/refresh")
        .send({ refreshToken: old });
      expect(
        (
          await request(app)
            .post("/api/v1/auth/refresh")
            .send({ refreshToken: old })
        ).status,
      ).toBe(401);
      expect(
        (
          await request(app)
            .get("/api/v1/me")
            .set("Authorization", `Bearer ${rotated.body.accessToken}`)
        ).status,
      ).toBe(401);
    });
    it("expired refresh rejected", async () => {
      const l = await request(app)
        .post("/api/v1/auth/login")
        .send({ email, password });
      await pool.query(
        "UPDATE auth_tokens SET expires_at=now()-interval '1 second' WHERE hash=$1",
        [hashToken(l.body.refreshToken)],
      );
      expect(
        (
          await request(app)
            .post("/api/v1/auth/refresh")
            .send({ refreshToken: l.body.refreshToken })
        ).status,
      ).toBe(401);
    });
  },
);
