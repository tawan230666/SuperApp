import {pool} from '@tipkhun/database';
import {z} from 'zod';
import {baseApp,authenticate,finish,HttpError} from '@tipkhun/auth';
import {control,createOrder,getOrder,cancelOrder,closePosition,execute,reconcile,recover,status,list,heartbeat} from './paper.js';
export const app=baseApp('trading-service',async()=>{await pool.query('SELECT order_id FROM paper_broker_orders LIMIT 0');const r=await fetch(`${process.env.RISK_SERVICE_URL??'http://localhost:3001'}/ready`,{signal:AbortSignal.timeout(2000)});if(!r.ok)throw new Error('Risk unavailable');});
app.use('/v1',authenticate());
for(const action of ['start','pause','resume','stop','emergency-stop'])app.post(`/v1/bot/${action}`,async(req,res)=>{z.object({}).strict().parse(req.body??{});res.json(await control(res.locals.identity.id,action,res.locals.requestId));});
app.get('/v1/bot/status',async(_req,res)=>res.json(await status(res.locals.identity.id)));
app.post('/v1/orders',async(req,res)=>res.status(201).json(await createOrder(res.locals.identity.id,req.body,req.header('idempotency-key')??'',req.header('authorization')!,res.locals.requestId)));
for(const kind of ['orders','positions','trades'] as const)app.get(`/v1/${kind}`,async(_req,res)=>res.json(await list(res.locals.identity.id,kind)));
const id=(value:unknown)=>z.string().uuid().parse(value);
app.get('/v1/orders/:id',async(req,res)=>res.json(await getOrder(res.locals.identity.id,id(req.params.id))));
app.post('/v1/orders/:id/cancel',async(req,res)=>res.json(await cancelOrder(res.locals.identity.id,id(req.params.id),res.locals.requestId)));
app.post('/v1/orders/:id/continue',async(req,res)=>res.json(await execute(res.locals.identity.id,id(req.params.id),res.locals.requestId,true)));
app.post('/v1/positions/:id/close',async(req,res)=>res.json(await closePosition(res.locals.identity.id,id(req.params.id),res.locals.requestId)));
app.post('/v1/reconcile',async(_req,res)=>res.json(await reconcile(res.locals.identity.id)));
finish(app);
if(process.env.NODE_ENV!=='test'){
 await recover();await heartbeat();
 const timer=setInterval(()=>{heartbeat().catch(()=>{});},5000);timer.unref();
 const server=app.listen(Number(process.env.TRADING_PORT??3003));
 process.on('SIGTERM',()=>{clearInterval(timer);server.close(()=>{pool.end().catch(()=>{});});});
}
