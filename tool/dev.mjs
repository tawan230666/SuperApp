import {provisionAI,aiEnvironment} from './ai-runtime.mjs';
import { existsSync } from "node:fs";
import { spawn } from "node:child_process";
if (existsSync(".env")) process.loadEnvFile(".env");
const runtime=await provisionAI(process.env.DATABASE_URL);
process.env.AI_GATEWAY_SECRET=runtime.secret;process.env.AI_SERVICE_URL='http://127.0.0.1:3007';
const ai=spawn('node',['services/ai-service/dist/server.js'],{env:aiEnvironment({...process.env,NODE_ENV:'development'},runtime,3007),stdio:'inherit'});
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
    "--filter",
    "@tipkhun/allocation-service",
    "--filter",
    "@tipkhun/portfolio-service",
    "dev",
  ],
  { stdio: "inherit", env: process.env },
);
child.on('exit',code=>{process.exitCode=code??1;ai.kill('SIGTERM');});
ai.on('exit',async code=>{child.kill('SIGTERM');await runtime.close();if(code)process.exitCode=code;});
for (const signal of ["SIGINT", "SIGTERM"])
  process.on(signal, () => child.kill(signal));
