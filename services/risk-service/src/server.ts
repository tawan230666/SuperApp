import express from 'express';
import type { Express } from 'express';
import { riskCheckRequestSchema } from '@tipkhun/contracts';
import { evaluateRisk } from './engine.js';

export const app: Express = express();
app.use(express.json({ limit: '32kb' }));
app.get('/health', (_req, res) => res.json({ service: 'risk-service', status: 'ok', timestamp: new Date().toISOString() }));
app.get('/ready', (_req, res) => res.json({ service: 'risk-service', status: 'ready', timestamp: new Date().toISOString() }));
app.post('/v1/risk/check', (req, res) => {
  const parsed = riskCheckRequestSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: 'Invalid risk request' });
  return res.json(evaluateRisk(parsed.data));
});

if (process.env.NODE_ENV !== 'test') {
  const port = Number(process.env.RISK_PORT ?? 3001);
  app.listen(port, () => console.log(JSON.stringify({ service: 'risk-service', port })));
}
