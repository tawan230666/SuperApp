import {randomUUID,randomBytes,createHmac,timingSafeEqual} from 'node:crypto';
import {z} from 'zod';
import {transaction,readTransaction,type PoolClient} from '@tipkhun/database';
import {HttpError} from '@tipkhun/auth';
import {authorizeBroker,validateBrokerDispatch,lockOwner} from '@tipkhun/risk-data';
import {assertSandbox,hash,intentSchema,providerId,replay,snapshotSchema,freshQuote,type BrokerProvider,type Fill,type Intent,type OrderState,type Position} from './domain.js';
import {DeterministicSandboxBrokerProvider,MockBrokerProvider} from './provider.js';
import type {CredentialVault} from './vault.js';

type Connection={id:string;user_id:string;provider:'mock'|'deterministic-sandbox';mode:'SANDBOX';status:'CONNECTED'|'DISCONNECTED';external_account_id:string;credential_ref:string;emergency_stop:boolean;reconciliation_state:string;initial_cash_minor:string;cash_minor:string;positions:Position[]};
type Order={id:string;connection_id:string;user_id:string;mode:'SANDBOX';symbol:'PTT'|'TDEX';side:'BUY'|'SELL';quantity:string;order_type:'MARKET';price_minor:string;fee_minor:string;filled_quantity:string;state:OrderState;preview_hash:string;request_hash:string;quote_as_of:Date;expires_at:Date;plan_version_id:string;confirmed_at:Date|null;risk_reserved_minor:string;reason:string|null};
const keySchema=z.string().min(8).max(128);
const connectionView=(a:Connection)=>({id:a.id,provider:a.provider,mode:a.mode,status:a.status,externalAccountId:a.external_account_id,emergencyStop:a.emergency_stop,reconciliationState:a.reconciliation_state});
const orderView=(o:Order)=>({...o,estimatedValueMinor:(BigInt(o.quantity)*BigInt(o.price_minor)).toString(),riskImpactMinor:o.side==='BUY'?(BigInt(o.quantity)*BigInt(o.price_minor)+BigInt(o.fee_minor)).toString():'0',portfolioImpact:{symbol:o.symbol,quantityDelta:`${o.side==='SELL'?'-':''}${o.quantity}`},marketDataStatus:'SYNTHETIC_SANDBOX',dataAsOf:o.quote_as_of});
async function connection(c:PoolClient,user:string,id:string){const a=(await c.query<Connection>('SELECT * FROM broker_connections WHERE id=$1 AND user_id=$2',[id,user])).rows[0];if(!a)throw new HttpError(404,'Broker connection not found');return a;}
async function order(c:PoolClient,user:string,id:string){const o=(await c.query<Order>('SELECT * FROM broker_orders WHERE id=$1 AND user_id=$2',[id,user])).rows[0];if(!o)throw new HttpError(404,'Broker order not found');return o;}
async function audit(c:PoolClient,user:string,action:string,id:string,requestId:string){await c.query('INSERT INTO broker_execution_audit(user_id,action,entity_id,request_id) VALUES($1,$2,$3,$4)',[user,action,id,requestId]);}
async function state(c:PoolClient,o:Order,next:OrderState,reason:string|null=null){await c.query('UPDATE broker_orders SET state=$2,reason=$3 WHERE id=$1',[o.id,next,reason]);o.state=next;o.reason=reason;}
function stableId(user:string,provider:string){const h=hash([user,provider]);return `${h.slice(0,8)}-${h.slice(8,12)}-5${h.slice(13,16)}-a${h.slice(17,20)}-${h.slice(20,32)}`;}
async function stored(c:PoolClient,user:string,kind:string,key:string,input:unknown){keySchema.parse(key);const r=(await c.query<{request_hash:string;result:unknown}>('SELECT request_hash,result FROM broker_operations WHERE user_id=$1 AND kind=$2 AND idempotency_key=$3',[user,kind,key])).rows[0];if(r&&r.request_hash!==hash(input))throw new HttpError(409,'IDEMPOTENCY_CONFLICT');return r;}
async function save(c:PoolClient,user:string,kind:string,key:string,input:unknown,result:unknown){await c.query('INSERT INTO broker_operations(user_id,kind,idempotency_key,request_hash,result) VALUES($1,$2,$3,$4,$5)',[user,kind,key,hash(input),JSON.stringify(result)]);return result;}
const eventSchema=z.object({eventId:z.string().uuid(),connectionId:z.string().uuid(),type:z.enum(['ORDER','FILL','CONNECTION']),clientOrderId:z.string().uuid().optional(),sequence:z.string().regex(/^[1-9][0-9]*$/),sentAt:z.string().datetime()}).strict();
export type BrokerOrderEvent=z.infer<typeof eventSchema>;
export type BrokerFillEvent=BrokerOrderEvent & {type:'FILL'};
export type BrokerConnectionEvent=BrokerOrderEvent & {type:'CONNECTION'};

