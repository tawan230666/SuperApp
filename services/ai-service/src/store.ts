import pg from 'pg';
import type {Freshness} from './output.js';
import {readValuation,readBotStatus,FixtureMarketDataProvider,DeterministicMarketDataProvider} from '@tipkhun/financial-read';
const url=process.env.AI_DATABASE_URL;
// Fail closed: never fall back to the owner credential used by execution services.
export const aiPool=new pg.Pool({connectionString:url??'postgres://unconfigured:unconfigured@127.0.0.1:1/unconfigured',max:4,connectionTimeoutMillis:3000,options:'-c timezone=UTC -c statement_timeout=10000'});
aiPool.on('error',()=>console.error('AI database unavailable'));
export async function assertIsolation(){
 if(!url||process.env.DATABASE_URL||!process.env.AI_GATEWAY_SECRET||process.env.AI_GATEWAY_SECRET.length<64)throw new Error('Isolated AI configuration required');
 const role=(await aiPool.query("SELECT r.rolsuper,r.rolcreatedb,r.rolcreaterole,r.rolreplication,r.rolbypassrls,current_user=session_user AS direct,pg_has_role(current_user,'tipkhun_ai','MEMBER') AS allowed FROM pg_roles r WHERE rolname=current_user")).rows[0];
 if(!role?.allowed||!role.direct||role.rolsuper||role.rolcreatedb||role.rolcreaterole||role.rolreplication||role.rolbypassrls)throw new Error('Unsafe AI role');
 const memberships=await aiPool.query("SELECT rolname FROM pg_roles WHERE rolname NOT IN(current_user,'tipkhun_ai') AND pg_has_role(current_user,oid,'MEMBER')");
 if(memberships.rowCount)throw new Error('Unexpected AI membership');
 const tables=(await aiPool.query(`SELECT c.relname,pg_get_userbyid(c.relowner)=current_user AS owned,
 has_table_privilege(c.oid,'INSERT') AS ins,has_any_column_privilege(c.oid,'INSERT') AS col_ins,
 has_table_privilege(c.oid,'UPDATE') AS upd,has_any_column_privilege(c.oid,'UPDATE') AS col_upd,
 has_table_privilege(c.oid,'DELETE,TRUNCATE,TRIGGER,REFERENCES') AS extra
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind IN('r','p','v','f')`)).rows;
 if(tables.some(t=>t.owned||t.upd||t.col_upd||t.extra||((t.ins||t.col_ins)&&!['ai_decisions','ai_audit_records'].includes(t.relname))))throw new Error('AI financial write privilege detected');
 for(const table of ['users','auth_sessions','auth_tokens'])if((await aiPool.query('SELECT has_any_column_privilege($1,\'SELECT\') AS allowed',[table])).rows[0].allowed)throw new Error('AI credential access detected');
 if((await aiPool.query("SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef AND has_function_privilege(p.oid,'EXECUTE')")).rowCount)throw new Error('AI privileged routine access detected');
 await aiPool.query('SELECT id FROM ai_audit_records LIMIT 0');
}
async function scoped<T>(user:string,readOnly:boolean,work:(c:pg.PoolClient)=>Promise<T>){
 const c=await aiPool.connect();try{await c.query(readOnly?'BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY':'BEGIN');await c.query("SELECT set_config('app.ai_user_id',$1,true)",[user]);const result=await work(c);await c.query('COMMIT');return result;}catch(e){await c.query('ROLLBACK');throw e;}finally{c.release();}
}
export async function readContext(user:string){return scoped(user,true,async c=>{
 const observedAt=(await c.query('SELECT now() AS time')).rows[0].time.toISOString();
 const test=['test','development'].includes(process.env.NODE_ENV??'')&&process.env.TEST_MODE==='1'&&process.env.PAPER_MARKET_PROVIDER==='deterministic'&&new URL(url!).pathname.endsWith('_test');
 const market=test?new DeterministicMarketDataProvider(user,c):new FixtureMarketDataProvider(user,c);
 // Missing/stale market data yields explicit unavailability; no historical quote is passed off as current.
 let portfolio:Awaited<ReturnType<typeof readValuation>>|null=null;let portfolioError:string|null=null;
 try{portfolio=await readValuation(c,user,market);}catch(e){if(e instanceof Error&&['MARKET_DATA_STALE','MARKET_DATA_UNAVAILABLE','MARKET_CLOSED','ASSET_NOT_FOUND'].includes(e.message))portfolioError=e.message;else throw e;}
 const bot=await readBotStatus(c,user);
 const plan=(await c.query('SELECT v.* FROM investment_plans p JOIN plan_versions v ON v.plan_id=p.id WHERE p.user_id=$1 ORDER BY v.version DESC LIMIT 1',[user])).rows[0]??null;
 const profile=(await c.query('SELECT risk_tolerance_bps,daily_loss_limit_minor,risk_per_trade_minor,max_trades,max_positions,max_drawdown_bps FROM risk_profiles WHERE user_id=$1',[user])).rows[0]??null;
 const ledger=(await c.query("SELECT a.bucket,coalesce(sum(CASE WHEN e.direction='CREDIT' THEN e.amount_minor ELSE -e.amount_minor END),0)::text AS balance_minor FROM ledger_accounts a LEFT JOIN ledger_entries e ON e.ledger_account_id=a.id WHERE a.user_id=$1 GROUP BY a.bucket ORDER BY a.bucket",[user])).rows;
 const allocations=(await c.query('SELECT * FROM allocation_batches WHERE user_id=$1 ORDER BY created_at DESC LIMIT 20',[user])).rows;
 const watchlist=(await c.query('SELECT a.symbol,a.name,a.sector FROM watchlists w JOIN watchlist_assets wa ON wa.watchlist_id=w.id JOIN assets a ON a.id=wa.asset_id WHERE w.user_id=$1 ORDER BY a.symbol',[user])).rows;
 // Aggregate the full owned history, independently of the 20-row UI preview.
 const tradingRow=(await c.query<{total_trades:string;net_pnl_minor:string}>("SELECT count(*)::text AS total_trades,coalesce(sum(t.net_pnl_minor),0)::text AS net_pnl_minor FROM trades t JOIN accounts a ON a.id=t.account_id WHERE a.user_id=$1",[user])).rows[0];
 const profitRow=(await c.query<{total_minor:string}>("SELECT coalesce(sum(amount_minor),0)::text AS total_minor FROM allocation_batches WHERE user_id=$1",[user])).rows[0];
 const trading={totalTrades:tradingRow.total_trades,netPnlMinor:tradingRow.net_pnl_minor};
 const profit={totalMinor:profitRow.total_minor};
 const quotes=portfolio?.holdings.map(h=>h.quote)??[];
 const freshness:Freshness={
  risk:{source:'PostgreSQL risk_profiles / plan_versions',observedAt,dataAsOf:null,status:plan?'CURRENT_SNAPSHOT':'EMPTY',note:'Configured limits read now; not available trading budget or a RiskDecision'},
  trading:{source:'PostgreSQL trades / accounts / bot_sessions',observedAt,dataAsOf:null,status:trading.totalTrades==='0'?'EMPTY':'STORED_HISTORY',note:'Full persisted trade history and stored bot status; no reconciliation performed'},
  profit:{source:'PostgreSQL allocation_batches / ledger_entries',observedAt,dataAsOf:null,status:profit.totalMinor==='0'?'EMPTY':'STORED_HISTORY',note:'All persisted allocations; allocated amounts are not available cash'},
  portfolio:{source:'PostgreSQL holdings / synthetic fixture quotes',observedAt,dataAsOf:quotes.length?quotes.map(q=>q.asOf).sort()[0]:null,status:portfolioError==='MARKET_DATA_STALE'?'STALE':portfolioError?'UNAVAILABLE':quotes.some(q=>q.isDelayed)?'DELAYED':quotes.length?'CURRENT_SNAPSHOT':'EMPTY',note:'Synthetic Paper valuation only; quote timestamps describe fixtures, not live market freshness'},
 };
 return {observedAt,mode:'PAPER' as const,source:'synthetic fixture',reconciliation:'Stored status only; no reconciliation performed',riskAuthority:'Risk Engine; this context is not execution authorization',freshness,trading,profit,portfolio,portfolioError,bot,plan,profile,ledger,allocations,watchlist};
 });}
export type FinancialContext=Awaited<ReturnType<typeof readContext>>;
export async function saveDecision(user:string,requestId:string,proposal:unknown){return scoped(user,false,async c=>{
 const saved=(await c.query("INSERT INTO ai_decisions(user_id,agent_type,proposal) VALUES($1,'mock-copilot-v1',$2) RETURNING id,created_at",[user,JSON.stringify(proposal)])).rows[0];
 await c.query("INSERT INTO ai_audit_records(user_id,decision_id,request_id,action) VALUES($1,$2,$3,'AI_PROPOSAL_RECORDED')",[user,saved.id,requestId]);return saved;
 });}
export async function decisions(user:string){return scoped(user,true,async c=>(await c.query("SELECT id,agent_type,proposal,created_at FROM ai_decisions WHERE user_id=$1 ORDER BY created_at DESC,id DESC LIMIT 50",[user])).rows);}
