import { describe, expect, it } from 'vitest';
import request from 'supertest';
import { app } from './server.js';

describe('API gateway', () => {
  it('returns health and a request id', async () => { const response = await request(app).get('/health'); expect(response.status).toBe(200); expect(response.headers['x-request-id']).toMatch(/^[0-9a-f-]{36}$/); });
  it('exposes versioned API capabilities without claiming live trading', async () => { const response = await request(app).get('/api/v1'); expect(response.body.liveTrading).toBe('LOCKED'); });
});
