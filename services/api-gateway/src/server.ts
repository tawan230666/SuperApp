import { baseApp, authenticate, finish } from "@tipkhun/auth";
import { riskRoutes } from "@tipkhun/risk-data";
export const app = baseApp("api-gateway");
app.use("/api/v1/auth", async (req,res)=>{
 try {
  const headers:Record<string,string>={'content-type':'application/json','x-request-id':res.locals.requestId};
  for(const key of ['authorization','cookie','origin','x-auth-client'])if(req.header(key))headers[key]=req.header(key)!;
  const upstream=await fetch(`${process.env.AUTH_SERVICE_URL??'http://localhost:3002'}/v1/auth${req.url}`,{method:req.method,headers,body:['GET','HEAD'].includes(req.method)?undefined:JSON.stringify(req.body),signal:AbortSignal.timeout(5000)});
  const cookies=upstream.headers.getSetCookie();if(cookies.length)res.setHeader('set-cookie',cookies);
  res.status(upstream.status).type('json').send(await upstream.text());
 }catch{res.status(503).json({error:'Auth service unavailable',requestId:res.locals.requestId});}
});
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
app.use(['/api/v1/bot','/api/v1/orders','/api/v1/positions','/api/v1/trades','/api/v1/reconcile'],authenticate(),async(req,res)=>{
 try{const upstream=await fetch(`${process.env.TRADING_SERVICE_URL??'http://localhost:3003'}${req.originalUrl.replace('/api/v1','/v1')}`,{method:req.method,headers:{'content-type':'application/json',authorization:req.header('authorization')!,'idempotency-key':req.header('idempotency-key')??'','x-request-id':res.locals.requestId},body:['GET','HEAD'].includes(req.method)?undefined:JSON.stringify(req.body??{}),signal:AbortSignal.timeout(10000)});res.status(upstream.status).type('json').send(await upstream.text());}
 catch{res.status(503).json({error:'Trading service unavailable',requestId:res.locals.requestId});}
});
app.use(['/api/v1/portfolio','/api/v1/watchlist','/api/v1/market'],authenticate(),async(req,res)=>{
 try{const upstream=await fetch(`${process.env.PORTFOLIO_SERVICE_URL??'http://localhost:3006'}${req.originalUrl.replace('/api/v1','/v1')}`,{method:req.method,headers:{'content-type':'application/json',authorization:req.header('authorization')!,'idempotency-key':req.header('idempotency-key')??'','x-request-id':res.locals.requestId},body:['GET','HEAD'].includes(req.method)?undefined:JSON.stringify(req.body??{}),signal:AbortSignal.timeout(10000)});res.status(upstream.status).type('json').send(await upstream.text());}
 catch{res.status(503).json({error:'Portfolio service unavailable',requestId:res.locals.requestId});}
});
app.use(['/api/v1/allocations','/api/v1/ledger','/api/v1/notifications','/api/v1/withdrawals'],authenticate(),async(req,res)=>{
 try{const upstream=await fetch(`${process.env.ALLOCATION_SERVICE_URL??'http://localhost:3005'}${req.originalUrl.replace('/api/v1','/v1')}`,{method:req.method,headers:{'content-type':'application/json',authorization:req.header('authorization')!,'idempotency-key':req.header('idempotency-key')??'','x-request-id':res.locals.requestId},body:['GET','HEAD'].includes(req.method)?undefined:JSON.stringify(req.body??{}),signal:AbortSignal.timeout(10000)});res.status(upstream.status).type('json').send(await upstream.text());}
 catch{res.status(503).json({error:'Allocation service unavailable',requestId:res.locals.requestId});}
});
app.use("/api/v1", riskRoutes());
app.post("/api/v1/risk/check", authenticate(), async (req, res) => {
  try {
    const response = await fetch(
      `${process.env.RISK_SERVICE_URL ?? "http://localhost:3001"}/v1/risk/check`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-request-id": res.locals.requestId,
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
