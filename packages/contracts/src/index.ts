import { z } from "zod";

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
  brokerConnected: z.boolean(),
});
export type RiskCheckRequest = z.infer<typeof riskCheckRequestSchema>;
export type RiskDecision = {
  approved: boolean;
  reason: string | null;
  riskRemainingMinor: number;
  tradesRemaining: number;
  status: "ACTIVE" | "STOPPED";
};
export const healthResponseSchema = z.object({
  service: z.string(),
  status: z.enum(["ok", "ready"]),
  timestamp: z.string(),
});
export const apiErrorSchema = z.object({
  error: z.string(),
  requestId: z.string(),
});

/** Remote persistence contracts use decimal strings for PostgreSQL bigint money. */
export const persistedMinorSchema = z
  .string()
  .regex(/^[1-9][0-9]{0,18}$/)
  .refine(
    (v) => /^[1-9][0-9]{0,18}$/.test(v) && BigInt(v) <= 9223372036854775807n,
  );
export const authCredentialsSchema = z
  .object({
    email: z
      .string()
      .trim()
      .email()
      .max(254)
      .transform((v) => v.toLowerCase()),
    password: z
      .string()
      .min(12)
      .max(72)
      .refine((v) => new TextEncoder().encode(v).length <= 72),
  })
  .strict();
export const investmentPlanSchema = z
  .object({
    capitalMinor: persistedMinorSchema,
    dailyLossLimitMinor: persistedMinorSchema,
    riskPerTradeMinor: persistedMinorSchema,
    maxTrades: z.number().int().min(1).max(100),
  })
  .strict()
  .refine(
    (v) =>
      [v.capitalMinor, v.dailyLossLimitMinor, v.riskPerTradeMinor].every((x) =>
        /^[1-9][0-9]{0,18}$/.test(x),
      ) &&
      BigInt(v.riskPerTradeMinor) <= BigInt(v.dailyLossLimitMinor) &&
      BigInt(v.dailyLossLimitMinor) <= BigInt(v.capitalMinor),
  );
export const persistedRiskProfileSchema = z
  .object({
    riskTolerance: z.number().int().min(0).max(10000),
    dailyLossLimit: persistedMinorSchema,
    riskPerTrade: persistedMinorSchema,
    maxTrades: z.number().int().min(1).max(100),
    maxPositions: z.number().int().min(1).max(100),
    maxDrawdown: z.number().int().min(1).max(10000),
  })
  .strict()
  .refine(
    (v) =>
      [v.riskPerTrade, v.dailyLossLimit].every((x) =>
        /^[1-9][0-9]{0,18}$/.test(x),
      ) && BigInt(v.riskPerTrade) <= BigInt(v.dailyLossLimit),
  );
export const proposedRiskSchema = z
  .object({ proposedRiskMinor: persistedMinorSchema })
  .strict();
