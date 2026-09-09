import { z } from 'zod';

export const moneyMinorSchema = z.number().int().finite().nonnegative();
export const riskCheckRequestSchema = z.object({
  capitalMinor: moneyMinorSchema,
  riskUsedMinor: moneyMinorSchema.default(0),
  riskReservedMinor: moneyMinorSchema.default(0),
  dailyLossLimitMinor: moneyMinorSchema,
  riskPerTradeMinor: moneyMinorSchema,
  tradeCount: z.number().int().nonnegative(),
  maxTrades: z.number().int().nonnegative(),
  proposedRiskMinor: moneyMinorSchema,
  emergencyStop: z.boolean().default(false),
  marketDataAgeSeconds: z.number().nonnegative(),
  brokerConnected: z.boolean()
});
export type RiskCheckRequest = z.infer<typeof riskCheckRequestSchema>;
export type RiskDecision = { approved: boolean; reason: string | null; riskRemainingMinor: number; tradesRemaining: number; status: 'ACTIVE' | 'STOPPED' };
export const healthResponseSchema = z.object({ service: z.string(), status: z.enum(['ok','ready']), timestamp: z.string() });
export const apiErrorSchema = z.object({ error: z.string(), requestId: z.string() });
