import crypto from "node:crypto";
import express, {
  type RequestHandler,
  type ErrorRequestHandler,
} from "express";
import helmet from "helmet";
import cors from "cors";
import { rateLimit } from "express-rate-limit";
import bcrypt from "bcryptjs";
import { z } from "zod";
import { pool, transaction, ready, type PoolClient } from "@tipkhun/database";
export class HttpError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}
export const hashToken = (token: string) =>
  crypto.createHash("sha256").update(token).digest("hex");
import { authCredentialsSchema as credentials } from "@tipkhun/contracts";
export async function audit(
  c: PoolClient,
  userId: string,
  action: string,
  entity: string,
  entityId: string,
  requestId: string,
) {
  await c.query(
    "INSERT INTO audit_logs(user_id,action,entity,entity_id,request_id,source) VALUES($1,$2,$3,$4,$5,$6)",
    [userId, action, entity, entityId, requestId, "api"],
  );
}
async function issue(c: PoolClient, sessionId: string) {
  const accessToken = crypto.randomBytes(32).toString("base64url");
  const refreshToken = crypto.randomBytes(32).toString("base64url");
  await c.query(
    "INSERT INTO auth_tokens(hash,session_id,kind,expires_at) VALUES($1,$3,'access',now()+interval '10 minutes'),($2,$3,'refresh',LEAST(now()+interval '7 days',(SELECT expires_at FROM auth_sessions WHERE id=$3)))",
    [hashToken(accessToken), hashToken(refreshToken), sessionId],
  );
  return { accessToken, refreshToken, expiresIn: 600 };
}
export const authenticate = (): RequestHandler => async (req, res, next) => {
  const match = /^Bearer ([A-Za-z0-9_-]{43})$/.exec(
    req.header("authorization") ?? "",
  );
  if (!match) throw new HttpError(401, "Authentication required");
  const q = await pool.query(
    "SELECT u.id,u.email,u.role,s.id AS session_id FROM auth_tokens t JOIN auth_sessions s ON s.id=t.session_id JOIN users u ON u.id=s.user_id WHERE t.hash=$1 AND t.kind='access' AND t.expires_at>now() AND s.expires_at>now() AND s.revoked_at IS NULL",
    [hashToken(match[1])],
  );
  if (!q.rowCount) throw new HttpError(401, "Invalid or expired session");
  res.locals.identity = q.rows[0];
  res.locals.requestContext = {
    requestId: res.locals.requestId,
    userId: q.rows[0].id,
    role: q.rows[0].role,
  };
  next();
};
export const authorize =
  (...roles: string[]): RequestHandler =>
  (_req, res, next) => {
    if (!res.locals.identity)
      throw new HttpError(401, "Authentication required");
    if (!roles.includes(res.locals.identity.role))
      throw new HttpError(403, "Forbidden");
    next();
  };
