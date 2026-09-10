import {createHash} from 'node:crypto';
import {z} from 'zod';
import {pool,transaction,type PoolClient} from '@tipkhun/database';
import {audit,HttpError} from '@tipkhun/auth';
import {currentPlan,lockOwner,transitionOrder,ensureLedgerAccounts,ledgerTransaction,notify} from '@tipkhun/risk-data';
export const orderSchema=z.object({instrument:z.literal('SYNTHETIC-THB'),quantity:z.string().regex(/^[1-9][0-9]{0,5}$/),type:z.literal('MARKET'),scenario:z.enum(['fill','partial','reject','error','unknown','slippage','profit','profit101','even']).default('fill')}).strict();
const fee=(notional:bigint)=>(notional+999n)/1000n; // 10bps rounded up in minor units.
export async function account(c:PoolClient,userId:string){return (await c.query("SELECT * FROM accounts WHERE user_id=$1 AND environment='paper'",[userId])).rows[0]??null;}
async function ownedOrder(c:PoolClient,userId:string,id:string){const o=(await c.query("SELECT o.* FROM orders o JOIN accounts a ON a.id=o.account_id WHERE o.id=$1 AND a.user_id=$2 AND o.paper_order",[id,userId])).rows[0];if(!o)throw new HttpError(404,'Order not found');return o;}
async function release(c:PoolClient,orderId:string){await c.query('UPDATE risk_reservations SET released_at=now() WHERE order_id=$1',[orderId]);}
async function record(c:PoolClient,userId:string,action:string,entity:string,id:string,requestId:string){await audit(c,userId,action,entity,id,requestId);const events:Record<string,string>={BOT_STARTED:'BOT_HEARTBEAT_MISSED',EMERGENCY_STOP:'EMERGENCY_STOP_TRIGGERED',ORDER_REJECTED:'ORDER_REJECTED',ORDER_FILLED:'POSITION_OPENED',POSITION_CLOSED:'POSITION_CLOSED'};if(events[action])await notify(c,userId,events[action],entity,id,{});}
export class PaperBrokerAdapter {
 async fill(c:PoolClient,o:any,continuation=false){
  const existing=(await c.query('SELECT * FROM paper_broker_orders WHERE order_id=$1',[o.id])).rows[0];
  if(existing&&['CANCELLED','REJECTED','FILLED','CLOSED'].includes(existing.state))throw new HttpError(409,'Broker order is terminal');
  if(o.scenario==='error')throw new Error('Paper broker injected error');
  if(o.scenario==='unknown')return {kind:'unknown' as const};
  await c.query("INSERT INTO paper_broker_orders(order_id,state) VALUES($1,'ACKNOWLEDGED') ON CONFLICT(order_id) DO NOTHING",[o.id]);
  if(o.scenario==='reject'){await c.query("UPDATE paper_broker_orders SET state='REJECTED' WHERE order_id=$1",[o.id]);return {kind:'reject' as const};}
  const remaining=BigInt(o.quantity)-BigInt(o.filled_quantity);
  const qty=o.scenario==='partial'&&!continuation&&remaining>1n?(remaining+1n)/2n:remaining;
  const price=BigInt(o.price_minor),notional=qty*price,fees=fee(notional);
  await c.query("INSERT INTO paper_broker_fills(order_id,side,quantity,price_minor,fee_minor) VALUES($1,'BUY',$2,$3,$4)",[o.id,qty.toString(),price.toString(),fees.toString()]);
  const filled=BigInt(o.filled_quantity)+qty,state=filled===BigInt(o.quantity)?'FILLED':'PARTIALLY_FILLED';
  await c.query('UPDATE paper_broker_orders SET state=$2,filled_quantity=$3 WHERE order_id=$1',[o.id,state,filled.toString()]);
  return {kind:'fill' as const,qty,price,notional,fees,filled,state};
 }
 async cancel(c:PoolClient,o:any){
  if(o.state==='UNKNOWN')throw new HttpError(409,'Unknown broker outcome requires reconciliation');
  await c.query("UPDATE paper_broker_orders SET state='CANCELLED' WHERE order_id=$1 AND state NOT IN ('FILLED','CLOSED','REJECTED')",[o.id]);
 }
}
const broker=new PaperBrokerAdapter();
async function cancelLocked(c:PoolClient,userId:string,o:any,requestId:string){
 if(['CANCELLED','REJECTED','CLOSED','EXPIRED'].includes(o.state))return;
 if(o.state==='FILLED')throw new HttpError(409,'Filled order requires explicit position close');
 if(o.state==='CREATED'){await transitionOrder(c,o,'REJECTED','Stopped before risk approval');await record(c,userId,'ORDER_REJECTED','Order',o.id,requestId);return;}
 await broker.cancel(c,o);await transitionOrder(c,o,'CANCELLED','Paper cancellation confirmed');
 if(BigInt(o.filled_quantity)===0n)await release(c,o.id);
 else await c.query('UPDATE risk_reservations SET amount_minor=$2 WHERE order_id=$1',[o.id,(BigInt(o.filled_quantity)*(BigInt(o.price_minor)+2n)).toString()]);
}
export async function control(userId:string,action:string,requestId:string){
 return transaction(async c=>{
  await lockOwner(c,userId);let a=await account(c,userId);
  if(!a){if(action!=='start')throw new HttpError(409,'Start a paper account first');const p=await currentPlan(c,userId);if(!p)throw new HttpError(409,'Create a risk plan first');
   a=(await c.query("INSERT INTO accounts(user_id,environment,initial_capital_minor,cash_minor) VALUES($1,'paper',$2,$2) RETURNING *",[userId,p.capitalMinor])).rows[0];
   await c.query('INSERT INTO paper_broker_accounts(account_id,initial_capital_minor) VALUES($1,$2)',[a.id,p.capitalMinor]);
   await c.query("INSERT INTO bot_sessions(account_id,state) VALUES($1,'READY')",[a.id]);
   await ensureLedgerAccounts(c,userId,a.id);
   await ledgerTransaction(c,userId,a.id,'OPENING_CAPITAL',a.id,'opening:'+a.id,[{bucket:'PAPER_CASH',direction:'DEBIT',amount:BigInt(p.capitalMinor)},{bucket:'TRADING_CAPITAL',direction:'CREDIT',amount:BigInt(p.capitalMinor)}]);
  }
  await ensureLedgerAccounts(c,userId,a.id);
  const session=(await c.query('SELECT * FROM bot_sessions WHERE account_id=$1',[a.id])).rows[0];
  if(['start','resume'].includes(action)&&(a.emergency_stop||a.reconciliation_state!=='OK'))throw new HttpError(409,'Emergency stop or reconciliation is active');
  const targets:Record<string,string>={start:'RUNNING',pause:'PAUSED',resume:'RUNNING',stop:'STOPPED','emergency-stop':'EMERGENCY_STOPPED'};
  const allowed:Record<string,string[]>={start:['READY','STOPPED'],pause:['RUNNING'],resume:['PAUSED'],stop:['READY','RUNNING','PAUSED','STOPPED'],'emergency-stop':['READY','RUNNING','PAUSED','STOPPED','ERROR','EMERGENCY_STOPPED']};
  if(!allowed[action]?.includes(session.state))throw new HttpError(409,'Invalid bot transition');
  if(action==='emergency-stop')await c.query('UPDATE accounts SET emergency_stop=true WHERE id=$1',[a.id]);
  if(['stop','emergency-stop'].includes(action)){
   const pending=await c.query("SELECT * FROM orders WHERE account_id=$1 AND paper_order AND state NOT IN ('FILLED','CLOSED','REJECTED','CANCELLED','EXPIRED')",[a.id]);
   for(const o of pending.rows){if(o.state==='UNKNOWN'){await c.query("UPDATE accounts SET reconciliation_state='RECONCILIATION_REQUIRED' WHERE id=$1",[a.id]);continue;}await cancelLocked(c,userId,o,requestId);}
  }
  await c.query("UPDATE bot_sessions SET state=$2,emergency_stop=$3,last_heartbeat=now(),started_at=CASE WHEN $4='start' THEN now() ELSE started_at END,stopped_at=CASE WHEN $2 IN ('STOPPED','EMERGENCY_STOPPED') THEN now() ELSE NULL END WHERE account_id=$1",[a.id,targets[action],action==='emergency-stop'||a.emergency_stop,action]);
  const actions:Record<string,string>={start:'BOT_STARTED',pause:'BOT_PAUSED',resume:'BOT_RESUMED',stop:'BOT_STOPPED','emergency-stop':'EMERGENCY_STOP'};
  await record(c,userId,actions[action],'BotSession',session.id,requestId);
  return {state:targets[action],paperAccountId:a.id,mode:'PAPER',closePolicy:'Open positions require explicit close; emergency stop does not liquidate them'};
 });
}
export async function createOrder(userId:string,input:unknown,key:string,token:string,requestId:string){
 const d=orderSchema.parse(input);if(['profit','profit101','even'].includes(d.scenario)&&process.env.NODE_ENV!=='test'&&process.env.TEST_MODE!=='1')throw new HttpError(400,'Test price scenario is disabled');if(!/^[A-Za-z0-9_.:-]{8,128}$/.test(key))throw new HttpError(400,'Idempotency-Key (8-128 safe characters) required');
 const hash=createHash('sha256').update(JSON.stringify(d)).digest('hex');
 const o=await transaction(async c=>{
  await lockOwner(c,userId);const a=await account(c,userId);if(!a)throw new HttpError(409,'Start paper account first');
  const existing=(await c.query('SELECT * FROM orders WHERE account_id=$1 AND idempotency_key=$2',[a.id,key])).rows[0];
  if(existing){if(existing.request_hash!==hash)throw new HttpError(409,'Idempotency key reused with different payload');return existing;}
  const b=(await c.query('SELECT state FROM bot_sessions WHERE account_id=$1',[a.id])).rows[0];
  if(a.emergency_stop||b.state!=='RUNNING'||a.reconciliation_state!=='OK')throw new HttpError(409,'Paper bot cannot accept new orders');
  const price=d.scenario==='slippage'?102n:101n,qty=BigInt(d.quantity),risk=qty*(price+2n);
  const row=(await c.query("INSERT INTO orders(account_id,idempotency_key,state,requested_risk_minor,paper_order,quantity,price_minor,scenario,request_hash) VALUES($1,$2,'CREATED',$3,true,$4,$5,$6,$7) RETURNING *",[a.id,key,risk.toString(),d.quantity,price.toString(),d.scenario,hash])).rows[0];
  await c.query("INSERT INTO order_events(order_id,to_state,reason) VALUES($1,'CREATED','User paper proposal')",[row.id]);await record(c,userId,'ORDER_CREATED','Order',row.id,requestId);return row;
 });
 if(o.state==='CREATED'){
  let response:Response;try{response=await fetch(`${process.env.RISK_SERVICE_URL??'http://localhost:3001'}/v1/risk/reserve`,{method:'POST',headers:{'content-type':'application/json',authorization:token},body:JSON.stringify({orderId:o.id}),signal:AbortSignal.timeout(5000)});}catch{throw new HttpError(503,'Risk Service unavailable; retry with same idempotency key');}
  if(!response.ok)throw new HttpError(response.status,'Risk reservation failed');
  const decision=await response.json() as {approved:boolean};if(!decision.approved)return getOrder(userId,o.id);
 }
 return execute(userId,o.id,requestId,false);
}
export async function execute(userId:string,orderId:string,requestId:string,continuation:boolean){
 try{return await transaction(async c=>{
  await lockOwner(c,userId);const o=await ownedOrder(c,userId,orderId),a=await account(c,userId);const b=(await c.query('SELECT state FROM bot_sessions WHERE account_id=$1',[a.id])).rows[0];
  if(!(o.state==='RISK_CHECKED'||(continuation&&o.state==='PARTIALLY_FILLED')))return o;
  if(a.emergency_stop||b.state!=='RUNNING'||a.reconciliation_state!=='OK'){await cancelLocked(c,userId,o,requestId);return o;}
  if(!(await c.query('SELECT order_id FROM risk_reservations WHERE order_id=$1 AND released_at IS NULL',[o.id])).rowCount)throw new HttpError(409,'Committed risk reservation required');
  if(o.state==='RISK_CHECKED')await transitionOrder(c,o,'SUBMITTED','Reservation verified before broker submission');
  const result=await broker.fill(c,o,continuation);
  if(result.kind==='unknown'){await transitionOrder(c,o,'UNKNOWN','Paper broker outcome unknown');await c.query("UPDATE accounts SET reconciliation_state='RECONCILIATION_REQUIRED' WHERE id=$1",[a.id]);return o;}
  if(o.state==='SUBMITTED')await transitionOrder(c,o,'ACKNOWLEDGED','Paper broker acknowledgement');
  if(result.kind==='reject'){await transitionOrder(c,o,'REJECTED','Paper broker rejected order');await release(c,o.id);await record(c,userId,'ORDER_REJECTED','Order',o.id,requestId);return o;}
  await c.query('UPDATE orders SET filled_quantity=$2 WHERE id=$1',[o.id,result.filled.toString()]);
  await transitionOrder(c,o,result.state,'Paper fill recorded');
  const position=(await c.query("INSERT INTO positions(account_id,order_id,instrument,quantity,cost_minor,state,entry_fees_minor) VALUES($1,$2,'SYNTHETIC-THB',$3,$4,'OPEN',$5) ON CONFLICT(order_id) DO UPDATE SET quantity=positions.quantity+EXCLUDED.quantity,cost_minor=positions.cost_minor+EXCLUDED.cost_minor,entry_fees_minor=positions.entry_fees_minor+EXCLUDED.entry_fees_minor RETURNING id",[a.id,o.id,result.qty.toString(),result.notional.toString(),result.fees.toString()])).rows[0];
  await c.query('UPDATE accounts SET cash_minor=cash_minor-$2,fees_minor=fees_minor+$3 WHERE id=$1',[a.id,(result.notional+result.fees).toString(),result.fees.toString()]);
  await ledgerTransaction(c,userId,a.id,'PAPER_BUY',o.id,`buy:${o.id}:${result.filled.toString()}`,[{bucket:'TRADING_CAPITAL',direction:'DEBIT',amount:result.notional},{bucket:'PAPER_CASH',direction:'CREDIT',amount:result.notional},{bucket:'FEES',direction:'DEBIT',amount:result.fees},{bucket:'PAPER_CASH',direction:'CREDIT',amount:result.fees}]);
  await record(c,userId,'ORDER_FILLED','Order',o.id,requestId);if(BigInt(o.filled_quantity)===0n)await record(c,userId,'POSITION_OPENED','Position',position.id,requestId);
  return (await c.query('SELECT * FROM orders WHERE id=$1',[o.id])).rows[0];
 });}catch(e){if(e instanceof HttpError)throw e;
  await transaction(async c=>{await lockOwner(c,userId);const o=await ownedOrder(c,userId,orderId);if(['RISK_CHECKED','PARTIALLY_FILLED'].includes(o.state)){if(o.state==='RISK_CHECKED')await transitionOrder(c,o,'SUBMITTED','Submission attempt rolled back');await transitionOrder(c,o,'UNKNOWN','Broker/database error; reconciliation required');await c.query("UPDATE accounts SET reconciliation_state='RECONCILIATION_REQUIRED' WHERE id=$1",[o.account_id]);}});
  throw new HttpError(503,'Paper broker error; reserved risk retained for reconciliation');
 }
}
export async function getOrder(userId:string,id:string){return transaction(c=>ownedOrder(c,userId,id));}
export async function getPosition(userId:string,id:string){return transaction(async c=>{const r=(await c.query("SELECT p.* FROM positions p JOIN accounts a ON a.id=p.account_id WHERE p.id=$1 AND a.user_id=$2 AND a.environment='paper'",[id,userId])).rows[0];if(!r)throw new HttpError(404,'Position not found');return r;});}
export async function getTrade(userId:string,id:string){return transaction(async c=>{const r=(await c.query("SELECT t.* FROM trades t JOIN accounts a ON a.id=t.account_id WHERE t.id=$1 AND a.user_id=$2 AND a.environment='paper'",[id,userId])).rows[0];if(!r)throw new HttpError(404,'Trade not found');return r;});}
export async function cancelOrder(userId:string,id:string,requestId:string){return transaction(async c=>{await lockOwner(c,userId);const o=await ownedOrder(c,userId,id);await cancelLocked(c,userId,o,requestId);return o;});}
export async function closePosition(userId:string,id:string,requestId:string){return transaction(async c=>{
 await lockOwner(c,userId);const p=(await c.query("SELECT p.* FROM positions p JOIN accounts a ON a.id=p.account_id WHERE p.id=$1 AND a.user_id=$2 AND a.environment='paper'",[id,userId])).rows[0];if(!p)throw new HttpError(404,'Position not found');
 if(p.state==='CLOSED')return (await c.query('SELECT * FROM trades WHERE paper_order_id=$1',[p.order_id])).rows[0];
 const o=await ownedOrder(c,userId,p.order_id);if(o.state==='UNKNOWN')throw new HttpError(409,'Unknown outcome requires reconciliation before closing');
 if(o.state==='PARTIALLY_FILLED')await cancelLocked(c,userId,o,requestId);
 const quantity=BigInt(String(p.quantity).split('.')[0]),price=o.scenario==='profit'?120n:o.scenario==='profit101'?204n:o.scenario==='even'?101n:99n,proceeds=quantity*price,fees=fee(proceeds),net=proceeds-BigInt(p.cost_minor)-BigInt(p.entry_fees_minor)-fees;
 await c.query("INSERT INTO paper_broker_fills(order_id,side,quantity,price_minor,fee_minor) VALUES($1,'SELL',$2,$3,$4)",[o.id,quantity.toString(),price.toString(),fees.toString()]);
 await c.query("UPDATE paper_broker_orders SET state='CLOSED' WHERE order_id=$1",[o.id]);
 await c.query("UPDATE positions SET state='CLOSED' WHERE id=$1",[p.id]);
 const trade=(await c.query("INSERT INTO trades(account_id,plan_version_id,paper_order_id,net_pnl_minor,fees_minor,mode) VALUES($1,$2,$3,$4,$5,'paper') RETURNING *",[p.account_id,o.plan_version_id,o.id,net.toString(),(BigInt(p.entry_fees_minor)+fees).toString()])).rows[0];
 await c.query('UPDATE accounts SET cash_minor=cash_minor+$2,fees_minor=fees_minor+$3,realized_pnl_minor=realized_pnl_minor+$4 WHERE id=$1',[p.account_id,(proceeds-fees).toString(),fees.toString(),net.toString()]);
 const pricePnl=proceeds-BigInt(p.cost_minor);
 const settlement=[{bucket:'PAPER_CASH',direction:'DEBIT' as const,amount:proceeds},{bucket:'TRADING_CAPITAL',direction:'CREDIT' as const,amount:BigInt(p.cost_minor)}]; if(pricePnl!==0n) settlement.push({bucket:'REALIZED_PROFIT',direction:pricePnl>0n?'CREDIT':'DEBIT',amount:pricePnl>0n?pricePnl:-pricePnl});
 await ledgerTransaction(c,userId,p.account_id,'PAPER_SETTLEMENT',o.id,`settle:${o.id}`,settlement);
 await ledgerTransaction(c,userId,p.account_id,'PAPER_EXIT_FEE',o.id,`exit-fee:${o.id}`,[{bucket:'FEES',direction:'DEBIT',amount:fees},{bucket:'PAPER_CASH',direction:'CREDIT',amount:fees}]);
 const allFees=BigInt(p.entry_fees_minor)+fees;
 if(allFees>0n) await ledgerTransaction(c,userId,p.account_id,'PAPER_FEE_TO_PNL',o.id,`fee-pnl:${o.id}`,[{bucket:'REALIZED_PROFIT',direction:'DEBIT',amount:allFees},{bucket:'FEES',direction:'CREDIT',amount:allFees}]);
 await transitionOrder(c,o,'CLOSED','Explicit paper position close confirmed');await release(c,o.id);await record(c,userId,'POSITION_CLOSED','Position',p.id,requestId);return trade;
});}
export async function reconcileLocked(c:PoolClient,a:any){
 const initial=(await c.query('SELECT initial_capital_minor FROM paper_broker_accounts WHERE account_id=$1',[a.id])).rows[0];
 const fills=(await c.query("SELECT coalesce(sum(CASE WHEN f.side='BUY' THEN -f.quantity*f.price_minor-f.fee_minor ELSE f.quantity*f.price_minor-f.fee_minor END),0)::text AS change,coalesce(sum(f.fee_minor),0)::text AS fees FROM paper_broker_fills f JOIN orders o ON o.id=f.order_id WHERE o.account_id=$1",[a.id])).rows[0];
 const unknowns=(await c.query("SELECT o.*,b.state AS broker_state,b.filled_quantity AS broker_filled FROM orders o JOIN paper_broker_orders b ON b.order_id=o.id WHERE o.account_id=$1 AND o.paper_order AND o.state='UNKNOWN'",[a.id])).rows;
  let recovered = false;
  for(const o of unknowns){
  if(o.broker_state==='FILLED' || o.broker_state==='PARTIALLY_FILLED') {
   recovered = true;
   await c.query('UPDATE orders SET state=$2,filled_quantity=$3 WHERE id=$1',[o.id,o.broker_state,o.broker_filled]);
   const fill=(await c.query("SELECT coalesce(sum(quantity),0)::text AS qty,coalesce(sum(quantity*price_minor),0)::text AS cost,coalesce(sum(fee_minor),0)::text AS fees FROM paper_broker_fills WHERE order_id=$1 AND side='BUY'",[o.id])).rows[0];
   if(BigInt(fill.qty)>0n && !(await c.query('SELECT id FROM positions WHERE order_id=$1',[o.id])).rowCount){
    await c.query("INSERT INTO positions(account_id,order_id,instrument,quantity,cost_minor,state,entry_fees_minor) VALUES($1,$2,'SYNTHETIC-THB',$3,$4,'OPEN',$5)",[o.account_id,o.id,fill.qty,fill.cost,fill.fees]);
    await c.query('UPDATE accounts SET cash_minor=cash_minor-$2,fees_minor=fees_minor+$3 WHERE id=$1',[o.account_id,(BigInt(fill.cost)+BigInt(fill.fees)).toString(),fill.fees]);
   }
  }
  else if(o.broker_state==='CANCELLED') await c.query("UPDATE orders SET state='CANCELLED' WHERE id=$1",[o.id]);
 }
 if(recovered) { await c.query("UPDATE accounts SET cash_minor=initial_capital_minor+(SELECT coalesce(sum(CASE WHEN f.side='BUY' THEN -f.quantity*f.price_minor-f.fee_minor ELSE f.quantity*f.price_minor-f.fee_minor END),0) FROM paper_broker_fills f JOIN orders o ON o.id=f.order_id WHERE o.account_id=$1),fees_minor=(SELECT coalesce(sum(fee_minor),0) FROM paper_broker_fills f JOIN orders o ON o.id=f.order_id WHERE o.account_id=$1) WHERE id=$1",[a.id]); const refreshed=(await c.query('SELECT cash_minor,fees_minor FROM accounts WHERE id=$1',[a.id])).rows[0]; a.cash_minor=refreshed.cash_minor; a.fees_minor=refreshed.fees_minor; }
 const mismatch=(await c.query("SELECT o.id FROM orders o LEFT JOIN paper_broker_orders b ON b.order_id=o.id LEFT JOIN positions p ON p.order_id=o.id WHERE o.account_id=$1 AND o.paper_order AND (o.state='UNKNOWN' OR (o.filled_quantity>0 AND (b.order_id IS NULL OR b.filled_quantity<>o.filled_quantity OR p.id IS NULL)) OR (b.order_id IS NOT NULL AND b.state<>o.state))",[a.id])).rowCount;
 const net=(await c.query('SELECT coalesce(sum(net_pnl_minor),0)::text AS net FROM trades WHERE account_id=$1',[a.id])).rows[0].net;
 const details=(await c.query(`SELECT o.id,o.state,o.filled_quantity,p.quantity::text AS quantity,p.state AS position_state,p.cost_minor,p.entry_fees_minor,t.net_pnl_minor,t.fees_minor,
 coalesce(f.bought,0)::text AS bought,coalesce(f.sold,0)::text AS sold,coalesce(f.cost,0)::text AS cost,coalesce(f.proceeds,0)::text AS proceeds,coalesce(f.entry_fees,0)::text AS entry_fees,coalesce(f.exit_fees,0)::text AS exit_fees
 FROM orders o LEFT JOIN positions p ON p.order_id=o.id LEFT JOIN trades t ON t.paper_order_id=o.id LEFT JOIN LATERAL
 (SELECT sum(quantity) FILTER(WHERE side='BUY') AS bought,sum(quantity) FILTER(WHERE side='SELL') AS sold,sum(quantity*price_minor) FILTER(WHERE side='BUY') AS cost,sum(quantity*price_minor) FILTER(WHERE side='SELL') AS proceeds,sum(fee_minor) FILTER(WHERE side='BUY') AS entry_fees,sum(fee_minor) FILTER(WHERE side='SELL') AS exit_fees FROM paper_broker_fills WHERE order_id=o.id) f ON true WHERE o.account_id=$1 AND o.paper_order`,[a.id])).rows;
 const ledgerMismatch=details.some(d=>{
  if(BigInt(d.bought)!==BigInt(d.filled_quantity))return true;
  if(BigInt(d.bought)===0n)return d.quantity!==null;
  if(!d.quantity||BigInt(d.quantity.split('.')[0])!==BigInt(d.bought)||BigInt(d.cost_minor)!==BigInt(d.cost)||BigInt(d.entry_fees_minor)!==BigInt(d.entry_fees))return true;
  if(d.state==='CLOSED')return d.position_state!=='CLOSED'||BigInt(d.sold)!==BigInt(d.bought)||d.net_pnl_minor===null||BigInt(d.net_pnl_minor)!==BigInt(d.proceeds)-BigInt(d.cost)-BigInt(d.entry_fees)-BigInt(d.exit_fees)||BigInt(d.fees_minor)!==BigInt(d.entry_fees)+BigInt(d.exit_fees);
  return d.position_state!=='OPEN'||BigInt(d.sold)!==0n||d.net_pnl_minor!==null;
 });
 const ok=initial&&!ledgerMismatch&&BigInt(a.initial_capital_minor)===BigInt(initial.initial_capital_minor)&&BigInt(a.cash_minor)===BigInt(initial.initial_capital_minor)+BigInt(fills.change)&&BigInt(a.fees_minor)===BigInt(fills.fees)&&BigInt(a.realized_pnl_minor)===BigInt(net)&&!mismatch;
 if(!ok){await c.query("UPDATE accounts SET reconciliation_state='RECONCILIATION_REQUIRED' WHERE id=$1",[a.id]);await c.query("UPDATE bot_sessions SET state=CASE WHEN emergency_stop THEN 'EMERGENCY_STOPPED' ELSE 'ERROR' END WHERE account_id=$1",[a.id]);}
 else if(a.reconciliation_state==='RECONCILIATION_REQUIRED'){await c.query("UPDATE accounts SET reconciliation_state='OK' WHERE id=$1",[a.id]);await c.query("UPDATE bot_sessions SET state=CASE WHEN state='ERROR' THEN 'STOPPED' ELSE state END WHERE account_id=$1",[a.id]);}
 return {status:ok?'OK':'RECONCILIATION_REQUIRED',mode:'PAPER'};
}
export async function reconcile(userId:string){return transaction(async c=>{await lockOwner(c,userId);const a=await account(c,userId);if(!a)throw new HttpError(404,'Paper account not found');return reconcileLocked(c,a);});}
export async function recover(){const users=await pool.query("SELECT DISTINCT user_id FROM accounts WHERE environment='paper'");for(const row of users.rows)await reconcile(row.user_id);}
export async function status(userId:string){return transaction(async c=>{
 await lockOwner(c,userId);const a=await account(c,userId);if(!a)return {mode:'PAPER',liveTrading:'LOCKED',state:'READY',account:null,brokerStatus:'NOT_STARTED'};
 const reconciliation=await reconcileLocked(c,a);const b=(await c.query('SELECT * FROM bot_sessions WHERE account_id=$1',[a.id])).rows[0];
  const p=(await c.query("SELECT coalesce(sum(quantity*101),0)::text AS value,coalesce(sum(quantity*101-cost_minor),0)::text AS unrealized,count(*)::int AS count FROM positions WHERE account_id=$1 AND state='OPEN'",[a.id])).rows[0];
 const pending=(await c.query("SELECT count(*)::int AS n FROM orders WHERE account_id=$1 AND paper_order AND state IN ('CREATED','RISK_CHECKED','SUBMITTED','ACKNOWLEDGED','PARTIALLY_FILLED','UNKNOWN')",[a.id])).rows[0].n;
 const daily=(await c.query("SELECT coalesce(sum(net_pnl_minor),0)::text AS pnl FROM trades WHERE account_id=$1 AND created_at>=date_trunc('day',now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC'",[a.id])).rows[0].pnl;
 const stale=b.last_heartbeat&&Date.now()-new Date(b.last_heartbeat).getTime()>15000; return {mode:'PAPER',liveTrading:'LOCKED',state:b.state,healthStatus:reconciliation.status!=='OK'?'RECONCILIATION_REQUIRED':stale?'STALE':b.state==='RUNNING'?'HEALTHY':'DEGRADED',paperAccountId:a.id,account:{cashMinor:a.cash_minor,equityMinor:(BigInt(a.cash_minor)+BigInt(p.value.split('.')[0])).toString(),realizedPnlMinor:a.realized_pnl_minor,unrealizedPnlMinor:p.unrealized,feesMinor:a.fees_minor},openPositions:p.count,pendingOrders:pending,dailyPnlMinor:daily,lastHeartbeat:b.last_heartbeat,strategyVersion:b.strategy_version,brokerStatus:reconciliation.status==='OK'?'PAPER_CONNECTED':'RECONCILIATION_REQUIRED',closePolicy:'Explicit close only; emergency does not liquidate'};
});}
export async function heartbeat(){await pool.query("UPDATE bot_sessions SET last_heartbeat=now() WHERE state IN ('RUNNING','PAUSED') AND account_id IN (SELECT id FROM accounts WHERE environment='paper')");}
export async function monitor(){
 const stale=await pool.query("SELECT b.account_id,a.user_id FROM bot_sessions b JOIN accounts a ON a.id=b.account_id WHERE b.state='RUNNING' AND (b.last_heartbeat IS NULL OR b.last_heartbeat<now()-interval '15 seconds')");
 for(const row of stale.rows) await transaction(async c=>{await c.query("UPDATE accounts SET reconciliation_state='RECONCILIATION_REQUIRED' WHERE id=$1",[row.account_id]);await c.query("UPDATE bot_sessions SET state='ERROR' WHERE account_id=$1",[row.account_id]);await notify(c,row.user_id,'BOT_HEARTBEAT_MISSED','BotSession',row.account_id,{health:'STALE'});});
 const accounts=await pool.query("SELECT DISTINCT user_id FROM accounts WHERE environment='paper'");for(const row of accounts.rows) await reconcile(row.user_id).catch(()=>{});
}
export async function list(userId:string,kind:'orders'|'positions'|'trades'){return (await pool.query(`SELECT r.* FROM ${kind} r JOIN accounts a ON a.id=r.account_id WHERE a.user_id=$1 AND a.environment='paper' ORDER BY r.id LIMIT 200`,[userId])).rows;}
