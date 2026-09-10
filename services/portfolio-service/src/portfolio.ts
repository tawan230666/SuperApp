import {randomUUID,createHash} from 'node:crypto';
import {pool,transaction,type PoolClient} from '@tipkhun/database';
import {audit,HttpError} from '@tipkhun/auth';
import {lockOwner,ensureLedgerAccounts,ledgerTransaction,notify} from '@tipkhun/risk-data';
import {provider,requireFresh,type Quote} from './market.js';
import {quantity,decimal,SCALE,fee,basisSold,bps} from './accounting.js';
export async function ensure(c:PoolClient,user:string){
 await lockOwner(c,user);
 const p=(await c.query('INSERT INTO portfolios(user_id) VALUES($1) ON CONFLICT(user_id) DO UPDATE SET user_id=EXCLUDED.user_id RETURNING *',[user])).rows[0];
 await c.query('INSERT INTO portfolio_cash(portfolio_id) VALUES($1) ON CONFLICT DO NOTHING',[p.id]);return p;
}
export async function buckets(c:PoolClient,user:string):Promise<Record<string,bigint>>{const r=await c.query("SELECT a.bucket,coalesce(sum(CASE WHEN e.direction='CREDIT' THEN e.amount_minor ELSE -e.amount_minor END),0)::text AS n FROM ledger_accounts a LEFT JOIN ledger_entries e ON e.ledger_account_id=a.id WHERE a.user_id=$1 GROUP BY a.bucket",[user]);return Object.fromEntries(r.rows.map(r=>[r.bucket,BigInt(r.n)]));}
export async function check(c:PoolClient,p:any,requestId:string){
 const b=await buckets(c,p.user_id),cash=BigInt((await c.query('SELECT amount_minor FROM portfolio_cash WHERE portfolio_id=$1',[p.id])).rows[0].amount_minor);
 const cost=BigInt((await c.query('SELECT coalesce(sum(cost_basis_minor),0)::text AS n FROM portfolio_holdings WHERE portfolio_id=$1',[p.id])).rows[0].n);
 const totals=(await c.query("SELECT coalesce(sum(CASE WHEN type='FUND' THEN amount_minor WHEN type='BUY' THEN -amount_minor-fee_minor ELSE amount_minor-fee_minor END),0)::text AS cash,coalesce(sum(realized_pnl_minor),0)::text AS pnl FROM portfolio_transactions WHERE portfolio_id=$1",[p.id])).rows[0];
 const quantities=(await c.query("WITH expected AS (SELECT asset_id,sum(CASE WHEN type='BUY' THEN quantity ELSE -quantity END) AS qty,sum(CASE WHEN type='BUY' THEN cost_minor ELSE -cost_minor END) AS cost FROM portfolio_transactions WHERE portfolio_id=$1 AND type IN ('BUY','SELL') GROUP BY asset_id) SELECT 1 FROM expected e FULL JOIN (SELECT asset_id,quantity,cost_basis_minor FROM portfolio_holdings WHERE portfolio_id=$1) h ON h.asset_id=e.asset_id WHERE coalesce(e.qty,0)<>coalesce(h.quantity,0) OR coalesce(e.cost,0)<>coalesce(h.cost_basis_minor,0)",[p.id])).rowCount;
 const valid=!quantities&&cash===(b.PORTFOLIO_CASH??0n)&&cost===(b.PORTFOLIO_COST??0n)&&cash===BigInt(totals.cash)&&BigInt(totals.pnl)===-(b.PORTFOLIO_PNL??0n);
 if(!valid&&p.reconciliation_state==='OK'){
  await c.query("UPDATE portfolios SET reconciliation_state='RECONCILIATION_REQUIRED',updated_at=now() WHERE id=$1",[p.id]);
  await audit(c,p.user_id,'LEDGER_RECONCILIATION_REQUIRED','Portfolio',p.id,requestId);
  await notify(c,p.user_id,'LEDGER_RECONCILIATION_REQUIRED','Portfolio',p.id);
 }
 return valid&&p.reconciliation_state==='OK';
}
export async function cashView(user:string){return transaction(async c=>{const p=await ensure(c,user),b=await buckets(c,user),r=(await c.query('SELECT amount_minor FROM portfolio_cash WHERE portfolio_id=$1',[p.id])).rows[0];return {mode:'PAPER',portfolioId:p.id,currency:'THB',cashMinor:r.amount_minor,longTermReservedCashMinor:(b.LONG_TERM_RESERVE??0n).toString()};});}
async function ownedAccount(c:PoolClient,user:string){const a=(await c.query("SELECT * FROM accounts WHERE user_id=$1 AND environment='paper'",[user])).rows[0];if(!a)throw new HttpError(409,'Start a paper account first');if(a.reconciliation_state!=='OK')throw new HttpError(409,'RECONCILIATION_REQUIRED');await ensureLedgerAccounts(c,user,a.id);for(const bucket of ['PORTFOLIO_CASH','PORTFOLIO_COST','PORTFOLIO_PNL','PORTFOLIO_FEES'])await c.query('INSERT INTO ledger_accounts(user_id,account_id,bucket) VALUES($1,$2,$3) ON CONFLICT DO NOTHING',[user,a.id,bucket]);return a;}
export type OrderInput={side:'BUY'|'SELL';symbol:string;quantity:string};
async function estimate(c:PoolClient,p:any,d:OrderInput){
 const md=provider(p.user_id),asset=await md.getAssetProfile(d.symbol),quote=await md.getQuote(d.symbol);requireFresh(quote);
 const qty=quantity(d.quantity),amount=qty*BigInt(quote.priceMinor)/SCALE;
 if(amount<1n)throw new HttpError(400,'ORDER_TOO_SMALL');
 const fees=fee(amount),cash=BigInt((await c.query('SELECT amount_minor FROM portfolio_cash WHERE portfolio_id=$1',[p.id])).rows[0].amount_minor);
 const holding=(await c.query('SELECT * FROM portfolio_holdings WHERE portfolio_id=$1 AND asset_id=$2',[p.id,asset.id])).rows[0];
 const held=holding&&!/^0(\.0+)?$/.test(String(holding.quantity))?quantity(String(holding.quantity).replace(/0+$/,'').replace(/\.$/,'')):0n;
 const heldCost=BigInt(holding?.cost_basis_minor??0);
 let cost=amount+fees;
 if(d.side==='BUY'&&cash<cost)throw new HttpError(409,'INSUFFICIENT_CASH');
 if(d.side==='SELL'){if(qty>held)throw new HttpError(409,'INSUFFICIENT_HOLDINGS');cost=basisSold(heldCost,held,qty);}
 const afterQty=d.side==='BUY'?held+qty:held-qty,afterCash=d.side==='BUY'?cash-amount-fees:cash+amount-fees;
 const others=(await c.query('SELECT h.quantity,a.symbol FROM portfolio_holdings h JOIN assets a ON a.id=h.asset_id WHERE h.portfolio_id=$1 AND h.asset_id<>$2 AND h.quantity>0',[p.id,asset.id])).rows;
 let otherValue=0n;for(const h of others){const q=await md.getQuote(h.symbol);requireFresh(q);otherValue+=quantity(String(h.quantity).replace(/0+$/,'').replace(/\.$/,''))*BigInt(q.priceMinor)/SCALE;}
 const value=afterQty*BigInt(quote.priceMinor)/SCALE;
 return {asset,quote,qty,amount,fees,cost,cash,held,heldCost,afterQty,afterCash,weightAfterBps:bps(value,value+otherValue+afterCash)};
}
function previewData(d:OrderInput,e:Awaited<ReturnType<typeof estimate>>){return {mode:'PAPER',...d,quote:e.quote,amountMinor:e.amount.toString(),feeMinor:e.fees.toString(),estimatedTotalMinor:(d.side==='BUY'?e.amount+e.fees:e.amount-e.fees).toString(),cashAfterMinor:e.afterCash.toString(),weightAfterBps:e.weightAfterBps};}
export async function preview(user:string,d:OrderInput,requestId:string){const result=await transaction(async c=>{const p=await ensure(c,user);if(!await check(c,p,requestId))return null;return previewData(d,await estimate(c,p,d));});if(!result)throw new HttpError(409,'RECONCILIATION_REQUIRED');return result;}
async function saveQuote(c:PoolClient,user:string,assetId:string,q:Quote){return (await c.query('INSERT INTO market_price_snapshots(user_id,asset_id,price_minor,currency,as_of,source,is_delayed,market_status) VALUES($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id',[user,assetId,q.priceMinor,q.currency,q.asOf,q.source,q.isDelayed,q.marketStatus])).rows[0].id;}
export async function mutate(user:string,key:string,d:{amountMinor:string}|OrderInput,requestId:string){
 const hash=createHash('sha256').update(JSON.stringify(d)).digest('hex');
 const result=await transaction(async c=>{
  const p=await ensure(c,user),old=(await c.query('SELECT * FROM portfolio_transactions WHERE user_id=$1 AND idempotency_key=$2',[user,key])).rows[0];
  if(old){if(old.request_hash!==hash)throw new HttpError(409,'IDEMPOTENCY_CONFLICT');return old;}
  if(!await check(c,p,requestId))return null;
  const a=await ownedAccount(c,user),id=randomUUID();let type:string,amount:bigint,fees=0n,cost=0n,pnl=0n,assetId:string|null=null,quoteId:string|null=null,qty:string|null=null;
  let moves:Array<{bucket:string;direction:'DEBIT'|'CREDIT';amount:bigint}>;
  if('amountMinor' in d){
   type='FUND';amount=BigInt(d.amountMinor);const b=await buckets(c,user);
   if(amount>(b.LONG_TERM_RESERVE??0n))throw new HttpError(409,'INSUFFICIENT_RESERVE');
   moves=[{bucket:'LONG_TERM_RESERVE',direction:'DEBIT',amount},{bucket:'PORTFOLIO_CASH',direction:'CREDIT',amount}];
   await c.query('UPDATE portfolio_cash SET amount_minor=amount_minor+$2,updated_at=now() WHERE portfolio_id=$1',[p.id,amount.toString()]);
  }else{
   type=d.side;const e=await estimate(c,p,d);amount=e.amount;fees=e.fees;cost=e.cost;assetId=e.asset.id;qty=decimal(e.qty);quoteId=await saveQuote(c,user,assetId!,e.quote);
   const buy=d.side==='BUY';pnl=buy?0n:amount-fees-cost;
   moves=buy?[{bucket:'PORTFOLIO_CASH',direction:'DEBIT',amount:amount+fees},{bucket:'PORTFOLIO_COST',direction:'CREDIT',amount:cost}]:[{bucket:'PORTFOLIO_COST',direction:'DEBIT',amount:cost},{bucket:'PORTFOLIO_CASH',direction:'CREDIT',amount},{bucket:'PORTFOLIO_CASH',direction:'DEBIT',amount:fees},...(pnl===0n?[]:[{bucket:'PORTFOLIO_PNL',direction:pnl>0n?'DEBIT' as const:'CREDIT' as const,amount:pnl>0n?pnl:-pnl}])];
   await c.query('UPDATE portfolio_cash SET amount_minor=$2,updated_at=now() WHERE portfolio_id=$1',[p.id,e.afterCash.toString()]);
   const newCost=buy?e.heldCost+cost:e.heldCost-cost;
   await c.query('INSERT INTO portfolio_holdings(user_id,instrument,quantity,cost_basis_minor,portfolio_id,asset_id) VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(portfolio_id,asset_id) WHERE portfolio_id IS NOT NULL DO UPDATE SET quantity=$3,cost_basis_minor=$4,updated_at=now()',[user,d.symbol,decimal(e.afterQty),newCost.toString(),p.id,assetId]);
   if(e.held===0n||e.afterQty===0n)await audit(c,user,e.afterQty===0n?'HOLDING_CLOSED':'HOLDING_OPENED','Portfolio',p.id,requestId);
   await audit(c,user,'PORTFOLIO_ORDER_CREATED','PortfolioTransaction',id,requestId);
  }
  const tx=await ledgerTransaction(c,user,a.id,type==='FUND'?'TRANSFER_TO_PORTFOLIO':`PORTFOLIO_${type}`,id,`portfolio:${user}:${key}`,moves.filter(m=>m.amount>0n));
  const saved=(await c.query('INSERT INTO portfolio_transactions(id,portfolio_id,user_id,type,asset_id,quantity,amount_minor,fee_minor,cost_minor,realized_pnl_minor,quote_id,ledger_transaction_id,idempotency_key,request_hash,request_id) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15) RETURNING *',[id,p.id,user,type,assetId,qty,amount.toString(),fees.toString(),cost.toString(),pnl.toString(),quoteId,tx,key,hash,requestId])).rows[0];
  await audit(c,user,type==='FUND'?'PORTFOLIO_FUNDED':'PORTFOLIO_ORDER_FILLED','PortfolioTransaction',id,requestId);
  return saved;
 });if(!result)throw new HttpError(409,'RECONCILIATION_REQUIRED');return result;
}
export async function valuation(user:string,requestId:string){return transaction(async c=>{
 const p=await ensure(c,user),valid=await check(c,p,requestId),cash=BigInt((await c.query('SELECT amount_minor FROM portfolio_cash WHERE portfolio_id=$1',[p.id])).rows[0].amount_minor);
 const rows=(await c.query('SELECT h.*,a.symbol,a.name,a.sector FROM portfolio_holdings h JOIN assets a ON a.id=h.asset_id WHERE h.portfolio_id=$1 AND h.quantity>0 ORDER BY a.symbol',[p.id])).rows;
 let value=0n,cost=0n;const holdings:Array<{id:string;symbol:string;name:string;sector:string;quantity:string;costBasisMinor:string;averageCostMinor:string;marketValueMinor:string;unrealizedPnlMinor:string;quote:Quote;weightBps:number}>=[];for(const h of rows){const quote=await provider(user).getQuote(h.symbol);requireFresh(quote);const qty=quantity(String(h.quantity).replace(/0+$/,'').replace(/\.$/,'')),v=qty*BigInt(quote.priceMinor)/SCALE,k=BigInt(h.cost_basis_minor);value+=v;cost+=k;holdings.push({id:h.id,symbol:h.symbol,name:h.name,sector:h.sector,quantity:decimal(qty),costBasisMinor:k.toString(),averageCostMinor:(k*SCALE/qty).toString(),marketValueMinor:v.toString(),unrealizedPnlMinor:(v-k).toString(),quote,weightBps:0});}
 const total=cash+value;for(const h of holdings)h.weightBps=bps(BigInt(h.marketValueMinor),total);
 const sums=(await c.query("SELECT coalesce(sum(amount_minor) FILTER(WHERE type='FUND'),0)::text AS funded,coalesce(sum(realized_pnl_minor),0)::text AS pnl,coalesce(sum(fee_minor),0)::text AS fees FROM portfolio_transactions WHERE portfolio_id=$1",[p.id])).rows[0];
 const funded=BigInt(sums.funded),pnl=BigInt(sums.pnl),targets=(await c.query('SELECT target,weight_bps AS "weightBps" FROM target_allocations WHERE portfolio_id=$1 ORDER BY target',[p.id])).rows;
 const sectors:Record<string,bigint>={};for(const h of holdings)sectors[h.sector]=(sectors[h.sector]??0n)+BigInt(h.marketValueMinor);
 const peak=BigInt((await c.query('SELECT coalesce(max(total_value_minor-funded_minor),0)::text AS peak FROM portfolio_snapshots WHERE portfolio_id=$1',[p.id])).rows[0].peak),profit=total-funded;
 const result={id:p.id,mode:'PAPER',currency:'THB',source:'synthetic fixture',reconciliationStatus:valid?'OK':'RECONCILIATION_REQUIRED',cashMinor:cash.toString(),marketValueMinor:value.toString(),totalValueMinor:total.toString(),costBasisMinor:cost.toString(),unrealizedPnlMinor:(value-cost).toString(),realizedPnlMinor:pnl.toString(),fundedMinor:funded.toString(),feesMinor:sums.fees,returnBps:bps(profit,funded),holdings,targets:targets.map(t=>{const current=t.target==='CASH'?bps(cash,total):holdings.find(h=>h.symbol===t.target)?.weightBps??0;return {...t,currentBps:current,differenceBps:current-t.weightBps};}),risk:{cashBps:bps(cash,total),largestPositionBps:Math.max(0,...holdings.map(h=>h.weightBps)),drawdownBps:bps(peak>profit?peak-profit:0n,funded+(peak>0n?peak:0n)),unrealizedLossMinor:(value<cost?cost-value:0n).toString(),sectorExposure:Object.entries(sectors).map(([sector,n])=>({sector,weightBps:bps(n,total)})),warnings:holdings.filter(h=>h.weightBps>p.concentration_limit_bps).map(h=>`${h.symbol}: concentration above ${p.concentration_limit_bps} bps`)}};
 if(valid)await c.query('INSERT INTO portfolio_snapshots(portfolio_id,cash_minor,market_value_minor,total_value_minor,cost_basis_minor,unrealized_pnl_minor,realized_pnl_minor,funded_minor) VALUES($1,$2,$3,$4,$5,$6,$7,$8)',[p.id,result.cashMinor,result.marketValueMinor,result.totalValueMinor,result.costBasisMinor,result.unrealizedPnlMinor,result.realizedPnlMinor,result.fundedMinor]);return result;
});}
export async function history(user:string,kind:'funding'|'orders'|'snapshots'){
 return transaction(async c=>{const p=await ensure(c,user);return kind==='snapshots'?(await c.query('SELECT * FROM (SELECT * FROM portfolio_snapshots WHERE portfolio_id=$1 ORDER BY created_at DESC LIMIT 200) s ORDER BY created_at',[p.id])).rows:(await c.query(`SELECT t.*,a.symbol FROM portfolio_transactions t LEFT JOIN assets a ON a.id=t.asset_id WHERE t.portfolio_id=$1 AND ${kind==='funding'?"t.type='FUND'":"t.type<>'FUND'"} ORDER BY t.created_at DESC LIMIT 200`,[p.id])).rows;});
}
