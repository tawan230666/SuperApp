import { z } from "zod";
import { baseApp, authenticate, finish } from "@tipkhun/auth";
import { authoritativeCheck, minor } from "@tipkhun/risk-data";
export const app = baseApp("risk-service");
app.post("/v1/risk/check", authenticate(), async (req, res) => {
  const d = z.object({ proposedRiskMinor: minor }).strict().parse(req.body);
  res.json(
    await authoritativeCheck(res.locals.identity.id, d.proposedRiskMinor),
  );
});
finish(app);
if (process.env.NODE_ENV !== "test")
  app.listen(Number(process.env.RISK_PORT ?? 3001));
