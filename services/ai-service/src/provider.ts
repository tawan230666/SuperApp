import type {FinancialContext} from './store.js';
import type {CopilotMode} from './output.js';
/** No imports of database clients, network clients, Risk or Execution. No dynamic tool dispatch. */
export const capabilities=Object.freeze({read:true,analyze:true,propose:true,execute:false,overrideRisk:false,provider:'mock-local',tools:[]});
export function analyze(question:string,c:FinancialContext,copilotMode:CopilotMode='ASK_FINANCIAL_QUESTION'){
 const refused=/(buy|sell|execute|order|reconcil|snapshot|allocate|override|ignore|risk.*(change|edit)|close|fund|ปิด|เปลี่ยน|ย้ายเงิน|ส่ง order|ซื้อ|ขาย|ส่งคำสั่ง|จัดสรร|แก้.*(แผน|ความเสี่ยง|บัญชี)|ข้าม.*กฎ)/i.test(question);
 const warnings=['ราคาทั้งหมดเป็น synthetic fixture / Paper ไม่ใช่ราคาตลาดจริง','AI = READ / ANALYZE / PROPOSE ONLY; Risk Engine เป็น authority; ไม่มีสิทธิ์ execution','สถานะ reconciliation เป็นค่าที่บันทึกไว้ ไม่ได้ตรวจหรือ reconcile ใหม่'];
 for(const [category,m] of Object.entries(c.freshness)){warnings.push(`${category}: ${m.status}; ${m.note}`);}
 if(!c.plan)warnings.push('ยังไม่มี Risk Plan จึงประเมินข้อจำกัดตามแผนไม่ได้');
 if(c.portfolioError)warnings.push(`Portfolio valuation unavailable: ${c.portfolioError}`);
 if(c.portfolio?.reconciliationStatus==='RECONCILIATION_REQUIRED'||c.bot.brokerStatus==='RECONCILIATION_REQUIRED')warnings.push('มี reconciliation latch: ให้ผู้ใช้ตรวจสอบผ่าน operation ที่ได้รับอนุญาต');
 let facts=[{label:'Portfolio total',value:c.portfolio?.totalValueMinor??null,unit:'THB minor',source:'/portfolio.totalValueMinor'},
 {label:'Portfolio unrealized P&L',value:c.portfolio?.unrealizedPnlMinor??null,unit:'THB minor',source:'/portfolio.unrealizedPnlMinor'},
 {label:'Bot status',value:c.bot.state,unit:'status',source:'/bot.state'},
 {label:'Risk per trade (plan limit)',value:c.plan?.risk_per_trade_minor??null,unit:'THB minor',source:'/plan.risk_per_trade_minor'}];
 if(c.trading){facts.push({label:'Closed trades (persisted total)',value:String(c.trading.totalTrades),unit:'count',source:'/trading.totalTrades'},{label:'Realized trading P&L',value:c.trading.netPnlMinor,unit:'THB minor',source:'/trading.netPnlMinor'});}
 if(c.profit)facts.push({label:'Allocated profit',value:c.profit.totalMinor,unit:'THB minor',source:'/profit.totalMinor'});
 let proposals=[...(c.portfolio?.risk.warnings??[]).map(message=>({kind:'REVIEW_CONCENTRATION',message})),
 ...(c.portfolio?.targets.filter(t=>Math.abs(t.differenceBps)>1000).map(t=>({kind:'REVIEW_TARGET',message:`${t.target}: deviation ${t.differenceBps} bps; review manually`}))??[])];
 const modeSources:Record<CopilotMode,string[]>={PORTFOLIO_REVIEW:['/portfolio'],RISK_REVIEW:['/plan','/bot'],TRADING_REVIEW:['/trading','/bot'],PROFIT_REVIEW:['/profit'],DAILY_SUMMARY:['/'],ASK_FINANCIAL_QUESTION:['/']};
 facts=facts.filter(f=>modeSources[copilotMode].some(prefix=>f.source.startsWith(prefix)));
 const includesPortfolio=['PORTFOLIO_REVIEW','DAILY_SUMMARY','ASK_FINANCIAL_QUESTION'].includes(copilotMode);
 if(!includesPortfolio)proposals=[];
 if(copilotMode==='RISK_REVIEW'&&c.plan)proposals.push({kind:'REVIEW_RISK_LIMITS',message:`Configured per-trade limit ${c.plan.risk_per_trade_minor} minor THB; consult Risk Engine for current available budget. This review is not authorization.`});
 if(copilotMode==='TRADING_REVIEW'&&c.trading.totalTrades!=='0')proposals.push({kind:'REVIEW_TRADE_HISTORY',message:`Review ${c.trading.totalTrades} persisted closed trades with total net P&L ${c.trading.netPnlMinor} minor THB; past performance is not a forecast.`});
 if(copilotMode==='PROFIT_REVIEW'&&c.profit.totalMinor!=='0')proposals.push({kind:'REVIEW_ALLOCATIONS',message:`Recorded allocations total ${c.profit.totalMinor} minor THB; review destination ledger balances before any manual operation.`});
 const summaries:Record<CopilotMode,string>={PORTFOLIO_REVIEW:'ทบทวนมูลค่าและการกระจุกตัวของ Portfolio',RISK_REVIEW:'ทบทวนข้อจำกัด Risk Plan และสถานะ Bot',TRADING_REVIEW:'ทบทวนประวัติเทรดที่บันทึกและสถานะ Bot',PROFIT_REVIEW:'ทบทวนกำไรที่จัดสรรแล้วจากฐานข้อมูล',DAILY_SUMMARY:'สรุปสถานะล่าสุด ณ วันนี้ พร้อมประวัติสะสม ไม่ใช่ผลตอบแทนเฉพาะวัน',ASK_FINANCIAL_QUESTION:'สรุปจากข้อมูล server ณ เวลาที่อ่าน โดย Mock Copilot ภายในเครื่อง'};
 return {freshness:c.freshness,copilotMode,dataAsOf:c.observedAt,observations:facts,risks:includesPortfolio?c.portfolio?.risk.warnings??[]:[],opportunities:[] as string[],recommendations:proposals,confidence:0 as number,provider:'mock-local',model:'deterministic-rules-v1',mode:'PAPER',intent:refused?'REFUSED_EXECUTION':'ANALYSIS',
 summary:refused?'คำขอนี้ไม่สามารถเปลี่ยนข้อมูลทางการเงินหรือสั่ง execution ผ่าน AI ได้':summaries[copilotMode],
 observedAt:c.observedAt,capabilities,facts,warnings,proposals,executionAuthorized:false,riskCheck:null};
}


