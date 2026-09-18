import {pool} from '@tipkhun/database';
import { z } from "zod";
import { baseApp, authenticate, finish } from "@tipkhun/auth";
import { authoritativeCheck, minor, reservePaperOrder } from "@tipkhun/risk-data";
export const app = baseApp("risk-service",async()=>{await pool.query("SELECT order_id FROM risk_reservations LIMIT 0");});
app.post("/v1/risk/check", authenticate(), async (req, res) => {
  const d = z.object({ proposedRiskMinor: minor }).strict().parse(req.body);
  res.json(
    await authoritativeCheck(res.locals.identity.id, d.proposedRiskMinor),
  );
});
app.post('/v1/risk/reserve',authenticate(),async(req,res)=>{
 const {orderId}=z.object({orderId:z.string().uuid()}).strict().parse(req.body);
 res.json(await reservePaperOrder(res.locals.identity.id,orderId,res.locals.requestId));
});
finish(app);
if (process.env.NODE_ENV !== "test")
  app.listen(Number(process.env.RISK_PORT ?? 3001));
