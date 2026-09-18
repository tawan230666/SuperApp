import {useEffect,useState} from 'react';
import {api} from './auth';
import {money} from './PortfolioPage';
const modes=['ASK_FINANCIAL_QUESTION','PORTFOLIO_REVIEW','RISK_REVIEW','TRADING_REVIEW','PROFIT_REVIEW','DAILY_SUMMARY'] as const;
type Decision={copilotMode?:string;confidence?:number;freshness?:Record<string,{status:string;dataAsOf:string|null;note:string;source:string}>;id:string;provider:string;intent:string;summary:string;observedAt:string;executionAuthorized:false;facts:{label:string;value:string|null;unit:string;source:string}[];warnings:string[];proposals:{kind:string;message:string}[]};
type History={id:string;proposal:Decision;created_at:string};
export function AssistantPage(){
 const [mode,setMode]=useState<string>('ASK_FINANCIAL_QUESTION');
 const [question,setQuestion]=useState(''),[busy,setBusy]=useState(false),[error,setError]=useState(''),[result,setResult]=useState<Decision|null>(null),[history,setHistory]=useState<History[]>([]);
 async function load(){setHistory(await api<History[]>('/copilot/decisions'));}
 useEffect(()=>{load().catch(e=>setError(e.message));},[]);
 async function send(){setBusy(true);setError('');try{const d=await api<Decision>('/copilot/query',{method:'POST',body:JSON.stringify({question,copilotMode:mode})});setResult(d);setQuestion('');await load();}catch(e){setError((e as Error).message);}finally{setBusy(false);}}
 return <section><header className="page-title"><div><span className="eyebrow">READ / ANALYZE / PROPOSE ONLY</span><h1>Financial Copilot</h1><p>Mock Copilot ภายในเครื่อง · ไม่ใช้ external AI API</p></div></header>
 <section className="panel"><p>อ่านข้อมูล Portfolio, Bot, Risk Plan และ Ledger จาก server · ราคาสังเคราะห์ Paper เท่านั้น</p><p>Risk Engine เป็น authority · AI ไม่มีสิทธิ์ส่งคำสั่งซื้อขายหรือแก้ข้อมูลทางการเงิน</p>
 <label>Copilot mode<select aria-label="Copilot mode" value={mode} onChange={e=>setMode(e.target.value)}>{modes.map(m=><option key={m}>{m}</option>)}</select></label><p>AI อาจผิดพลาดได้ · Confidence ยังไม่ผ่านการสอบเทียบ ไม่ใช่โอกาสได้กำไร</p><button type="button" onClick={()=>setQuestion('สรุปสถานะการลงทุนของฉัน')}>สรุปสถานะการลงทุนของฉัน</button>
 <form onSubmit={e=>{e.preventDefault();if(question.trim()&&!busy)void send();}}><label>ถาม Copilot<textarea aria-label="ถาม Copilot" maxLength={2000} value={question} onChange={e=>setQuestion(e.target.value)} placeholder="สรุป Portfolio และความเสี่ยง" rows={3}/></label><button className="button primary" disabled={busy||!question.trim()}>{busy?'กำลังวิเคราะห์…':'วิเคราะห์'}</button></form>
 {error&&<p role="alert">{error} <button onClick={()=>{setError('');load().catch(e=>setError(e.message));}}>ลองโหลดประวัติใหม่</button></p>}
 </section>
 {result&&<section className="panel" aria-label="Copilot analysis"><h2>{result.intent==='REFUSED_EXECUTION'?'ไม่สามารถทำ execution ผ่าน AI':'ผลวิเคราะห์'}</h2><p>{result.summary}</p><small>{result.provider} · ข้อมูล ณ {result.observedAt}</small>
 <p>Mode: {result.copilotMode??'Legacy summary'} · Confidence: {result.confidence??0} (uncalibrated)</p>{result.freshness&&<ul aria-label="Data freshness">{Object.entries(result.freshness).map(([k,m])=><li key={k}>{k}: {m.status} · {m.source} · {m.dataAsOf??'ไม่มีเวลาอัปเดตต้นทาง'} · {m.note}</li>)}</ul>}
 <dl>{result.facts.map(f=><div key={f.source}><dt>{f.label}</dt><dd><span>{f.value===null?'ข้อมูลไม่เพียงพอ':f.unit==='THB minor'?money(f.value):f.value}</span><small>แหล่งข้อมูล: {f.source}</small></dd></div>)}</dl>
 <h3>ข้อจำกัดข้อมูล</h3><ul>{result.warnings.map(w=><li key={w}>{w}</li>)}</ul>
 <h3>ข้อเสนอเพื่อพิจารณา</h3>{result.proposals.length?<ul>{result.proposals.map((p,i)=><li key={i}>{p.message}</li>)}</ul>:<p>ไม่มีข้อเสนอเพิ่มเติมจากกฎที่รองรับ</p>}
 </section>}
 <section className="panel"><h2>ประวัติการวิเคราะห์</h2>{history.length===0?<p>ยังไม่มีการวิเคราะห์ที่บันทึกไว้</p>:history.map(h=><p key={h.id}><button onClick={()=>setResult({...h.proposal,id:h.id})}>{h.proposal.summary}</button><small>{h.created_at}</small></p>)}</section>
 </section>;
}
