import { describe, expect, it } from 'vitest';
import { evaluateRisk } from './engine.js';

const base = { capitalMinor: 35000, riskUsedMinor: 0, riskReservedMinor: 0, dailyLossLimitMinor: 1750, riskPerTradeMinor: 500, tradeCount: 0, maxTrades: 3, proposedRiskMinor: 500, emergencyStop: false, marketDataAgeSeconds: 1, brokerConnected: true };
describe('authoritative risk engine', () => {
  it('approves within all limits without allowing negative remaining', () => expect(evaluateRisk(base)).toMatchObject({approved:true, riskRemainingMinor:1750, tradesRemaining:3}));
  it('does not replenish budget from profit', () => expect(evaluateRisk({...base, riskUsedMinor: 1750, proposedRiskMinor: 1})).toMatchObject({approved:false, riskRemainingMinor:0}));
  it('stops at loss, emergency, stale data and broker disconnect', () => {
    for (const change of [{riskUsedMinor:1750}, {emergencyStop:true}, {marketDataAgeSeconds:31}, {brokerConnected:false}]) expect(evaluateRisk({...base, ...change} as typeof base).approved).toBe(false);
  });
  it('rejects oversized risk and trade exhaustion', () => {
    expect(evaluateRisk({...base, proposedRiskMinor:501}).approved).toBe(false);
    expect(evaluateRisk({...base, tradeCount:3}).approved).toBe(false);
  });
});
