import express from 'express';
import helmet from 'helmet';
import {rateLimit} from 'express-rate-limit';
import {createHmac,timingSafeEqual,randomUUID} from 'node:crypto';
import {z} from 'zod';
import {aiPool,assertIsolation,readContext,saveDecision,decisions} from './store.js';
import {DeterministicAIProvider,capabilities} from './provider.js';
import {generateProposal} from './generate.js';
import {copilotModeSchema} from './output.js';
const provider=new DeterministicAIProvider();
export const app:express.Express=express();app.disable('x-powered-by');app.use(helmet());
app.use(express.json({limit:'16kb'}));app.use(rateLimit({windowMs:60000,limit:process.env.TEST_MODE==='1'?10000:60}));
app.use((_q,r,next)=>{r.setHeader('Cache-Control','no-store');next();});
app.get('/health',(_q,r)=>r.json({service:'ai-service',provider:'mock-local'}));
app.get('/ready',async(_q,r)=>{try{await assertIsolation();r.json({status:'ready',capabilities});}catch{r.status(503).json({status:'unavailable'});}});
// A signed audience/path/body-bound assertion replaces the user's reusable execution credential.
app.use('/v1',async(q,r,next)=>{
 const raw=q.header('x-ai-identity')??'',sig=q.header('x-ai-signature')??'',secret=process.env.AI_GATEWAY_SECRET;
 if(!secret||!raw||!/^\w{64}$/.test(sig)||q.header('authorization')){r.status(401).json({error:'Gateway identity required'});return;}
 const expected=createHmac('sha256',secret).update(raw).digest('hex');
 if(!timingSafeEqual(Buffer.from(expected),Buffer.from(sig))){r.status(401).json({error:'Invalid gateway identity'});return;}
 let claim;try{claim=z.object({aud:z.literal('ai-copilot'),userId:z.string().uuid(),requestId:z.string().uuid(),expires:z.number(),method:z.string(),path:z.string(),body:z.string()}).strict().parse(JSON.parse(Buffer.from(raw,'base64url').toString()));}catch{r.status(401).json({error:'Invalid gateway identity'});return;}
 if(claim.expires<Date.now()||claim.expires>Date.now()+30000||claim.method!==q.method||claim.path!==q.originalUrl||claim.body!==JSON.stringify(q.body??{})){r.status(401).json({error:'Invalid gateway identity'});return;}
 await assertIsolation();r.locals.identity=claim;next();
});
app.get('/v1/copilot/context',async(_q,r)=>r.json(await readContext(r.locals.identity.userId)));
app.get('/v1/copilot/decisions',async(_q,r)=>r.json(await decisions(r.locals.identity.userId)));
app.post('/v1/copilot/query',async(q,r)=>{
 const input=z.object({question:z.string().trim().min(1).max(2000),copilotMode:copilotModeSchema.default('ASK_FINANCIAL_QUESTION')}).strict().parse(q.body);
 const c=await readContext(r.locals.identity.userId),proposal=await generateProposal(provider,input.question,c,input.copilotMode);
 const saved=await saveDecision(r.locals.identity.userId,r.locals.identity.requestId,proposal);r.status(201).json({...proposal,id:saved.id,createdAt:saved.created_at});
});
app.use((_q,r)=>r.status(404).json({error:'Not found'}));
app.use(((e:any,_q:any,r:any,_next:any)=>r.status(e instanceof z.ZodError||e?.type==='entity.parse.failed'?400:503).json({error:e instanceof z.ZodError?'Invalid request':'AI unavailable',requestId:randomUUID()})) as express.ErrorRequestHandler);
if(process.env.NODE_ENV!=='test'){await assertIsolation();const server=app.listen(Number(process.env.AI_PORT??3007),'127.0.0.1');process.on('SIGTERM',()=>server.close(()=>{aiPool.end().catch(()=>{});}));}
