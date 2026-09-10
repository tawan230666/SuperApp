import { describe, expect, it } from 'vitest';
import { riskCheckRequestSchema } from './index.js';

describe('contracts', () => {
  it('rejects fractional minor units and negative money', () => {
    expect(() => riskCheckRequestSchema.parse({capitalMinor: 35000.5, dailyLossLimitMinor: 1750, riskPerTradeMinor: 500, tradeCount: 0, maxTrades: 3, proposedRiskMinor: 500, marketDataAgeSeconds: 1, brokerConnected: true})).toThrow();
  });
});