export function baseApp(service: string): express.Express {
  const app = express();
  app.disable("x-powered-by");
  app.use(helmet());
  app.use(
    cors({
      origin: process.env.WEB_ORIGIN?.split(",") ?? ["http://localhost:5173"],
      credentials: true,
    }),
  );
  app.use((_req, res, next) => {
    res.locals.requestId = crypto.randomUUID();
    res.setHeader("x-request-id", res.locals.requestId);
    res.setHeader("Cache-Control", "no-store");
    next();
  });
  app.use(rateLimit({ windowMs: 60000, limit: 120 }));
  app.use(express.json({ limit: "32kb" }));
  app.get("/health", (_req, res) => res.json({ service, status: "ok" }));
  app.get("/ready", async (_req, res) => {
    try {
      await ready();
      await pool.query("SELECT max_positions FROM risk_profiles LIMIT 0");
      await pool.query("SELECT id FROM auth_sessions LIMIT 0");
      res.json({ service, status: "ready" });
    } catch {
      res.status(503).json({ service, status: "unavailable" });
    }
  });
  return app;
}
const errors: ErrorRequestHandler = (err, _req, res, _next) => {
  const status =
    err instanceof HttpError
      ? err.status
      : err instanceof z.ZodError
        ? 400
        : err?.type === "entity.parse.failed"
          ? 400
          : 503;
  res
    .status(status)
    .json({
      error:
        err instanceof HttpError
          ? err.message
          : status === 400
            ? "Invalid request"
            : "Service unavailable",
      requestId: res.locals.requestId,
    });
};
export function finish(app: express.Express) {
  app.use(errors);
}
export function authRoutes(): express.Router {
  const router = express.Router();
  router.use(rateLimit({ windowMs: 15 * 60000, limit: 40 }));
  function refreshInput(req: express.Request) {
    const origin = req.header("origin");
    if (
      origin &&
      !(
        process.env.WEB_ORIGIN?.split(",") ?? ["http://localhost:5173"]
      ).includes(origin)
    )
      throw new HttpError(403, "Origin rejected");
    if (req.header("x-auth-client") !== "web")
      return z
        .object({ refreshToken: z.string().regex(/^[A-Za-z0-9_-]{43}$/) })
        .strict()
        .parse(req.body).refreshToken;
    if (!origin) throw new HttpError(403, "Origin required");
    return (
      req.headers.cookie
        ?.split(";")
        .map((v) => v.trim())
        .find((v) => v.startsWith("tipkhun_refresh="))
        ?.slice(16) ?? ""
    );
  }
  function deliver(
    req: express.Request,
    res: express.Response,
    tokens: Awaited<ReturnType<typeof issue>>,
  ) {
    if (req.header("x-auth-client") === "web") {
      res.cookie("tipkhun_refresh", tokens.refreshToken, {
        httpOnly: true,
        secure: process.env.NODE_ENV === "production",
        sameSite: "strict",
        path: "/",
        maxAge: 7 * 86400000,
      });
      return { accessToken: tokens.accessToken, expiresIn: tokens.expiresIn };
    }
    return tokens;
  }
  router.post("/register", async (req, res) => {
    const data = credentials.parse(req.body);
    const passwordHash = await bcrypt.hash(data.password, 12);
    try {
      const user = await transaction(async (c) => {
        const q = await c.query(
          'INSERT INTO users(email,password_hash) VALUES($1,$2) RETURNING id,email,role,created_at AS "createdAt",updated_at AS "updatedAt"',
          [data.email, passwordHash],
        );
        await c.query(
          "INSERT INTO accounts(user_id,environment) VALUES($1,'simulation')",
          [q.rows[0].id],
        );
        await audit(
          c,
          q.rows[0].id,
          "USER_REGISTERED",
          "User",
          q.rows[0].id,
          res.locals.requestId,
        );
        return q.rows[0];
      });
      res.status(201).json({ user });
    } catch (e) {
      if ((e as { code?: string }).code === "23505")
        throw new HttpError(409, "Email already registered");
      throw e;
    }
  });
  router.post("/login", async (req, res) => {
    const data = credentials.parse(req.body);
    const q = await pool.query(
      "SELECT id,email,role,password_hash FROM users WHERE email=$1",
      [data.email],
    );
    const user = q.rows[0];
    const valid = await bcrypt.compare(
      data.password,
      user?.password_hash ??
        "$2b$12$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy",
    );
    if (!user || !valid) throw new HttpError(401, "Invalid email or password");
    const tokens = await transaction(async (c) => {
      const s = await c.query(
        "INSERT INTO auth_sessions(user_id,expires_at) VALUES($1,now()+interval '30 days') RETURNING id",
        [user.id],
      );
      await audit(
        c,
        user.id,
        "USER_LOGIN",
        "User",
        user.id,
        res.locals.requestId,
      );
      return issue(c, s.rows[0].id);
    });
    res.json({
      ...deliver(req, res, tokens),
      user: { id: user.id, email: user.email, role: user.role },
    });
  });
  router.post("/refresh", async (req, res) => {
    const token = refreshInput(req);
    const result = await transaction(async (c) => {
      const q = await c.query(
        "SELECT s.id,s.user_id,t.consumed_at,t.expires_at>now() AS valid,s.expires_at>now() AS session_valid,s.revoked_at FROM auth_tokens t JOIN auth_sessions s ON s.id=t.session_id WHERE t.hash=$1 AND t.kind='refresh' FOR UPDATE OF s,t",
        [hashToken(token)],
      );
      const row = q.rows[0];
      if (!row) return null;
      if (row.consumed_at) {
        await c.query("UPDATE auth_sessions SET revoked_at=now() WHERE id=$1", [
          row.id,
        ]);
        return null;
      }
      if (!row.valid || !row.session_valid || row.revoked_at) return null;
      await c.query("UPDATE auth_tokens SET consumed_at=now() WHERE hash=$1", [
        hashToken(token),
      ]);
      return issue(c, row.id);
    });
    if (!result) throw new HttpError(401, "Invalid or expired session");
    res.json(deliver(req, res, result));
  });
  router.post("/logout", authenticate(), async (_req, res) => {
    const id = res.locals.identity;
    await transaction(async (c) => {
      await c.query(
        "UPDATE auth_sessions SET revoked_at=now() WHERE id=$1 AND user_id=$2",
        [id.session_id, id.id],
      );
      await audit(c, id.id, "USER_LOGOUT", "User", id.id, res.locals.requestId);
    });
    res.clearCookie("tipkhun_refresh", {
      path: "/",
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "strict",
    });
    res.status(204).end();
  });
  router.get("/me", authenticate(), (_req, res) => {
    const { id, email, role } = res.locals.identity;
    res.json({ id, email, role });
  });
  return router;
}
