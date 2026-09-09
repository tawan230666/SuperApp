import crypto from 'node:crypto';
import express from 'express';
import type { Express } from 'express';
import cors from 'cors';
import helmet from 'helmet';

export const app: Express = express();
app.disable('x-powered-by');
app.use(helmet());
app.use(cors({ origin: process.env.WEB_ORIGIN?.split(',') ?? ['http://localhost:5173'] }));
app.use(express.json({ limit: '64kb' }));
app.use((req, res, next) => { const id = req.header('x-request-id') ?? crypto.randomUUID(); res.setHeader('x-request-id', id); next(); });
app.get('/health', (_req, res) => res.json({ service: 'api-gateway', status: 'ok', timestamp: new Date().toISOString() }));
app.get('/ready', (_req, res) => res.json({ service: 'api-gateway', status: 'ready', timestamp: new Date().toISOString() }));
app.get('/api/v1', (_req, res) => res.json({ service: 'api-gateway', version: 'v1', mode: 'simulation', liveTrading: 'LOCKED', routes: ['/auth','/users','/risk','/trades','/bot','/portfolio','/allocations','/ai'] }));
app.post('/api/v1/risk/check', async (req, res) => {
  const target = process.env.RISK_SERVICE_URL ?? 'http://localhost:3001';
  try { const response = await fetch(`${target}/v1/risk/check`, { method: 'POST', headers: {'content-type':'application/json','x-request-id': String(res.getHeader('x-request-id'))}, body: JSON.stringify(req.body) }); return res.status(response.status).type('json').send(await response.text()); }
  catch { return res.status(503).json({ error: 'Risk service unavailable', requestId: res.getHeader('x-request-id') }); }
});

if (process.env.NODE_ENV !== 'test') { const port = Number(process.env.API_PORT ?? 3000); app.listen(port, () => console.log(JSON.stringify({ service: 'api-gateway', port }))); }
