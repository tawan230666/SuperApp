import {z} from 'zod';
import {createHash} from 'node:crypto';

export const providerId=z.enum(['mock','deterministic-sandbox']);
export const intentSchema=z.object({connectionId:z.string().uuid(),symbol:z.enum(['PTT','TDEX']),side:z.enum(['BUY','SELL']),quantity:z.string().regex(/^[1-9][0-9]{0,5}$/),orderType:z.literal('MARKET'),mode:z.literal('SANDBOX')}).strict();
export type Intent=z.infer<typeof intentSchema>;
export type BrokerState='ACKNOWLEDGED'|'PARTIALLY_FILLED'|'FILLED'|'CANCELLED'|'REJECTED';
export type OrderState=BrokerState|'CREATED'|'RISK_CHECKED'|'AWAITING_CONFIRMATION'|'SUBMITTING'|'CANCEL_PENDING'|'UNKNOWN'|'ERROR';
export type Quote={priceMinor:string;feeMinor:string;asOf:string;status:'FRESH'|'STALE'|'UNAVAILABLE';source:'synthetic-sandbox'};
export type Position={symbol:string;quantity:string;costMinor:string};
export type Fill={id:string;clientOrderId:string;sequence:string;symbol:string;side:'BUY'|'SELL';quantity:string;priceMinor:string;feeMinor:string;realizedPnlMinor:string;executedAt:string};
export type ExternalOrder={clientOrderId:string;symbol:string;side:'BUY'|'SELL';quantity:string;priceMinor:string;state:BrokerState;filledQuantity:string};
export type BrokerSnapshot={accountId:string;connected:boolean;initialCashMinor:string;cashMinor:string;positions:Position[];orders:ExternalOrder[];fills:Fill[];asOf:string};
const unsigned=z.string().regex(/^(0|[1-9][0-9]*)$/),positive=z.string().regex(/^[1-9][0-9]*$/);
export const snapshotSchema=z.object({
 accountId:z.string().uuid(),connected:z.boolean(),initialCashMinor:positive,cashMinor:unsigned,asOf:z.string().datetime(),
 positions:z.array(z.object({symbol:z.enum(['PTT','TDEX']),quantity:positive,costMinor:unsigned}).strict()),
 orders:z.array(z.object({clientOrderId:z.string().uuid(),symbol:z.enum(['PTT','TDEX']),side:z.enum(['BUY','SELL']),quantity:positive,priceMinor:positive,state:z.enum(['ACKNOWLEDGED','PARTIALLY_FILLED','FILLED','CANCELLED','REJECTED']),filledQuantity:unsigned}).strict()),
 fills:z.array(z.object({id:z.string().uuid(),clientOrderId:z.string().uuid(),sequence:positive,symbol:z.enum(['PTT','TDEX']),side:z.enum(['BUY','SELL']),quantity:positive,priceMinor:positive,feeMinor:unsigned,realizedPnlMinor:z.string().regex(/^-?(0|[1-9][0-9]*)$/),executedAt:z.string().datetime()}).strict()),
}).strict();
export type Submission={clientOrderId:string;symbol:string;side:'BUY'|'SELL';quantity:string;priceMinor:string};
export type Capabilities={provider:string;mode:'SANDBOX'|'LOCKED';submit:boolean;oauth:boolean;currency:'THB'};
export interface BrokerProvider {
 getCapabilities():Capabilities;
 connect(accountId:string):Promise<void>;
 disconnect(accountId:string):Promise<void>;
 health(accountId:string):Promise<{connected:boolean}>;
 getAccount(accountId:string):Promise<{id:string;mode:'SANDBOX'}>;
 getBalances(accountId:string):Promise<{cashMinor:string;currency:'THB'}>;
 getPositions(accountId:string):Promise<Position[]>;
 previewOrder(accountId:string,intent:Intent):Promise<Quote>;
 submitOrder(accountId:string,order:Submission):Promise<void>;
 cancelOrder(accountId:string,clientOrderId:string):Promise<void>;
 getOrder(accountId:string,clientOrderId:string):Promise<ExternalOrder|null>;
 listOrders(accountId:string):Promise<ExternalOrder[]>;
 getFills(accountId:string):Promise<Fill[]>;
 reconcile(accountId:string):Promise<BrokerSnapshot>;
}
export const hash=(value:unknown)=>createHash('sha256').update(JSON.stringify(value)).digest('hex');
export function freshQuote(quote:Quote){const age=Date.now()-Date.parse(quote.asOf);return quote.status==='FRESH'&&Number.isFinite(age)&&age>=-5000&&age<=60000;}
export class BrokerError extends Error {}
export function assertSandbox(provider:BrokerProvider){
 const capabilities=provider.getCapabilities();
 if(capabilities.mode!=='SANDBOX'||!capabilities.submit||!providerId.safeParse(capabilities.provider).success||process.env.LIVE_TRADING_ENABLED==='true')throw new BrokerError('LIVE_TRADING_LOCKED');
}
/** Full notional risk, integer shares, no leverage, no shorting, explicit zero sandbox fees. */
export function replay(initial:string,fills:Fill[]){
 let cash=BigInt(initial);const positions=new Map<string,{quantity:bigint;cost:bigint}>();
 let last=0n;
 for(const fill of fills){
  const sequence=BigInt(fill.sequence),q=BigInt(fill.quantity),price=BigInt(fill.priceMinor),fee=BigInt(fill.feeMinor);
  if(sequence!==last+1n||q<=0n||price<=0n||fee<0n)throw new BrokerError('INVALID_FILL_SEQUENCE');last=sequence;
  const p=positions.get(fill.symbol)??{quantity:0n,cost:0n};
  let realized=0n;
  if(fill.side==='BUY'){cash-=q*price+fee;p.quantity+=q;p.cost+=q*price+fee;}
  else {if(p.quantity<q)throw new BrokerError('SHORT_POSITION_FORBIDDEN');const cost=p.cost*q/p.quantity;realized=q*price-fee-cost;cash+=q*price-fee;p.quantity-=q;p.cost-=cost;}
  if(realized!==BigInt(fill.realizedPnlMinor)||cash<0n)throw new BrokerError('BROKER_ACCOUNTING_MISMATCH');
  positions.set(fill.symbol,p);
 }
 return {cashMinor:cash.toString(),positions:[...positions].filter(([,p])=>p.quantity>0n).sort(([a],[b])=>a.localeCompare(b)).map(([symbol,p])=>({symbol,quantity:p.quantity.toString(),costMinor:p.cost.toString()}))};
}
/** Future adapters are deliberately unconstructable execution integrations. No SDK/network code. */
export interface OAuthPort {
 authorize(input:{ownerId:string;redirectUri:string;stateHash:string;pkceChallenge:string}):Promise<{authorizationUrl:string}>;
 callback(input:{state:string;code:string;pkceVerifier:string}):Promise<{credentialReference:string}>;
 refresh(credentialReference:string):Promise<void>;
 revoke(credentialReference:string):Promise<void>;
}
export abstract class AlpacaBrokerProvider implements BrokerProvider {
 getCapabilities():Capabilities{return {provider:'alpaca',mode:'LOCKED',submit:false,oauth:true,currency:'THB'};}
 async submitOrder(_accountId:string,_order:Submission):Promise<void>{throw new BrokerError('LIVE_TRADING_LOCKED');}
 abstract connect:BrokerProvider['connect'];abstract disconnect:BrokerProvider['disconnect'];abstract health:BrokerProvider['health'];
 abstract getAccount:BrokerProvider['getAccount'];abstract getBalances:BrokerProvider['getBalances'];abstract getPositions:BrokerProvider['getPositions'];
 abstract previewOrder:BrokerProvider['previewOrder'];abstract cancelOrder:BrokerProvider['cancelOrder'];abstract getOrder:BrokerProvider['getOrder'];
 abstract listOrders:BrokerProvider['listOrders'];abstract getFills:BrokerProvider['getFills'];abstract reconcile:BrokerProvider['reconcile'];
}
export abstract class SettradeBrokerProvider extends AlpacaBrokerProvider {
 override getCapabilities():Capabilities{return {...super.getCapabilities(),provider:'settrade'};}
}