/** Future production adapters must implement this data-only interface; none is enabled. */
export interface AIProvider {
 readonly id:string;
 readonly model:string;
 generate(question:string,context:FinancialContext,mode:CopilotMode):Promise<unknown>;
 health():Promise<{available:boolean}>;
}
export class DeterministicAIProvider implements AIProvider {
 readonly id='mock-local';readonly model='deterministic-rules-v1';
 async generate(question:string,context:FinancialContext,mode:CopilotMode):Promise<unknown>{return analyze(question,context,mode);}
 async health(){return {available:true};}
}
/** Explicit local/test failure fixtures, never configured from client text or metadata. */
export class MockAIProvider extends DeterministicAIProvider {
 constructor(private readonly scenario:'valid'|'malformed'|'missing'|'timeout'|'unavailable'='valid'){super();}
 override async health(){return {available:this.scenario!=='unavailable'};}
 override async generate(question:string,context:FinancialContext,mode:CopilotMode):Promise<unknown>{
  if(this.scenario==='unavailable')throw new Error('AI_PROVIDER_UNAVAILABLE');
  if(this.scenario==='timeout')return new Promise(()=>{});
  if(this.scenario==='malformed')return 'not structured output';
  if(this.scenario==='missing')return {summary:'incomplete'};
  return super.generate(question,context,mode);
 }
}
