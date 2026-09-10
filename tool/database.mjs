import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
if (existsSync(".env")) process.loadEnvFile(".env");
const result = spawnSync(
  "pnpm",
  ["--filter", "@tipkhun/database", process.argv[2]],
  { stdio: "inherit", env: process.env },
);
process.exitCode = result.status ?? 1;