export class BrokerExecution {
 constructor(private readonly vault:CredentialVault,private readonly providers:Record<'mock'|'deterministic-sandbox',BrokerProvider>={mock:new MockBrokerProvider(),'deterministic-sandbox':new DeterministicSandboxBrokerProvider()}){}
 private provider(a:Connection){const p=this.providers[a.provider];assertSandbox(p);return p;}
 private async active(c:PoolClient,a:Connection){
  if(a.status!=='CONNECTED')throw new HttpError(409,'BROKER_DISCONNECTED');
  if(a.emergency_stop)throw new HttpError(409,'EMERGENCY_STOP');
  if(a.reconciliation_state!=='OK')throw new HttpError(409,'RECONCILIATION_REQUIRED');
  await this.vault.read(c,a.credential_ref,a.id,a.user_id);
 }
 list(user:string){return readTransaction(async c=>(await c.query<Connection>('SELECT * FROM broker_connections WHERE user_id=$1 ORDER BY id',[user])).rows.map(connectionView));}
 balances(user:string,id:string){return readTransaction(async c=>{const a=await connection(c,user,id);return {...connectionView(a),cashMinor:a.cash_minor,currency:'THB',source:'stored broker mirror',positions:a.positions};});}
 orders(user:string){return readTransaction(async c=>(await c.query<Order>('SELECT * FROM broker_orders WHERE user_id=$1 ORDER BY created_at DESC,id DESC',[user])).rows.map(orderView));}
 getOrder(user:string,id:string){return readTransaction(async c=>orderView(await order(c,user,id)));}
 async connect(user:string,providerInput:unknown,key:string,requestId:string){
  const provider=providerId.parse(providerInput);assertSandbox(this.providers[provider]);
  return transaction(async c=>{
   await lockOwner(c,user);const prior=await stored(c,user,'connect',key,{provider});if(prior)return prior.result;
   const id=stableId(user,provider),reference=randomUUID();
   const exists=(await c.query<Connection>('SELECT * FROM broker_connections WHERE id=$1 AND user_id=$2',[id,user])).rows[0];
   if(exists?.status==='CONNECTED')return save(c,user,'connect',key,{provider},connectionView(exists));
   // Stable external account ID prevents duplicate accounts if the local commit is lost.
   await this.providers[provider].connect(id);
   await c.query("INSERT INTO broker_connections(id,user_id,provider,status,external_account_id,credential_ref,initial_cash_minor,cash_minor) VALUES($1,$2,$3,'CONNECTED',$4,$5,100000,100000) ON CONFLICT(id) DO UPDATE SET status='CONNECTED',credential_ref=$5,updated_at=now()",[id,user,provider,`sandbox:${id}`,reference]);
   await this.vault.put(c,reference,id,user,`sandbox-only:${randomBytes(32).toString('hex')}`);
   if(exists)await this.vault.revoke(c,exists.credential_ref,user);
   await audit(c,user,'BROKER_CONNECTED',id,requestId);
   return save(c,user,'connect',key,{provider},connectionView(await connection(c,user,id)));
  });
 }
 async disconnect(user:string,id:string,key:string,requestId:string){return transaction(async c=>{
  await lockOwner(c,user);const a=await connection(c,user,id),prior=await stored(c,user,'disconnect',key,{id});if(prior)return prior.result;
  await this.provider(a).disconnect(id);await this.vault.revoke(c,a.credential_ref,user);
  await c.query("UPDATE broker_connections SET status='DISCONNECTED',updated_at=now() WHERE id=$1",[id]);
  await audit(c,user,'BROKER_DISCONNECTED',id,requestId);return save(c,user,'disconnect',key,{id},connectionView(await connection(c,user,id)));
 });}
 async emergencyStop(user:string,id:string,key:string,requestId:string){return transaction(async c=>{
  await lockOwner(c,user);await connection(c,user,id);const prior=await stored(c,user,'emergency',key,{id});if(prior)return prior.result;
  await c.query('UPDATE broker_connections SET emergency_stop=true,updated_at=now() WHERE id=$1',[id]);
  await audit(c,user,'BROKER_EMERGENCY_STOP',id,requestId);return save(c,user,'emergency',key,{id},connectionView(await connection(c,user,id)));
 });}
 private async capacity(c:PoolClient,a:Connection,intent:Intent,price:string,fee:string){
  const pending=(await c.query<Order>("SELECT * FROM broker_orders WHERE connection_id=$1 AND state IN ('SUBMITTING','ACKNOWLEDGED','PARTIALLY_FILLED','CANCEL_PENDING','UNKNOWN')",[a.id])).rows;
  const amount=BigInt(intent.quantity)*BigInt(price)+BigInt(fee);
  if(intent.side==='BUY'&&amount>BigInt(a.cash_minor)-pending.filter(o=>o.side==='BUY').reduce((n,o)=>n+BigInt(o.risk_reserved_minor),0n))throw new HttpError(409,'INSUFFICIENT_BALANCE');
  const reservedShares=pending.filter(o=>o.side==='SELL'&&o.symbol===intent.symbol).reduce((n,o)=>n+BigInt(o.quantity)-BigInt(o.filled_quantity),0n);
  if(intent.side==='SELL'&&BigInt(intent.quantity)>BigInt(a.positions.find(p=>p.symbol===intent.symbol)?.quantity??'0')-reservedShares)throw new HttpError(409,'INSUFFICIENT_POSITION');
  return intent.side==='BUY'?amount:0n;
 }
 async preview(user:string,input:unknown,key:string,requestId:string){
  const intent=intentSchema.parse(input);keySchema.parse(key);
  return transaction(async c=>{
   await lockOwner(c,user);const a=await connection(c,user,intent.connectionId);
   const existing=(await c.query<Order>('SELECT * FROM broker_orders WHERE user_id=$1 AND idempotency_key=$2',[user,key])).rows[0];
   if(existing){if(existing.request_hash!==hash(intent))throw new HttpError(409,'IDEMPOTENCY_CONFLICT');return orderView(existing);}
   await this.active(c,a);const quote=await this.provider(a).previewOrder(a.id,intent);
   if(!freshQuote(quote))throw new HttpError(409,'STALE_MARKET_DATA');
   const risk=await this.capacity(c,a,intent,quote.priceMinor,quote.feeMinor),decision=await authorizeBroker(c,user,risk);
   const id=randomUUID(),previewHash=hash({intent,quote,id,plan:decision.planVersionId});
   const o=(await c.query<Order>("INSERT INTO broker_orders(id,connection_id,user_id,idempotency_key,request_hash,symbol,side,quantity,order_type,price_minor,fee_minor,state,preview_hash,quote_as_of,expires_at,plan_version_id) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'CREATED',$12,$13,now()+interval '30 seconds',$14) RETURNING *",[id,a.id,user,key,hash(intent),intent.symbol,intent.side,intent.quantity,intent.orderType,quote.priceMinor,quote.feeMinor,previewHash,quote.asOf,decision.planVersionId])).rows[0];
   if(decision.approved){await state(c,o,'RISK_CHECKED');await state(c,o,'AWAITING_CONFIRMATION');}else await state(c,o,'REJECTED',decision.reason);
   await audit(c,user,'BROKER_PREVIEW',id,requestId);return orderView(o);
  });
 }
 async confirm(user:string,input:unknown,requestId:string){
  const d=z.object({previewId:z.string().uuid(),previewHash:z.string().length(64),confirmed:z.literal(true),mode:z.literal('SANDBOX')}).strict().parse(input);
  const dispatch=await transaction(async c=>{
   await lockOwner(c,user);const o=await order(c,user,d.previewId),a=await connection(c,user,o.connection_id);
   if(o.preview_hash!==d.previewHash)throw new HttpError(409,'PREVIEW_MISMATCH');
   if(o.state!=='AWAITING_CONFIRMATION')return false; // Retry reads the original outcome; never dispatches again.
   await this.active(c,a);
   if(o.expires_at.getTime()<Date.now())throw new HttpError(409,'PREVIEW_EXPIRED');
   const intent:Intent={connectionId:a.id,symbol:o.symbol,side:o.side,quantity:o.quantity,orderType:o.order_type,mode:'SANDBOX'};
   const quote=await this.provider(a).previewOrder(a.id,intent);
   if(!freshQuote(quote)||quote.priceMinor!==o.price_minor||quote.feeMinor!==o.fee_minor)throw new HttpError(409,'STALE_OR_CHANGED_PREVIEW');
   const risk=await this.capacity(c,a,intent,quote.priceMinor,quote.feeMinor),decision=await authorizeBroker(c,user,risk);
   if(!decision.approved){await state(c,o,'REJECTED',decision.reason);await audit(c,user,'BROKER_RISK_REJECTED',o.id,requestId);return false;}
   if(decision.planVersionId!==o.plan_version_id)throw new HttpError(409,'PLAN_CHANGED');
   await c.query('UPDATE broker_orders SET confirmed_at=now(),risk_reserved_minor=$2 WHERE id=$1',[o.id,risk.toString()]);
   await state(c,o,'SUBMITTING');await audit(c,user,'BROKER_SUBMIT_INTENT',o.id,requestId);return true;
  });
  if(dispatch)await transaction(async c=>{
   await lockOwner(c,user);const o=await order(c,user,d.previewId),a=await connection(c,user,o.connection_id);
   if(o.state!=='SUBMITTING')return;
   // The owner lock is the linearization point for disconnect/emergency and dispatch.
   try{
    await this.active(c,a);
    if(!await validateBrokerDispatch(c,user,BigInt(o.risk_reserved_minor),o.plan_version_id))throw new HttpError(409,'RISK_CHANGED');
    const q=await this.provider(a).previewOrder(a.id,{connectionId:a.id,mode:'SANDBOX',symbol:o.symbol,side:o.side,quantity:o.quantity,orderType:o.order_type});
    if(o.expires_at.getTime()<Date.now()||!freshQuote(q)||q.priceMinor!==o.price_minor||q.feeMinor!==o.fee_minor)throw new HttpError(409,'STALE_MARKET_DATA');
   }
   catch{await state(c,o,'REJECTED','DISPATCH_GATE_CLOSED');await c.query('UPDATE broker_orders SET risk_reserved_minor=0 WHERE id=$1',[o.id]);return;}
   try{await this.provider(a).submitOrder(a.id,{clientOrderId:o.id,symbol:o.symbol,side:o.side,quantity:o.quantity,priceMinor:o.price_minor});}
   catch{await state(c,o,'UNKNOWN','BROKER_OUTCOME_UNKNOWN');await c.query("UPDATE broker_connections SET reconciliation_state='RECONCILIATION_REQUIRED' WHERE id=$1",[a.id]);await audit(c,user,'BROKER_UNKNOWN',o.id,requestId);return;}
   await this.reconcileLocked(c,a,requestId);
  });
  return this.getOrder(user,d.previewId);
 }
 private async localFills(c:PoolClient,a:Connection){return (await c.query<Fill>('SELECT external_fill_id AS id,order_id AS "clientOrderId",sequence::text,symbol,side,quantity::text,price_minor::text AS "priceMinor",fee_minor::text AS "feeMinor",realized_pnl_minor::text AS "realizedPnlMinor",executed_at AS "executedAt" FROM broker_fills WHERE connection_id=$1 AND user_id=$2 ORDER BY sequence',[a.id,a.user_id])).rows.map(f=>({...f,executedAt:new Date(f.executedAt).toISOString()}));}
 private async reconcileLocked(c:PoolClient,a:Connection,requestId:string){
  // Broker acceptance survives a failed mirror transaction. Keep its reservation and
  // record uncertainty without rolling back to a dispatchable state.
  await c.query('SAVEPOINT broker_reconcile');
  try{const result=await this.reconcileEvidence(c,a,requestId);await c.query('RELEASE SAVEPOINT broker_reconcile');return result;}
  catch{
   await c.query('ROLLBACK TO SAVEPOINT broker_reconcile');
   await c.query('RELEASE SAVEPOINT broker_reconcile');
   return this.unresolved(c,a,requestId,['BROKER_EVIDENCE_UNAVAILABLE_OR_INVALID'],{});
  }
 }
 private async unresolved(c:PoolClient,a:Connection,requestId:string,mismatches:string[],snapshot:unknown){
  await c.query("UPDATE broker_orders SET state='UNKNOWN',reason='RECONCILIATION_REQUIRED' WHERE connection_id=$1 AND user_id=$2 AND state IN ('SUBMITTING','CANCEL_PENDING')",[a.id,a.user_id]);
  await c.query("UPDATE broker_connections SET reconciliation_state='RECONCILIATION_REQUIRED' WHERE id=$1",[a.id]);
  const run=(await c.query<{id:string}>("INSERT INTO broker_reconciliation_runs(connection_id,user_id,status,mismatches,snapshot) VALUES($1,$2,'RECONCILIATION_REQUIRED',$3,$4) RETURNING id",[a.id,a.user_id,JSON.stringify(mismatches),JSON.stringify(snapshot)])).rows[0];
  await audit(c,a.user_id,'BROKER_RECONCILIATION_REQUIRED',a.id,requestId);
  return {...run,status:'RECONCILIATION_REQUIRED',mismatches};
 }
 private async reconcileEvidence(c:PoolClient,a:Connection,requestId:string){
  const s=snapshotSchema.parse(await this.provider(a).reconcile(a.id)),local=await this.localFills(c,a),orders=(await c.query<Order>('SELECT * FROM broker_orders WHERE connection_id=$1 AND user_id=$2',[a.id,a.user_id])).rows;
  const mismatches:string[]=[];
  if(s.connected!==(a.status==='CONNECTED'))mismatches.push('BROKER_CONNECTION_MISMATCH');
  if(new Set(s.orders.map(o=>o.clientOrderId)).size!==s.orders.length||new Set(s.fills.map(f=>f.id)).size!==s.fills.length||new Set(s.positions.map(p=>p.symbol)).size!==s.positions.length)mismatches.push('DUPLICATE_BROKER_EVIDENCE');
  if(s.accountId!==a.id||s.initialCashMinor!==a.initial_cash_minor)mismatches.push('BROKER_ACCOUNT_IDENTITY');
  try{if(hash(replay(a.initial_cash_minor,local))!==hash({cashMinor:a.cash_minor,positions:a.positions}))mismatches.push('LOCAL_MIRROR_MISMATCH');if(hash(replay(s.initialCashMinor,s.fills))!==hash({cashMinor:s.cashMinor,positions:s.positions}))mismatches.push('BROKER_BALANCE_POSITION_MISMATCH');}catch{mismatches.push('INVALID_FILL_ACCOUNTING');}
  for(const f of local)if(!s.fills.some(other=>hash(other)===hash(f)))mismatches.push('MISSING_OR_CHANGED_BROKER_FILL');
  for(const external of s.orders){const o=orders.find(o=>o.id===external.clientOrderId);if(!o||!o.confirmed_at||o.symbol!==external.symbol||o.side!==external.side||o.quantity!==external.quantity||o.price_minor!==external.priceMinor)mismatches.push('UNCONFIRMED_OR_CHANGED_BROKER_ORDER');}
  for(const f of s.fills){const o=orders.find(o=>o.id===f.clientOrderId);if(!s.orders.some(external=>external.clientOrderId===f.clientOrderId)||!o||!o.confirmed_at||o.symbol!==f.symbol||o.side!==f.side||o.price_minor!==f.priceMinor)mismatches.push('INVALID_BROKER_FILL');}
  for(const o of orders){
   const external=s.orders.find(x=>x.clientOrderId===o.id),sum=s.fills.filter(f=>f.clientOrderId===o.id).reduce((n,f)=>n+BigInt(f.quantity),0n);
   if(sum>BigInt(o.quantity)||external&&sum!==BigInt(external.filledQuantity))mismatches.push('FILL_TOTAL_MISMATCH');
   if(o.confirmed_at&&!external&&o.state!=='REJECTED')mismatches.push('ORDER_NOT_FOUND_UNRESOLVED');
   if(!external&&o.state==='SUBMITTING')await state(c,o,'UNKNOWN','RECOVER_UNCERTAIN_DISPATCH');
   if(external&&o.state==='FILLED'&&external.state!=='FILLED')mismatches.push('BROKER_STATE_REGRESSION');
   if(external){
    if(external.state==='FILLED'&&sum!==BigInt(o.quantity)||external.state==='ACKNOWLEDGED'&&sum!==0n||external.state==='REJECTED'&&sum!==0n||external.state==='PARTIALLY_FILLED'&&(sum===0n||sum===BigInt(o.quantity)))mismatches.push('INCONSISTENT_BROKER_STATE');
    if(o.state==='CANCELLED'&&!['CANCELLED','FILLED'].includes(external.state)||o.state==='REJECTED'&&external.state!=='REJECTED'||o.state==='PARTIALLY_FILLED'&&external.state==='ACKNOWLEDGED')mismatches.push('BROKER_STATE_REGRESSION');
   }
  }
  if(mismatches.length)return this.unresolved(c,a,requestId,mismatches,s);
  if(!mismatches.length){
   for(const f of s.fills.filter(f=>!local.some(old=>old.id===f.id)))await c.query('INSERT INTO broker_fills(id,connection_id,user_id,order_id,external_fill_id,sequence,symbol,side,quantity,price_minor,fee_minor,realized_pnl_minor,executed_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)',[randomUUID(),a.id,a.user_id,f.clientOrderId,f.id,f.sequence,f.symbol,f.side,f.quantity,f.priceMinor,f.feeMinor,f.realizedPnlMinor,f.executedAt]);
   for(const external of s.orders){const o=orders.find(o=>o.id===external.clientOrderId)!;
    await c.query('UPDATE broker_orders SET filled_quantity=$2,risk_reserved_minor=$3,state=$4,reason=NULL WHERE id=$1',[o.id,external.filledQuantity,['FILLED','CANCELLED','REJECTED'].includes(external.state)||o.side==='SELL'?'0':((BigInt(o.quantity)-BigInt(external.filledQuantity))*BigInt(o.price_minor)).toString(),external.state]);
   }
   await c.query('UPDATE broker_connections SET cash_minor=$2,positions=$3,updated_at=now() WHERE id=$1',[a.id,s.cashMinor,JSON.stringify(s.positions)]);
  }
  const status=mismatches.length?'RECONCILIATION_REQUIRED':'OK';
  await c.query('UPDATE broker_connections SET reconciliation_state=$2 WHERE id=$1',[a.id,status]);
  const run=(await c.query<{id:string}>('INSERT INTO broker_reconciliation_runs(connection_id,user_id,status,mismatches,snapshot) VALUES($1,$2,$3,$4,$5) RETURNING id',[a.id,a.user_id,status,JSON.stringify(mismatches),JSON.stringify(s)])).rows[0];
  await audit(c,a.user_id,'BROKER_RECONCILED',a.id,requestId);return {...run,status,mismatches};
 }
 async reconcile(user:string,id:string,key:string,requestId:string){return transaction(async c=>{
  await lockOwner(c,user);const a=await connection(c,user,id),prior=await stored(c,user,'reconcile',key,{id});if(prior)return prior.result;
  return save(c,user,'reconcile',key,{id},await this.reconcileLocked(c,a,requestId));
 });}
 async cancel(user:string,id:string,key:string,requestId:string){return transaction(async c=>{
  await lockOwner(c,user);const o=await order(c,user,id),a=await connection(c,user,o.connection_id),prior=await stored(c,user,'cancel',key,{id});if(prior)return prior.result;
  if(o.state==='AWAITING_CONFIRMATION')await state(c,o,'CANCELLED');
  else if(['ACKNOWLEDGED','PARTIALLY_FILLED'].includes(o.state)){
   if(a.status!=='CONNECTED')throw new HttpError(409,'BROKER_DISCONNECTED');await this.vault.read(c,a.credential_ref,a.id,user);
   await state(c,o,'CANCEL_PENDING');
   try{await this.provider(a).cancelOrder(a.id,o.id);}catch{await state(c,o,'UNKNOWN','CANCEL_OUTCOME_UNKNOWN');await c.query("UPDATE broker_connections SET reconciliation_state='RECONCILIATION_REQUIRED' WHERE id=$1",[a.id]);}
   if(o.state==='CANCEL_PENDING')await this.reconcileLocked(c,a,requestId);
  }else if(['UNKNOWN','SUBMITTING','CANCEL_PENDING'].includes(o.state))throw new HttpError(409,'RECONCILE_BEFORE_CANCEL');
  await audit(c,user,'BROKER_CANCEL',o.id,requestId);return save(c,user,'cancel',key,{id},orderView(await order(c,user,id)));
 });}
 async event(input:unknown,signature:string,requestId:string){
  const e=eventSchema.parse(input);if(Math.abs(Date.now()-Date.parse(e.sentAt))>60000||!/^[a-f0-9]{64}$/.test(signature))throw new HttpError(401,'Invalid broker event');
  return transaction(async c=>{
   const owner=(await c.query<{user_id:string}>('SELECT user_id FROM broker_connections WHERE id=$1',[e.connectionId])).rows[0];if(!owner)throw new HttpError(401,'Invalid broker event');
   await lockOwner(c,owner.user_id);const a=await connection(c,owner.user_id,e.connectionId);
   const secret=await this.vault.read(c,a.credential_ref,a.id,a.user_id),expected=createHmac('sha256',secret).update(JSON.stringify(e)).digest('hex');
   if(!timingSafeEqual(Buffer.from(expected),Buffer.from(signature)))throw new HttpError(401,'Invalid broker event');
   const old=(await c.query<{payload_hash:string;outcome:string}>('SELECT payload_hash,outcome FROM broker_order_events WHERE connection_id=$1 AND external_event_id=$2',[a.id,e.eventId])).rows[0];
   if(old){if(old.payload_hash!==hash(e))throw new HttpError(409,'EVENT_REPLAY_CONFLICT');return {duplicate:true,status:old.outcome};}
   if(e.clientOrderId)await order(c,a.user_id,e.clientOrderId);
   // Event contents are wake-up metadata, never authority to invent a fill/state.
   const result=await this.reconcileLocked(c,a,requestId);
   await c.query('INSERT INTO broker_order_events(connection_id,user_id,external_event_id,payload_hash,metadata,outcome) VALUES($1,$2,$3,$4,$5,$6)',[a.id,a.user_id,e.eventId,hash(e),JSON.stringify(e),result.status]);
   return {duplicate:false,status:result.status};
  });
 }
}
