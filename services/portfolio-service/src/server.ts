import express from 'express'; import type { Express } from 'express';
export const app: Express=express(); app.get('/health',(_req,res)=>res.json({service:'portfolio-service',status:'ok',mode:'simulation',timestamp:new Date().toISOString()})); app.get('/ready',(_req,res)=>res.json({service:'portfolio-service',status:'ready',timestamp:new Date().toISOString()})); app.get('/v1/portfolio',(_req,res)=>res.status(501).json({error:'Portfolio persistence is planned; no fabricated holdings are returned'}));
if(process.env.NODE_ENV!=='test') app.listen(Number(process.env.PORTFOLIO_PORT??3004));
