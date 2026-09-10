import {requireFreePorts} from './test-ports.mjs';
import { existsSync } from "node:fs";
import { spawn, spawnSync } from "node:child_process";
if (existsSync(".env")) process.loadEnvFile(".env");
const url = process.env.TEST_DATABASE_URL;
if (!url || !new URL(url).pathname.endsWith("_test")) {
  console.error(
    "TEST_DATABASE_URL must target a dedicated database ending in _test",
  );
  process.exit(1);
}
const env = {
  ...process.env,
  DATABASE_URL: url,
  NODE_ENV: "test",
  TEST_MODE: "1",
  RUN_DB_TESTS: "1",
  PAPER_MARKET_PROVIDER: "deterministic",
  PORTFOLIO_SERVICE_URL: "http://127.0.0.1:13006",
  RISK_SERVICE_URL: "http://127.0.0.1:13001",
  AUTH_SERVICE_URL: "http://127.0.0.1:13002",
  TRADING_SERVICE_URL: "http://127.0.0.1:13003",
  ALLOCATION_SERVICE_URL: "http://127.0.0.1:13005",
};
const migrated = spawnSync(
  "pnpm",
  ["--filter", "@tipkhun/database", "migrate"],
  { env, stdio: "inherit" },
);
if (migrated.status !== 0) process.exit(1);
await requireFreePorts([13000,13001,13002,13003,13005,13006,13007,13008]);
const children = [
  spawn("node",["services/portfolio-service/dist/server.js"],{env:{...env,NODE_ENV:"development",PORTFOLIO_PORT:"13006"},stdio:"inherit"}),
  spawn("node",["services/api-gateway/dist/server.js"],{env:{...env,NODE_ENV:"development",API_PORT:"13000"},stdio:"inherit"}),
  spawn("node",["services/trading-service/dist/server.js"],{env:{...env,NODE_ENV:"development",TRADING_PORT:"13003"},stdio:"inherit"}),
  spawn("node",["services/auth-service/dist/server.js"],{env:{...env,NODE_ENV:"development",AUTH_PORT:"13002"},stdio:"inherit"}),
  spawn("node", ["services/risk-service/dist/server.js"], {
    env: { ...env, NODE_ENV: "development", RISK_PORT: "13001" },
    stdio: "inherit",
  }),
  spawn("node",["services/allocation-service/dist/server.js"],{env:{...env,NODE_ENV:"development",ALLOCATION_PORT:"13005"},stdio:"inherit"}),
];
try {
  let healthy = false;
  for (let i = 0; i < 150; i++) {
    try {
      if ((await fetch("http://127.0.0.1:13006/ready")).ok && (await fetch("http://127.0.0.1:13000/ready")).ok && (await fetch("http://127.0.0.1:13001/ready")).ok && (await fetch("http://127.0.0.1:13002/ready")).ok && (await fetch("http://127.0.0.1:13003/ready")).ok && (await fetch("http://127.0.0.1:13005/ready")).ok) {
        healthy = true;
        break;
      }
    } catch {}
    await new Promise((r) => setTimeout(r, 200));
  }
  if (!healthy) throw new Error("Risk dependency is not ready");
  const result = spawnSync(
    "pnpm",
    [
      "--filter",
      "@tipkhun/api-gateway",
      "exec",
      "vitest",
      "run",
      process.argv[2] === "portfolio" ? "src/portfolio.integration.test.ts" : process.argv[2] === "paper" ? "src/paper.integration.test.ts" : "src/integration.test.ts",
    ],
    { env, stdio: "inherit" },
  );
  process.exitCode = result.status ?? 1;
} catch (e) {
  console.error(e.message);
  process.exitCode = 1;
} finally {
  for (const child of children) child.kill("SIGTERM");
}
