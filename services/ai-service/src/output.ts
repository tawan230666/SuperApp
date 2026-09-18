import {z} from 'zod';
export const copilotModeSchema=z.enum(['PORTFOLIO_REVIEW','RISK_REVIEW','TRADING_REVIEW','PROFIT_REVIEW','DAILY_SUMMARY','ASK_FINANCIAL_QUESTION']);
export type CopilotMode=z.infer<typeof copilotModeSchema>;
export const freshnessSchema=z.record(z.object({source:z.string(),observedAt:z.string().datetime(),dataAsOf:z.string().datetime().nullable(),status:z.enum(['CURRENT_SNAPSHOT','STORED_HISTORY','STALE','DELAYED','UNAVAILABLE','EMPTY']),note:z.string()}).strict());
export type Freshness=z.infer<typeof freshnessSchema>;
const fact=z.object({label:z.string(),value:z.union([z.string(),z.number(),z.null()]),unit:z.string(),source:z.string()}).strict();
export const outputSchema=z.object({
 freshness:freshnessSchema,provider:z.string(),model:z.string(),mode:z.literal('PAPER'),copilotMode:copilotModeSchema,
 intent:z.enum(['REFUSED_EXECUTION','ANALYSIS']),summary:z.string().min(1),observedAt:z.string().datetime(),dataAsOf:z.string().datetime(),
 capabilities:z.object({read:z.literal(true),analyze:z.literal(true),propose:z.literal(true),execute:z.literal(false),overrideRisk:z.literal(false),provider:z.string(),tools:z.array(z.never()).length(0)}).strict(),
 facts:z.array(fact),observations:z.array(fact),risks:z.array(z.string()),opportunities:z.array(z.string()),recommendations:z.array(z.object({kind:z.string(),message:z.string()}).strict()),
 warnings:z.array(z.string()),proposals:z.array(z.object({kind:z.string(),message:z.string()}).strict()),confidence:z.number().min(0).max(1),executionAuthorized:z.literal(false),riskCheck:z.null()
}).strict();
export type StructuredOutput=z.infer<typeof outputSchema>;
