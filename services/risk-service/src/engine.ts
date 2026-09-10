import type { RiskCheckRequest, RiskDecision } from '@tipkhun/contracts';

/** Authoritative deterministic gate. It never accepts an AI override. */
export function evaluateRisk(input: RiskCheckRequest): RiskDecision {
  const dailyConsumed = input.riskUsedMinor + input.riskReservedMinor;
  const remaining = Math.max(0, Math.min(input.dailyLossLimitMinor, input.capitalMinor) - dailyConsumed);
  const tradesRemaining = Math.max(0, input.maxTrades - input.tradeCount);
  let reason: string | null = null;
  if (input.emergencyStop) reason = 'Emergency stop is active';
  else if (!input.brokerConnected) reason = 'Broker is disconnected';
  else if (input.marketDataAgeSeconds > 30) reason = 'Market data is stale';
  else if (input.riskUsedMinor >= input.dailyLossLimitMinor) reason = 'Daily loss limit reached';
  else if (remaining <= 0) reason = 'Risk budget exhausted';
  else if (tradesRemaining <= 0) reason = 'Maximum trades reached';
  else if (input.proposedRiskMinor <= 0 || input.proposedRiskMinor > input.riskPerTradeMinor) reason = 'Proposed risk exceeds per-trade limit';
  else if (input.proposedRiskMinor > remaining) reason = 'Proposed risk exceeds remaining budget';
  return { approved: reason === null, reason, riskRemainingMinor: remaining, tradesRemaining, status: reason === null ? 'ACTIVE' : 'STOPPED' };
}
