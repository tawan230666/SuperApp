import { describe, expect, it } from "vitest";
import request from "supertest";
import { app } from "./server.js";

describe("API gateway", () => {
  it("returns health and a request id", async () => {
    const response = await request(app).get("/health");
    expect(response.status).toBe(200);
    expect(response.headers["x-request-id"]).toMatch(/^[0-9a-f-]{36}$/);
  });
  it("exposes versioned API capabilities without claiming live trading", async () => {
    const response = await request(app).get("/api/v1");
    expect(response.body.liveTrading).toBe("LOCKED");
  });
});

it('sanitizes malformed input and retains request id',async()=>{
 const response=await request(app).post('/api/v1/auth/register').set('Content-Type','application/json').send('{');
 expect(response.status).toBe(400);expect(response.body.error).toBe('Invalid request');
 expect(response.body.requestId).toMatch(/^[0-9a-f-]{36}$/);expect(response.body.stack).toBeUndefined();
});
