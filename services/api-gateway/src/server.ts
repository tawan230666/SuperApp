import { baseApp, authRoutes, authenticate, finish } from "@tipkhun/auth";
import { riskRoutes } from "@tipkhun/risk-data";
export const app = baseApp("api-gateway");
app.use("/api/v1/auth", authRoutes());
app.get("/api/v1/me", authenticate(), (_req, res) => {
  const { id, email, role } = res.locals.identity;
  res.json({ id, email, role });
});
app.get("/api/v1", (_req, res) =>
  res.json({
    service: "api-gateway",
    version: "v1",
    mode: "simulation",
    liveTrading: "LOCKED",
  }),
);
app.use("/api/v1", riskRoutes());
app.post("/api/v1/risk/check", authenticate(), async (req, res) => {
  try {
    const response = await fetch(
      `${process.env.RISK_SERVICE_URL ?? "http://localhost:3001"}/v1/risk/check`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: req.header("authorization")!,
        },
        body: JSON.stringify(req.body),
        signal: AbortSignal.timeout(5000),
      },
    );
    res
      .status(response.status)
      .type("json")
      .send(await response.text());
  } catch {
    res
      .status(503)
      .json({
        error: "Risk service unavailable",
        requestId: res.locals.requestId,
      });
  }
});
finish(app);
if (process.env.NODE_ENV !== "test")
  app.listen(Number(process.env.API_PORT ?? 3000));
