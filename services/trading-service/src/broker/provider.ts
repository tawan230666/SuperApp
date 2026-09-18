import {randomUUID} from 'node:crypto';
import {transaction,readTransaction,type PoolClient} from '@tipkhun/database';
import {BrokerError,assertSandbox,hash,replay,type BrokerProvider,type BrokerSnapshot,type Submission,type Intent,type ExternalOrder,type Fill,type Capabilities} from './domain.js';

type Account={id:string;initial_cash_minor:string;connected:boolean;next_sequence:string;scenario:string};
type Order={id:string;account_id:string;request_hash:string;symbol:string;side:'BUY'|'SELL';quantity:string;price_minor:string;state:ExternalOrder['state']};
async function account(c:PoolClient,id:string,lock=false){const a=(await c.query<Account>(`SELECT * FROM sandbox_broker_accounts WHERE id=$1${lock?' FOR UPDATE':''}`,[id])).rows[0];if(!a)throw new BrokerError('BROKER_ACCOUNT_NOT_FOUND');return a;}
async function read(c:PoolClient,id:string):Promise<BrokerSnapshot>{
 const a=await account(c,id);
 const fills=(await c.query<Fill>('SELECT id,order_id AS "clientOrderId",sequence::text,symbol,side,quantity::text,price_minor::text AS "priceMinor",fee_minor::text AS "feeMinor",realized_pnl_minor::text AS "realizedPnlMinor",executed_at AS "executedAt" FROM sandbox_broker_fills WHERE account_id=$1 ORDER BY sequence',[id])).rows.map(f=>({...f,executedAt:new Date(f.executedAt).toISOString()}));
 const orders=(await c.query<Order>('SELECT * FROM sandbox_broker_orders WHERE account_id=$1 ORDER BY id',[id])).rows.map(o=>({clientOrderId:o.id,symbol:o.symbol,side:o.side,quantity:o.quantity,priceMinor:o.price_minor,state:o.state,filledQuantity:fills.filter(f=>f.clientOrderId===o.id).reduce((n,f)=>n+BigInt(f.quantity),0n).toString()}));
 return {accountId:id,connected:a.connected,initialCashMinor:a.initial_cash_minor,...replay(a.initial_cash_minor,fills),orders,fills,asOf:new Date().toISOString()};
}
async function fill(c:PoolClient,a:Account,o:Order,quantity:bigint){
 const s=await read(c,a.id),existing=s.orders.find(x=>x.clientOrderId===o.id)!;
 if(quantity<=0n||BigInt(existing.filledQuantity)+quantity>BigInt(o.quantity))throw new BrokerError('INVALID_FILL_QUANTITY');
 const p=s.positions.find(x=>x.symbol===o.symbol);let realized=0n;
 if(o.side==='SELL'){
  if(!p||BigInt(p.quantity)<quantity)throw new BrokerError('INSUFFICIENT_POSITION');
  realized=quantity*BigInt(o.price_minor)-BigInt(p.costMinor)*quantity/BigInt(p.quantity);
 }else if(BigInt(s.cashMinor)<quantity*BigInt(o.price_minor))throw new BrokerError('INSUFFICIENT_BALANCE');
 await c.query('INSERT INTO sandbox_broker_fills(id,account_id,order_id,sequence,symbol,side,quantity,price_minor,fee_minor,realized_pnl_minor) VALUES($1,$2,$3,$4,$5,$6,$7,$8,0,$9)',[randomUUID(),a.id,o.id,a.next_sequence,o.symbol,o.side,quantity.toString(),o.price_minor,realized.toString()]);
 await c.query('UPDATE sandbox_broker_accounts SET next_sequence=next_sequence+1 WHERE id=$1',[a.id]);
 await c.query('UPDATE sandbox_broker_orders SET state=$2 WHERE id=$1',[o.id,BigInt(existing.filledQuantity)+quantity===BigInt(o.quantity)?'FILLED':'PARTIALLY_FILLED']);
}
export class DeterministicSandboxBrokerProvider implements BrokerProvider {
 getCapabilities():Capabilities{return {provider:'deterministic-sandbox',mode:'SANDBOX',submit:true,oauth:false,currency:'THB'};}
 async connect(id:string){assertSandbox(this);await transaction(async c=>{await c.query('INSERT INTO sandbox_broker_accounts(id,initial_cash_minor) VALUES($1,100000) ON CONFLICT(id) DO UPDATE SET connected=true',[id]);});}
 async disconnect(id:string){await transaction(async c=>{await account(c,id,true);await c.query('UPDATE sandbox_broker_accounts SET connected=false WHERE id=$1',[id]);});}
 async health(id:string){return {connected:(await this.reconcile(id)).connected};}
 async getAccount(id:string){await this.health(id);return {id,mode:'SANDBOX' as const};}
 async getBalances(id:string){return {cashMinor:(await this.reconcile(id)).cashMinor,currency:'THB' as const};}
 async getPositions(id:string){return (await this.reconcile(id)).positions;}
 async getOrder(id:string,orderId:string){return (await this.reconcile(id)).orders.find(o=>o.clientOrderId===orderId)??null;}
 async listOrders(id:string){return (await this.reconcile(id)).orders;}
 async getFills(id:string){return (await this.reconcile(id)).fills;}
 reconcile(id:string){return readTransaction(c=>read(c,id));}
 async previewOrder(id:string,intent:Intent){
  assertSandbox(this);const a=await readTransaction(c=>account(c,id));if(!a.connected)throw new BrokerError('BROKER_DISCONNECTED');
  return {priceMinor:intent.symbol==='PTT'?'100':'200',feeMinor:'0',asOf:new Date(Date.now()-(a.scenario==='stale'?120000:0)).toISOString(),status:a.scenario==='stale'?'STALE' as const:a.scenario==='unavailable'?'UNAVAILABLE' as const:'FRESH' as const,source:'synthetic-sandbox' as const};
 }
 async submitOrder(id:string,input:Submission){
  assertSandbox(this);
  const outcome=await transaction(async c=>{
   const a=await account(c,id,true);if(!a.connected)throw new BrokerError('BROKER_DISCONNECTED');
   const existing=(await c.query<Order>('SELECT * FROM sandbox_broker_orders WHERE id=$1',[input.clientOrderId])).rows[0];
   if(existing){if(existing.account_id!==id||existing.request_hash!==hash(input))throw new BrokerError('IDEMPOTENCY_CONFLICT');return 'existing';}
   if(a.scenario==='network-timeout')return 'timeout'; // Broker acceptance cannot be proven absent by the caller.
   const s=await read(c,id),q=BigInt(input.quantity),price=BigInt(input.priceMinor);
   if(q<=0n||!['PTT','TDEX'].includes(input.symbol)||!['BUY','SELL'].includes(input.side)||price!==(input.symbol==='PTT'?100n:200n))throw new BrokerError('INVALID_ORDER');
   const pending=s.orders.filter(o=>['ACKNOWLEDGED','PARTIALLY_FILLED'].includes(o.state));
   const cashReserved=pending.filter(o=>o.side==='BUY').reduce((n,o)=>n+(BigInt(o.quantity)-BigInt(o.filledQuantity))*BigInt(o.priceMinor),0n);
   const sharesReserved=pending.filter(o=>o.side==='SELL'&&o.symbol===input.symbol).reduce((n,o)=>n+BigInt(o.quantity)-BigInt(o.filledQuantity),0n);
   if(input.side==='BUY'&&q*price>BigInt(s.cashMinor)-cashReserved)throw new BrokerError('INSUFFICIENT_BALANCE');
   if(input.side==='SELL'&&q>BigInt(s.positions.find(p=>p.symbol===input.symbol)?.quantity??'0')-sharesReserved)throw new BrokerError('INSUFFICIENT_POSITION');
   const o=(await c.query<Order>("INSERT INTO sandbox_broker_orders(id,account_id,request_hash,symbol,side,quantity,price_minor,state) VALUES($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *",[input.clientOrderId,id,hash(input),input.symbol,input.side,input.quantity,input.priceMinor,a.scenario==='reject'?'REJECTED':'ACKNOWLEDGED'])).rows[0];
   if(['fill','ack-timeout','partial'].includes(a.scenario))await fill(c,a,o,a.scenario==='partial'&&q>1n?q/2n:q);
   return a.scenario==='ack-timeout'?'timeout':'accepted';
  });
  if(outcome==='timeout')throw new BrokerError('BROKER_ACK_UNKNOWN');
 }
 async cancelOrder(id:string,orderId:string){
  assertSandbox(this);const timeout=await transaction(async c=>{
   const a=await account(c,id,true);if(!a.connected)throw new BrokerError('BROKER_DISCONNECTED');
   const o=(await c.query<Order>('SELECT * FROM sandbox_broker_orders WHERE account_id=$1 AND id=$2',[id,orderId])).rows[0];
   if(!o)throw new BrokerError('ORDER_NOT_FOUND');
   if(['ACKNOWLEDGED','PARTIALLY_FILLED'].includes(o.state))await c.query("UPDATE sandbox_broker_orders SET state='CANCELLED' WHERE id=$1",[orderId]);
   return a.scenario==='cancel-timeout';
  });if(timeout)throw new BrokerError('BROKER_ACK_UNKNOWN');
 }
}
export class MockBrokerProvider extends DeterministicSandboxBrokerProvider {
 override getCapabilities():Capabilities{return {...super.getCapabilities(),provider:'mock'};}
}
/** Test harness only. No API route. Can model fills delivered after cancellation. */
export async function simulateLateFill(accountId:string,orderId:string,quantity:string){
 if(process.env.NODE_ENV!=='test'||process.env.TEST_MODE!=='1'||!new URL(process.env.DATABASE_URL??'http://invalid').pathname.endsWith('_test'))throw new BrokerError('TEST_ONLY');
 await transaction(async c=>{const a=await account(c,accountId,true);const o=(await c.query<Order>('SELECT * FROM sandbox_broker_orders WHERE id=$1 AND account_id=$2',[orderId,accountId])).rows[0];if(!o)throw new BrokerError('ORDER_NOT_FOUND');await fill(c,a,o,BigInt(quantity));});
}
