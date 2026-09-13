import pg from '../packages/database/node_modules/pg/lib/index.js';
import {randomBytes} from 'node:crypto';
/** Local development/test provisioning only. The AI child receives no owner URL or user tokens. */
export async function provisionAI(databaseUrl){
 const admin=new pg.Pool({connectionString:databaseUrl,connectionTimeoutMillis:3000});
 const role=`ai_runtime_${randomBytes(8).toString('hex')}`,password=randomBytes(32).toString('hex');
 try{await admin.query(`CREATE ROLE ${role} LOGIN PASSWORD '${password}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS IN ROLE tipkhun_ai`);}
 catch{await admin.end();throw new Error('AI restricted login provisioning failed; run migrations first');}
 const url=new URL(databaseUrl);url.username=role;url.password=password;
 return {databaseUrl:url.toString(),secret:randomBytes(32).toString('hex'),async close(){try{await admin.query(`DROP ROLE ${role}`);}finally{await admin.end();}}};
}
export function aiEnvironment(base,runtime,port){
 // Allowlist, never spread parent env: no DATABASE_URL, TEST_DATABASE_URL, broker credentials, or service URLs.
 return {PATH:base.PATH,NODE_ENV:base.NODE_ENV,AI_DATABASE_URL:runtime.databaseUrl,AI_GATEWAY_SECRET:runtime.secret,AI_PORT:String(port),TEST_MODE:base.TEST_MODE,PAPER_MARKET_PROVIDER:base.PAPER_MARKET_PROVIDER};
}
