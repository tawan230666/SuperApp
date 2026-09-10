import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
const base=process.env.WEB_TEST_URL,fixturePath='/shared/fixture.json',verify=process.argv[2]==='verify';
const browser=await chromium.launch({headless:true});
try{
 const page=await browser.newPage();page.setDefaultTimeout(20000);page.on('pageerror',e=>console.error('Browser error:',e.message));page.on('response',async r=>{if(r.url().includes('/api/')&&r.status()>=400)console.error('API failure:',new URL(r.url()).pathname,r.status());});
 const fixture=verify?JSON.parse(readFileSync(fixturePath,'utf8')):{email:`portfolio-browser-${Date.now()}@example.test`,password:'Portfolio-browser-password-1234'};
 await page.goto(`${base}/${verify?'login':'register'}`);
 await page.getByLabel('Email',{exact:true}).fill(fixture.email);await page.getByLabel('Password',{exact:true}).fill(fixture.password);
 if(!verify)await page.getByLabel('Confirm password',{exact:true}).fill(fixture.password);
 const login=page.waitForResponse(r=>r.url().includes('/auth/login')&&r.status()===200);
 await page.getByRole('button',{name:verify?'เข้าสู่ระบบ':'สมัครสมาชิก',exact:true}).click();
 const token=(await (await login).json()).accessToken;
 const api=async(method,path,body,key)=>page.evaluate(async({token,method,path,body,key})=>{const r=await fetch(`/api/v1${path}`,{method,headers:{'content-type':'application/json',authorization:`Bearer ${token}`,...(key?{'Idempotency-Key':key}:{})},body:body===undefined?undefined:JSON.stringify(body)});const result=await r.json();if(!r.ok)throw new Error(`${path}: ${r.status} ${result.error}`);return result;},{token,method,path,body,key});
 if(!verify){
  await page.getByText('สร้างแผนความเสี่ยงแรกของคุณ').waitFor();await page.goto(`${base}/risk`);
  for(const [label,value] of Object.entries({riskTolerance:'1000',dailyLossLimit:'5000',riskPerTrade:'2000',maxPositions:'10',maxDrawdown:'10000',capitalMinor:'100000',dailyLossLimitMinor:'5000',riskPerTradeMinor:'2000'}))await page.getByLabel(label,{exact:true}).fill(value);
  await page.getByRole('button',{name:'ดู Preview',exact:true}).click();await page.getByRole('button',{name:'ยืนยันบันทึก',exact:true}).click();await page.getByText('บันทึกแล้ว',{exact:true}).waitFor();
  await page.goto(`${base}/bot`);await page.getByRole('button',{name:'START',exact:true}).click();await page.getByText('RUNNING',{exact:true}).waitFor();
  await api('POST','/orders',{instrument:'SYNTHETIC-THB',type:'MARKET',quantity:'10',scenario:'profit101'},`browser-trade-${Date.now()}`);
  const position=(await api('GET','/positions'))[0];const closed=await api('POST',`/positions/${position.id}/close`,{});assert.equal(closed.net_pnl_minor,'1025');
  await page.goto(`${base}/profit-router`);await page.getByRole('button',{name:'PREVIEW',exact:true}).click();await page.getByRole('button',{name:'CONFIRM',exact:true}).click();await page.getByText('ยืนยันการจัดสรรแล้ว',{exact:true}).waitFor();
  fixture.allocationId=(await api('GET','/allocations/history'))[0].id;
  await page.goto(`${base}/long-term`);await page.getByRole('heading',{name:'Long-Term Portfolio',exact:true}).waitFor();await page.getByTestId('Long-Term Reserve Available').filter({hasText:'3.07 THB'}).waitFor();
  await page.getByLabel('Funding amount (minor units)').fill('300');await page.getByRole('button',{name:'Preview funding',exact:true}).click();await page.getByRole('button',{name:'Confirm funding',exact:true}).click();await page.getByText('Funded portfolio',{exact:true}).waitFor();
  await page.getByLabel('Quantity',{exact:true}).fill('10');await page.getByRole('button',{name:'Preview order',exact:true}).click();await page.getByLabel('Order preview').waitFor();
  assert.equal((await api('GET','/portfolio/holdings')).length,0);
  await page.getByRole('button',{name:'Confirm paper order',exact:true}).click();await page.getByText('Paper BUY filled',{exact:true}).waitFor();await page.getByTestId('holding-PTT').filter({hasText:'10.000000'}).waitFor();
  fixture.holdingId=(await api('GET','/portfolio/holdings'))[0].id;
  await api('PUT','/market/test-scenario',{symbol:'PTT',scenario:'up'});await page.reload();await page.getByTestId('Unrealized P&L').filter({hasText:'0.19 THB'}).waitFor();
  await page.getByRole('button',{name:'Save targets',exact:true}).click();await page.getByText('Targets saved',{exact:true}).waitFor();
  writeFileSync(fixturePath,JSON.stringify(fixture),{mode:0o600});
  console.log('PASS browser Phase 5: real profitable trade, allocation, fund, preview, BUY, valuation, targets; ready for Flutter');
 }else{
  await page.goto(`${base}/long-term`);await page.getByTestId('holding-PTT').filter({hasText:'6.000000'}).waitFor();await page.getByRole('button',{name:'Remove TDEX',exact:true}).waitFor();await page.getByTestId('Realized P&L').filter({hasText:'0.07 THB'}).waitFor();
  await page.getByLabel('Side',{exact:true}).selectOption('SELL');await page.getByLabel('Quantity',{exact:true}).fill('6');await page.getByRole('button',{name:'Preview order',exact:true}).click();await page.getByRole('button',{name:'Confirm paper order',exact:true}).click();await page.getByText('Paper SELL filled',{exact:true}).waitFor();await page.getByText('ยังไม่มีสินทรัพย์ใน Portfolio',{exact:true}).waitFor();
  await page.reload();await page.getByTestId('Realized P&L').filter({hasText:'0.17 THB'}).waitFor();
  await page.getByRole('button',{name:'Remove TDEX',exact:true}).click();await page.getByText('Watchlist ว่าง',{exact:true}).waitFor();
  await page.getByRole('button',{name:'Logout',exact:true}).click();await page.goto(`${base}/long-term`);await page.getByRole('heading',{name:'เข้าสู่ระบบ',exact:true}).waitFor();
  console.log('PASS browser Phase 5: React reload sees Flutter SELL and watchlist; React SELL, persisted P&L, logout protection');
 }
}finally{await browser.close();}
