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
  RUN_DB_TESTS: "1",
  RISK_SERVICE_URL: "http://127.0.0.1:13001",
};
const migrated = spawnSync(
  "pnpm",
  ["--filter", "@tipkhun/database", "migrate"],
  { env, stdio: "inherit" },
);
if (migrated.status !== 0) process.exit(1);
const children = [
  spawn("node", ["services/risk-service/dist/server.js"], {
    env: { ...env, NODE_ENV: "development", RISK_PORT: "13001" },
    stdio: "inherit",
  }),
];
try {
  let healthy = false;
  for (let i = 0; i < 30; i++) {
    try {
      if ((await fetch("http://127.0.0.1:13001/ready")).ok) {
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
      "src/integration.test.ts",
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
