import assert from 'node:assert/strict';
import pg from '../packages/database/node_modules/pg/lib/index.js';
import {provisionAI,aiEnvironment} from './ai-runtime.mjs';
import {requireFreePorts} from './test-ports.mjs';
import {spawn} from 'node:child_process';
import {existsSync,mkdtempSync,rmSync,readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
if(existsSync('.env'))process.loadEnvFile('.env');
if(!process.env.TEST_DATABASE_URL||!new URL(process.env.TEST_DATABASE_URL).pathname.endsWith('_test'))throw new Error('Dedicated TEST_DATABASE_URL required');
const env={...process.env,DATABASE_URL:process.env.TEST_DATABASE_URL,NODE_ENV:'development',TEST_MODE:'1',AUTH_PORT:'14002',RISK_PORT:'14001',TRADING_PORT:'14003',ALLOCATION_PORT:'14005',PORTFOLIO_PORT:'14006',PAPER_MARKET_PROVIDER:'deterministic',PORTFOLIO_SERVICE_URL:'http://127.0.0.1:14006',API_PORT:'14000',AUTH_SERVICE_URL:'http://127.0.0.1:14002',RISK_SERVICE_URL:'http://127.0.0.1:14001',TRADING_SERVICE_URL:'http://127.0.0.1:14003',ALLOCATION_SERVICE_URL:'http://127.0.0.1:14005',API_GATEWAY_URL:'http://127.0.0.1:14000',WEB_ORIGIN:'http://host.docker.internal:15173'};
await requireFreePorts([14000,14001,14002,14003,14005,14006,14007,15173]);
const aiRuntime=await provisionAI(env.DATABASE_URL);env.AI_GATEWAY_SECRET=aiRuntime.secret;env.AI_SERVICE_URL='http://127.0.0.1:14007';
const children=['auth-service','risk-service','trading-service','allocation-service','portfolio-service','api-gateway'].map(s=>spawn('node',[`services/${s}/dist/server.js`],{env,stdio:'inherit'}));
children.push(spawn('node',['services/ai-service/dist/server.js'],{env:aiEnvironment(env,aiRuntime,14007),stdio:'inherit'}));
children.push(spawn('pnpm',['--filter','@tipkhun/web','exec','vite','--host','0.0.0.0','--port','15173','--strictPort'],{env,stdio:'inherit'}));
try {
 let ready=false;
 for(let i=0;i<150;i++){try{const responses=await Promise.all([14000,14001,14002,14003,14005,14006,14007].map(p=>fetch(`http://127.0.0.1:${p}/ready`)));if(responses.every(r=>r.ok)&&(await fetch('http://127.0.0.1:15173')).ok){ready=true;break;}}catch{}await new Promise(r=>setTimeout(r,200));}
 if(!ready)throw new Error('Browser test services unavailable');
 const shared=mkdtempSync(join(tmpdir(),'tipkhun-portfolio-e2e-'));
 async function run(cmd,args,extraEnv={}){const child=spawn(cmd,args,{stdio:'inherit',env:{...process.env,...extraEnv}});const code=await new Promise(resolve=>{child.on('error',()=>resolve(1));child.on('exit',c=>resolve(c??1));});if(code!==0)throw new Error(`${cmd} acceptance failed (${code})`);}
 async function aiFinancialState(){
  const fixture=JSON.parse(readFileSync(join(shared,'fixture.json'),'utf8'));
  const db=new pg.Client({connectionString:env.DATABASE_URL});await db.connect();
  try{
   await db.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
   const user=(await db.query('SELECT id FROM users WHERE email=$1',[fixture.email])).rows[0].id;
   const state={};
   const queries={accounts:'SELECT * FROM accounts WHERE user_id=$1',bots:'SELECT b.* FROM bot_sessions b JOIN accounts a ON a.id=b.account_id WHERE a.user_id=$1',orders:'SELECT o.* FROM orders o JOIN accounts a ON a.id=o.account_id WHERE a.user_id=$1',positions:'SELECT p.* FROM positions p JOIN accounts a ON a.id=p.account_id WHERE a.user_id=$1',trades:'SELECT t.* FROM trades t JOIN accounts a ON a.id=t.account_id WHERE a.user_id=$1',reservations:'SELECT r.* FROM risk_reservations r JOIN orders o ON o.id=r.order_id JOIN accounts a ON a.id=o.account_id WHERE a.user_id=$1',plans:'SELECT v.* FROM plan_versions v JOIN investment_plans p ON p.id=v.plan_id WHERE p.user_id=$1',profile:'SELECT * FROM risk_profiles WHERE user_id=$1',ledger:'SELECT e.* FROM ledger_entries e JOIN ledger_accounts a ON a.id=e.ledger_account_id WHERE a.user_id=$1',ledgerAccounts:'SELECT * FROM ledger_accounts WHERE user_id=$1',ledgerTransactions:'SELECT * FROM ledger_transactions WHERE user_id=$1',allocations:'SELECT * FROM allocation_batches WHERE user_id=$1',profit:'SELECT * FROM profit_allocations WHERE user_id=$1',portfolio:'SELECT * FROM portfolios WHERE user_id=$1',holdings:'SELECT * FROM portfolio_holdings WHERE user_id=$1',cash:'SELECT c.* FROM portfolio_cash c JOIN portfolios p ON p.id=c.portfolio_id WHERE p.user_id=$1',transactions:'SELECT * FROM portfolio_transactions WHERE user_id=$1',snapshots:'SELECT s.* FROM portfolio_snapshots s JOIN portfolios p ON p.id=s.portfolio_id WHERE p.user_id=$1'};
   for(const [name,sql] of Object.entries(queries))state[name]=(await db.query(sql,[user])).rows.map(r=>JSON.stringify(r)).sort();
   await db.query('COMMIT');return state;
  }finally{await db.end();}
 }
 const docker=['run','--rm','-v',`${process.cwd()}:/work:ro`,'-v',`${shared}:/shared`,'-w','/work/apps/web','-e','WEB_TEST_URL=http://host.docker.internal:15173','mcr.microsoft.com/playwright:v1.55.0-noble','node'];
 try{
  await run('docker',[...docker,'e2e/phase2.mjs']);
  await run('docker',[...docker,'e2e/assistant.mjs']);
  await run('docker',[...docker,'e2e/portfolio.mjs']);
  const beforeAI=await aiFinancialState();
  await run('docker',[...docker,'e2e/assistant-shared.mjs']);
  await run('flutter',['test','--no-pub','--dart-define=PLATFORM_REPOSITORY=remote','tool/ai_remote_acceptance_test.dart'],{AI_SHARED_FIXTURE:join(shared,'fixture.json'),FLUTTER_SUPPRESS_ANALYTICS:'true',DART_SUPPRESS_ANALYTICS:'true'});
  await run('docker',[...docker,'e2e/assistant-shared.mjs','verify']);
  assert.deepEqual(await aiFinancialState(),beforeAI);
  console.log('PASS shared AI financial isolation: full PostgreSQL rows unchanged across React and Flutter advisory/refusal');
  await run('flutter',['test','--no-pub','--dart-define=PLATFORM_REPOSITORY=remote','tool/portfolio_remote_acceptance_test.dart'],{PORTFOLIO_SHARED_FIXTURE:join(shared,'fixture.json'),FLUTTER_SUPPRESS_ANALYTICS:'true',DART_SUPPRESS_ANALYTICS:'true'});
  await run('docker',[...docker,'e2e/portfolio.mjs','verify']);
 }finally{rmSync(shared,{recursive:true,force:true});}

}finally{await Promise.all(children.map(c=>new Promise(resolve=>{if(c.exitCode!==null||c.signalCode!==null)return resolve();c.once('exit',resolve);c.kill('SIGTERM');})));await aiRuntime.close();}
