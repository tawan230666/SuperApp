export const events = ['trade.created','trade.closed','risk.limit_reached','allocation.created','bot.started','bot.stopped'] as const;
export type DomainEvent = typeof events[number];
export const serviceHealth = (service: string, status: 'ok'|'ready') => ({ service, status, timestamp: new Date().toISOString() });
