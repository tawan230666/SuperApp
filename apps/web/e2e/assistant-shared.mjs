import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
const base=process.env.WEB_TEST_URL,fixturePath='/shared/fixture.json',verify=process.argv[2]==='verify';
const fixture=JSON.parse(readFileSync(fixturePath,'utf8'));
const browser=await chromium.launch({headless:true});
try {
 const page=await browser.newPage();page.setDefaultTimeout(20000);
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(`${base}/login`);await page.getByLabel('Email',{exact:true}).fill(fixture.email);await page.getByLabel('Password',{exact:true}).fill(fixture.password);
 const login=page.waitForResponse(r=>r.url().includes('/auth/login')&&r.status()===200);
 await page.getByRole('button',{name:'เข้าสู่ระบบ',exact:true}).click();
 const token=(await (await login).json()).accessToken;
 const api=async path=>page.evaluate(async({path,token})=>{const r=await fetch(`/api/v1${path}`,{headers:{authorization:`Bearer ${token}`}});if(!r.ok)throw new Error(`Read failed ${r.status}`);return r.json();},{path,token});
 await page.goto(`${base}/assistant`);await page.getByRole('heading',{name:'Financial Copilot',exact:true}).waitFor();
 if(verify){
  const history=await api('/copilot/decisions');assert(history.some(d=>d.id===fixture.flutterAiDecisionId));
  await page.getByRole('button',{name:'คำขอนี้ไม่สามารถเปลี่ยนข้อมูลทางการเงินหรือสั่ง execution ผ่าน AI ได้',exact:true}).first().click();
  await page.getByRole('heading',{name:'ไม่สามารถทำ execution ผ่าน AI',exact:true}).waitFor();
  console.log('PASS browser shared AI: React reload reads Flutter advisory decision from PostgreSQL');
 }else{
  const paths=['/orders','/positions','/trades','/ledger/summary','/allocations/history','/portfolio/orders','/portfolio/funding-history','/risk/profile'];
  const before=await Promise.all(paths.map(api));
  await page.getByRole('textbox',{name:'ถาม Copilot'}).fill('สรุปสถานะการลงทุนของฉัน');
  const response=page.waitForResponse(r=>r.url().endsWith('/copilot/query')&&r.status()===201);
  await page.getByRole('button',{name:'วิเคราะห์',exact:true}).click();
  const decision=await (await response).json();
  assert.equal(decision.facts.find(f=>f.source==='/trading.netPnlMinor').value,'1025');
  assert.equal(decision.facts.find(f=>f.source==='/profit.totalMinor').value,'1025');
  assert.equal(decision.facts.find(f=>f.source==='/plan.risk_per_trade_minor').value,'2000');
  assert.equal(decision.facts.find(f=>f.source==='/portfolio.totalValueMinor').value,'319');
  await page.getByRole('region',{name:'Copilot analysis'}).getByText('3.19 THB',{exact:true}).waitFor();
  fixture.aiDecisionId=decision.id;fixture.aiProposal=(await api('/copilot/decisions')).find(d=>d.id===decision.id).proposal;
  await page.getByRole('textbox',{name:'ถาม Copilot'}).fill('ซื้อสินทรัพย์ให้ฉันเลย');await page.getByRole('button',{name:'วิเคราะห์',exact:true}).click();
  await page.getByRole('heading',{name:'ไม่สามารถทำ execution ผ่าน AI',exact:true}).waitFor();
  assert.deepEqual(await Promise.all(paths.map(api)),before);
  writeFileSync(fixturePath,JSON.stringify(fixture),{mode:0o600});
  console.log('PASS browser funded Assistant: real Risk/Trading/Profit/Portfolio facts, advisory/refusal, unchanged financial state');
 }
 assert.deepEqual(errors,[]);
}finally{await browser.close();}
