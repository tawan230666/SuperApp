import {it,expect} from 'vitest';
import {quantity,decimal,basisSold,fee} from './accounting.js';
import {requireFresh,testMarketEnabled} from './market.js';
it('six decimal quantities preserve precision above JS safe integer',()=>{expect(decimal(quantity('987654321012.123456'))).toBe('987654321012.123456');expect(()=>quantity('1.0000001')).toThrow();expect(()=>quantity('0')).toThrow();});
it('average cost disposal preserves the final remainder',()=>{expect(basisSold(101n,3n,1n)).toBe(33n);expect(basisSold(68n,2n,2n)).toBe(68n);expect(()=>basisSold(1n,1n,2n)).toThrow();});
it('fees round up without binary floating point',()=>{expect(fee(101n)).toBe(1n);expect(fee(1001n)).toBe(2n);});
it('stale and future quotes fail explicitly',()=>{const q={symbol:'PTT',priceMinor:'10',currency:'THB',timestamp:'',asOf:new Date().toISOString(),source:'test',isDelayed:true,isStale:false,marketStatus:'OPEN'};expect(()=>requireFresh(q)).not.toThrow();expect(()=>requireFresh({...q,isStale:true})).toThrow('MARKET_DATA_STALE');expect(()=>requireFresh({...q,asOf:new Date(Date.now()+100000).toISOString()})).toThrow('MARKET_DATA_STALE');});
it('production cannot enable test controls',()=>{const old={...process.env};try{process.env.NODE_ENV='production';process.env.TEST_MODE='1';process.env.PAPER_MARKET_PROVIDER='deterministic';process.env.DATABASE_URL='postgres://localhost/paper_test';expect(testMarketEnabled()).toBe(false);}finally{process.env=old;}});
