import express from 'express'; import type { Express } from 'express';
export const app: Express = express();
app.use(express.json({limit:'32kb'}));
app.get('/health', (_req,res)=>res.json({service:'auth-service',status:'ok',timestamp:new Date().toISOString()}));
app.get('/ready', (_req,res)=>res.json({service:'auth-service',status:'ready',timestamp:new Date().toISOString()}));
app.post('/v1/auth/register', (_req,res)=>res.status(501).json({error:'Auth persistence is not enabled in this milestone'}));
app.post('/v1/auth/login', (_req,res)=>res.status(501).json({error:'Auth persistence is not enabled in this milestone'}));
if(process.env.NODE_ENV!=='test') app.listen(Number(process.env.AUTH_PORT??3002));
