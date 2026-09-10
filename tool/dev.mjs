import { existsSync } from "node:fs";
import { spawn } from "node:child_process";
if (existsSync(".env")) process.loadEnvFile(".env");
const child = spawn(
  "pnpm",
  [
    "--parallel",
    "--filter",
    "@tipkhun/web",
    "--filter",
    "@tipkhun/api-gateway",
    "--filter",
    "@tipkhun/auth-service",
    "--filter",
    "@tipkhun/risk-service",
    "--filter",
    "@tipkhun/trading-service",
    "dev",
  ],
  { stdio: "inherit", env: process.env },
);
child.on("exit", (code) => {
  process.exitCode = code ?? 1;
});
for (const signal of ["SIGINT", "SIGTERM"])
  process.on(signal, () => child.kill(signal));
