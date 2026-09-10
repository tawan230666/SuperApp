import {baseApp,authenticate,finish,HttpError,audit} from '@tipkhun/auth';
import {pool,transaction} from '@tipkhun/database';
import {z} from 'zod';
import {ensure,cashView,mutate,preview,valuation,history} from './portfolio.js';
import {provider,testMarketEnabled} from './market.js';
const app=baseApp('portfolio-service',async()=>{await pool.query('SELECT id FROM portfolios LIMIT 0');await pool.query('SELECT id FROM assets LIMIT 0');});
app.use('/v1',authenticate());
const symbol=z.string().regex(/^[A-Z0-9.-]{1,30}$/),minor=z.string().regex(/^[1-9]\d{0,14}$/),order=z.object({side:z.enum(['BUY','SELL']),symbol,quantity:z.string().regex(/^\d{1,12}(\.\d{1,6})?$/)}).strict();
const uid=(r:any):string=>r.locals.identity.id;
const key=(req:any)=>z.string().regex(/^[A-Za-z0-9_.:-]{8,128}$/).parse(req.header('idempotency-key'));
async function event(user:string,requestId:string,e:unknown){if(e instanceof HttpError)await transaction(async c=>{await audit(c,user,e.message.startsWith('MARKET_DATA')?e.message:'PORTFOLIO_ORDER_REJECTED','User',user,requestId);});}
app.get('/v1/portfolio/cash',async(_q,r)=>r.json(await cashView(uid(r))));
app.post('/v1/portfolio/fund',async(q,r)=>r.status(201).json(await mutate(uid(r),key(q),z.object({amountMinor:minor}).strict().parse(q.body),r.locals.requestId)));
app.get('/v1/portfolio/funding-history',async(_q,r)=>r.json(await history(uid(r),'funding')));
app.post('/v1/portfolio/orders/preview',async(q,r)=>{try{r.json(await preview(uid(r),order.parse(q.body),r.locals.requestId));}catch(e){await event(uid(r),r.locals.requestId,e);throw e;}});
app.post('/v1/portfolio/orders',async(q,r)=>{try{r.status(201).json(await mutate(uid(r),key(q),order.parse(q.body),r.locals.requestId));}catch(e){await event(uid(r),r.locals.requestId,e);throw e;}});
app.get('/v1/portfolio/orders',async(_q,r)=>r.json(await history(uid(r),'orders')));
app.get('/v1/portfolio',async(_q,r)=>r.json(await valuation(uid(r),r.locals.requestId)));
app.get('/v1/portfolio/holdings',async(_q,r)=>r.json((await valuation(uid(r),r.locals.requestId)).holdings));
app.get('/v1/portfolio/performance',async(_q,r)=>{await valuation(uid(r),r.locals.requestId);r.json(await history(uid(r),'snapshots'));});
app.get('/v1/portfolio/targets',async(_q,r)=>r.json((await valuation(uid(r),r.locals.requestId)).targets));
app.put('/v1/portfolio/targets',async(q,r)=>{
 const d=z.object({targets:z.array(z.object({target:symbol,weightBps:z.number().int().min(0).max(10000)}).strict()).min(1).max(50),concentrationLimitBps:z.number().int().min(1).max(10000).optional()}).strict().refine(x=>x.targets.reduce((a,t)=>a+t.weightBps,0)===10000&&new Set(x.targets.map(t=>t.target)).size===x.targets.length).parse(q.body);
 await transaction(async c=>{const p=await ensure(c,uid(r));for(const t of d.targets)if(t.target!=='CASH')await provider(uid(r)).getAssetProfile(t.target);await c.query('DELETE FROM target_allocations WHERE portfolio_id=$1',[p.id]);for(const t of d.targets)await c.query('INSERT INTO target_allocations(portfolio_id,target,weight_bps) VALUES($1,$2,$3)',[p.id,t.target,t.weightBps]);if(d.concentrationLimitBps)await c.query('UPDATE portfolios SET concentration_limit_bps=$2 WHERE id=$1',[p.id,d.concentrationLimitBps]);await audit(c,uid(r),'PORTFOLIO_TARGETS_UPDATED','Portfolio',p.id,r.locals.requestId);});r.json(d);
});
app.get('/v1/market/assets',async(q,r)=>r.json(await provider(uid(r)).searchAssets(z.string().max(80).parse(q.query.q??''))));
app.get('/v1/market/quotes/:symbol',async(q,r)=>r.json(await provider(uid(r)).getQuote(symbol.parse(q.params.symbol))));
app.get('/v1/market/history/:symbol',async(q,r)=>r.json(await provider(uid(r)).getHistoricalBars(symbol.parse(q.params.symbol))));
app.get('/v1/watchlist',async(_q,r)=>{const rows=(await pool.query('SELECT a.* FROM watchlist_assets wa JOIN watchlists w ON w.id=wa.watchlist_id JOIN assets a ON a.id=wa.asset_id WHERE w.user_id=$1 ORDER BY a.symbol',[uid(r)])).rows;r.json(await Promise.all(rows.map(async a=>({...a,quote:await provider(uid(r)).getQuote(a.symbol)}))));});
app.post('/v1/watchlist',async(q,r)=>{const d=z.object({symbol}).strict().parse(q.body),a=await provider(uid(r)).getAssetProfile(d.symbol);await transaction(async c=>{await ensure(c,uid(r));const w=(await c.query('INSERT INTO watchlists(user_id) VALUES($1) ON CONFLICT(user_id) DO UPDATE SET user_id=EXCLUDED.user_id RETURNING id',[uid(r)])).rows[0];await c.query('INSERT INTO watchlist_assets(watchlist_id,asset_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[w.id,a.id]);await audit(c,uid(r),'WATCHLIST_UPDATED','Watchlist',w.id,r.locals.requestId);});r.status(201).json(a);});
app.delete('/v1/watchlist/:symbol',async(q,r)=>{await transaction(async c=>{await ensure(c,uid(r));await c.query('DELETE FROM watchlist_assets wa USING watchlists w,assets a WHERE wa.watchlist_id=w.id AND wa.asset_id=a.id AND w.user_id=$1 AND a.symbol=$2',[uid(r),symbol.parse(q.params.symbol)]);await audit(c,uid(r),'WATCHLIST_UPDATED','User',uid(r),r.locals.requestId);});r.status(204).end();});
// Route is absent in production and absent on any non-test database.
if(testMarketEnabled())app.put('/v1/market/test-scenario',async(q,r)=>{const d=z.object({symbol,scenario:z.enum(['unchanged','up','down','stale','delayed','unavailable'])}).strict().parse(q.body),a=await provider(uid(r)).getAssetProfile(d.symbol);await pool.query('INSERT INTO paper_market_controls(user_id,asset_id,scenario) VALUES($1,$2,$3) ON CONFLICT(user_id,asset_id) DO UPDATE SET scenario=$3,updated_at=now()',[uid(r),a.id,d.scenario]);r.json({mode:'PAPER',...d});});
finish(app);if(process.env.NODE_ENV!=='test')app.listen(Number(process.env.PORTFOLIO_PORT??3006));export {app};
