import {spawn} from 'node:child_process';
import {existsSync} from 'node:fs';
if(existsSync('.env'))process.loadEnvFile('.env');
if(!process.env.TEST_DATABASE_URL||!new URL(process.env.TEST_DATABASE_URL).pathname.endsWith('_test'))throw new Error('Dedicated TEST_DATABASE_URL required');
const env={...process.env,DATABASE_URL:process.env.TEST_DATABASE_URL,NODE_ENV:'development',AUTH_PORT:'14002',RISK_PORT:'14001',TRADING_PORT:'14003',ALLOCATION_PORT:'14005',API_PORT:'14000',AUTH_SERVICE_URL:'http://127.0.0.1:14002',RISK_SERVICE_URL:'http://127.0.0.1:14001',TRADING_SERVICE_URL:'http://127.0.0.1:14003',ALLOCATION_SERVICE_URL:'http://127.0.0.1:14005',API_GATEWAY_URL:'http://127.0.0.1:14000',WEB_ORIGIN:'http://host.docker.internal:15173'};
const children=['auth-service','risk-service','trading-service','allocation-service','api-gateway'].map(s=>spawn('node',[`services/${s}/dist/server.js`],{env,stdio:'inherit'}));
children.push(spawn('pnpm',['--filter','@tipkhun/web','exec','vite','--host','0.0.0.0','--port','15173','--strictPort'],{env,stdio:'inherit'}));
try {
 let ready=false;
 for(let i=0;i<50;i++){try{const responses=await Promise.all([14000,14001,14002,14003,14005].map(p=>fetch(`http://127.0.0.1:${p}/ready`)));if(responses.every(r=>r.ok)&&(await fetch('http://127.0.0.1:15173')).ok){ready=true;break;}}catch{}await new Promise(r=>setTimeout(r,200));}
 if(!ready)throw new Error('Browser test services unavailable');
 const test=spawn('docker',['run','--rm','-v',`${process.cwd()}:/work:ro`,'-w','/work/apps/web','-e','WEB_TEST_URL=http://host.docker.internal:15173','mcr.microsoft.com/playwright:v1.55.0-noble','node','e2e/phase2.mjs'],{stdio:'inherit'});
 process.exitCode=await new Promise(resolve=>test.on('exit',c=>resolve(c??1)));
}finally{children.forEach(c=>c.kill('SIGTERM'));}
