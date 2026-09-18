import {describe,it,expect} from 'vitest';
import {freshQuote,replay,assertSandbox,AlpacaBrokerProvider,SettradeBrokerProvider,type Quote,type Fill} from './domain.js';
import {DeterministicSandboxBrokerProvider,MockBrokerProvider} from './provider.js';
import {EncryptedCredentialVault} from './vault.js';
const quote:Quote={priceMinor:'100',feeMinor:'0',source:'synthetic-sandbox',status:'FRESH',asOf:new Date().toISOString()};
const fill:Fill={id:'test',clientOrderId:'test',sequence:'1',symbol:'PTT',side:'BUY',quantity:'4',priceMinor:'100',feeMinor:'0',realizedPnlMinor:'0',executedAt:new Date().toISOString()};
describe('broker pure security and accounting',()=>{
 it('rejects invalid/future/old/unavailable quotes',()=>{expect(freshQuote({...quote,asOf:new Date().toISOString()})).toBe(true);for(const asOf of ['invalid',new Date(Date.now()+60000).toISOString(),new Date(Date.now()-60001).toISOString()])expect(freshQuote({...quote,asOf})).toBe(false);expect(freshQuote({...quote,status:'UNAVAILABLE'})).toBe(false);});
 it('replays integer cash/cost and realized loss across partial sells without float drift',()=>{expect(replay('1000',[fill,{...fill,id:'sell',sequence:'2',side:'SELL',quantity:'3',priceMinor:'90',feeMinor:'1',realizedPnlMinor:'-31'}])).toEqual({cashMinor:'869',positions:[{symbol:'PTT',quantity:'1',costMinor:'100'}]});});
 it('rejects fill gaps, shorts, negative cash and fabricated profit',()=>{for(const fills of [[{...fill,sequence:'2'}],[{...fill,side:'SELL' as const}],[{...fill,quantity:'100'}],[{...fill,realizedPnlMinor:'1'}]])expect(()=>replay('1000',fills)).toThrow();});
 it('requires exactly 256-bit vault key material',()=>{for(const size of [0,16,31,33])expect(()=>new EncryptedCredentialVault(Buffer.alloc(size))).toThrow('BROKER_VAULT_UNAVAILABLE');});
 it('only mock and deterministic sandbox have execution capabilities; future adapters stay locked',()=>{for(const provider of [new DeterministicSandboxBrokerProvider(),new MockBrokerProvider()])expect(()=>assertSandbox(provider)).not.toThrow();expect(AlpacaBrokerProvider.prototype.getCapabilities()).toMatchObject({mode:'LOCKED',submit:false});expect(SettradeBrokerProvider.prototype.getCapabilities()).toMatchObject({provider:'settrade',mode:'LOCKED',submit:false});});
});
