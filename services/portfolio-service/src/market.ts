import {pool} from '@tipkhun/database';
import {HttpError} from '@tipkhun/auth';

export type Quote = {symbol:string;priceMinor:string;currency:string;timestamp:string;asOf:string;source:string;isDelayed:boolean;isStale:boolean;marketStatus:string};
export type Asset = {id:string;symbol:string;name:string;type:'STOCK'|'ETF';exchange:string;currency:string;country:string;sector:string;industry:string;active:boolean};
export interface MarketDataProvider {
 getQuote(symbol:string):Promise<Quote>;
 getQuotes(symbols:string[]):Promise<Quote[]>;
 getHistoricalBars(symbol:string):Promise<Quote[]>;
 searchAssets(query:string):Promise<Asset[]>;
 getAssetProfile(symbol:string):Promise<Asset>;
}
export function testMarketEnabled() {
 return ['test','development'].includes(process.env.NODE_ENV??'') && process.env.TEST_MODE==='1' &&
 process.env.PAPER_MARKET_PROVIDER==='deterministic' && new URL(process.env.DATABASE_URL??'postgres://localhost/none').pathname.endsWith('_test');
}
export function requireFresh(q:Quote) {
 if(q.isStale || !Number.isFinite(Date.parse(q.asOf)) || Date.now()-Date.parse(q.asOf)>60000 || Date.parse(q.asOf)>Date.now()+5000) throw new HttpError(409,'MARKET_DATA_STALE');
 if(q.marketStatus!=='OPEN') throw new HttpError(409,'MARKET_CLOSED');
}
/** Curated asset identities with explicitly synthetic prices. No external price provider or invented bars. */
export class FixtureMarketDataProvider implements MarketDataProvider {
 constructor(protected readonly userId:string){}
 protected async scenario(_asset:Asset):Promise<string>{return 'unchanged';}
 async getAssetProfile(symbol:string):Promise<Asset>{
  const a=(await pool.query('SELECT * FROM assets WHERE symbol=$1 AND active',[symbol])).rows[0];
  if(!a)throw new HttpError(404,'ASSET_NOT_FOUND');return a;
 }
 async searchAssets(query:string):Promise<Asset[]>{return (await pool.query('SELECT * FROM assets WHERE active AND (symbol ILIKE $1 OR name ILIKE $1) ORDER BY symbol LIMIT 50',[`%${query}%`])).rows;}
 async getQuote(symbol:string):Promise<Quote>{
  const a=await this.getAssetProfile(symbol),scenario=await this.scenario(a);
  if(scenario==='unavailable')throw new HttpError(503,'MARKET_DATA_UNAVAILABLE');
  const base=a.type==='STOCK'?10n:20n;
  const price=scenario==='up'?base*12n/10n:scenario==='down'?base*8n/10n:base;
  const asOf=new Date(Date.now()-(scenario==='stale'?120000:scenario==='delayed'?30000:0)).toISOString();
  return {symbol,priceMinor:price.toString(),currency:a.currency,asOf,timestamp:asOf,source:this instanceof DeterministicMarketDataProvider?'deterministic-paper':'fixture-paper',isDelayed:scenario==='delayed',isStale:scenario==='stale',marketStatus:'OPEN'};
 }
 async getQuotes(symbols:string[]){return Promise.all(symbols.map(s=>this.getQuote(s)));}
 async getHistoricalBars(symbol:string):Promise<Quote[]>{
  const a=await this.getAssetProfile(symbol);
  return (await pool.query('SELECT * FROM market_price_snapshots WHERE user_id=$1 AND asset_id=$2 ORDER BY created_at DESC LIMIT 200',[this.userId,a.id])).rows.map(r=>({symbol,priceMinor:r.price_minor,currency:r.currency,asOf:r.as_of.toISOString(),timestamp:r.as_of.toISOString(),source:r.source,isDelayed:r.is_delayed,isStale:Date.now()-r.as_of.getTime()>60000,marketStatus:r.market_status}));
 }
}
export class DeterministicMarketDataProvider extends FixtureMarketDataProvider {
 protected override async scenario(a:Asset){if(!testMarketEnabled())throw new HttpError(503,'TEST_PROVIDER_DISABLED');return (await pool.query('SELECT scenario FROM paper_market_controls WHERE user_id=$1 AND asset_id=$2',[this.userId,a.id])).rows[0]?.scenario??'unchanged';}
}
// A future real provider implements this contract; there is no live implementation.
export interface RealMarketDataProvider extends MarketDataProvider { readonly source:string }
export const provider=(userId:string):MarketDataProvider=>testMarketEnabled()?new DeterministicMarketDataProvider(userId):new FixtureMarketDataProvider(userId);
