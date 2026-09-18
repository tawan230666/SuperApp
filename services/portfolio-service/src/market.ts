import {pool} from '@tipkhun/database';
import {FixtureMarketDataProvider,DeterministicMarketDataProvider,type ReadQuery} from '@tipkhun/financial-read';
export {requireFresh,type Quote,type Asset,type MarketDataProvider,type RealMarketDataProvider} from '@tipkhun/financial-read';
export function testMarketEnabled() {
 return ['test','development'].includes(process.env.NODE_ENV??'') && process.env.TEST_MODE==='1' &&
 process.env.PAPER_MARKET_PROVIDER==='deterministic' && new URL(process.env.DATABASE_URL??'postgres://localhost/none').pathname.endsWith('_test');
}
export const provider=(userId:string,db:ReadQuery=pool)=>testMarketEnabled()?new DeterministicMarketDataProvider(userId,db):new FixtureMarketDataProvider(userId,db);
