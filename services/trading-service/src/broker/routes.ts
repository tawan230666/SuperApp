import {Router} from 'express';
import {z} from 'zod';
import {BrokerExecution} from './execution.js';
import {EncryptedCredentialVault} from './vault.js';
import {HttpError} from '@tipkhun/auth';

// Lazy construction keeps existing Paper/AI usable without a broker vault key.
let execution:BrokerExecution|undefined;
function service(){
 const encoded=process.env.BROKER_VAULT_KEY;
 if(!encoded||!/^[a-f0-9]{64}$/.test(encoded))throw new HttpError(503,'Broker vault unavailable');
 return execution??=new BrokerExecution(new EncryptedCredentialVault(Buffer.from(encoded,'hex')));
}
export function brokerRoutes():Router{
 const r=Router(),id=(v:unknown)=>z.string().uuid().parse(v),empty=(v:unknown)=>z.object({}).strict().parse(v??{});
 r.get('/brokers',async(_q,s)=>s.json({mode:'SANDBOX',liveTrading:'LOCKED',providers:['mock','deterministic-sandbox'],connections:await service().list(s.locals.identity.id)}));
 r.post('/brokers/:provider/connect',async(q,s)=>{empty(q.body);s.status(201).json(await service().connect(s.locals.identity.id,q.params.provider,q.header('idempotency-key')??'',s.locals.requestId));});
 r.post('/brokers/:id/disconnect',async(q,s)=>{empty(q.body);s.json(await service().disconnect(s.locals.identity.id,id(q.params.id),q.header('idempotency-key')??'',s.locals.requestId));});
 r.post('/broker/:id/emergency-stop',async(q,s)=>{empty(q.body);s.json(await service().emergencyStop(s.locals.identity.id,id(q.params.id),q.header('idempotency-key')??'',s.locals.requestId));});
 r.get('/broker/accounts',async(_q,s)=>s.json(await service().list(s.locals.identity.id)));
 for(const kind of ['balances','positions'])r.get(`/broker/${kind}`,async(q,s)=>s.json(await service().balances(s.locals.identity.id,id(q.query.connectionId))));
 r.post('/broker/orders/preview',async(q,s)=>s.status(201).json(await service().preview(s.locals.identity.id,q.body,q.header('idempotency-key')??'',s.locals.requestId)));
 r.post('/broker/orders/confirm',async(q,s)=>s.json(await service().confirm(s.locals.identity.id,q.body,s.locals.requestId)));
 r.get('/broker/orders',async(_q,s)=>s.json(await service().orders(s.locals.identity.id)));
 r.get('/broker/orders/:id',async(q,s)=>s.json(await service().getOrder(s.locals.identity.id,id(q.params.id))));
 r.post('/broker/orders/:id/cancel',async(q,s)=>{empty(q.body);s.json(await service().cancel(s.locals.identity.id,id(q.params.id),q.header('idempotency-key')??'',s.locals.requestId));});
 r.post('/broker/reconcile',async(q,s)=>{const body=z.object({connectionId:z.string().uuid()}).strict().parse(q.body);s.json(await service().reconcile(s.locals.identity.id,body.connectionId,q.header('idempotency-key')??'',s.locals.requestId));});
 return r;
}
/** Authenticated by scoped broker event HMAC, separate from user API. */
export async function brokerEvent(input:unknown,signature:string,requestId:string){return service().event(input,signature,requestId);}
