import express from 'express'; import type { Express } from 'express';
export const app: Express=express(); app.use(express.json({limit:'32kb'}));
app.get('/health',(_req,res)=>res.json({service:'trading-service',status:'ok',mode:'paper',liveTrading:'LOCKED',timestamp:new Date().toISOString()}));
app.get('/ready',(_req,res)=>res.json({service:'trading-service',status:'ready',timestamp:new Date().toISOString()}));
app.post('/v1/bot/start',(_req,res)=>res.status(501).json({error:'Execution is available only through the existing local Flutter PaperEngine'}));
if(process.env.NODE_ENV!=='test') app.listen(Number(process.env.TRADING_PORT??3003));
