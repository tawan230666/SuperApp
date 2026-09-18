import assert from 'node:assert/strict';
let access='';const email=`api-${Date.now()}@example.test`,password='API-test-password-123';
async function call(path,method='GET',data,expected=200){const r=await fetch(`http://localhost:3000/api/v1${path}`,{method,headers:{'content-type':'application/json',...(access?{authorization:`Bearer ${access}`}:{})},body:data?JSON.stringify(data):undefined});assert.equal(r.status,expected,`${method} ${path}`);return expected===204?null:r.json();}
await call('/auth/register','POST',{email,password},201);const login=await call('/auth/login','POST',{email,password});access=login.accessToken;
const user=await call('/me');assert.equal(user.email,email);
await call('/risk/profile','PUT',{riskTolerance:500,dailyLossLimit:'1750',riskPerTrade:'500',maxTrades:3,maxPositions:2,maxDrawdown:1000});
await call('/plans','POST',{capitalMinor:'35000',dailyLossLimitMinor:'1750',riskPerTradeMinor:'500',maxTrades:3},201);
assert.equal((await call('/plans/current')).version,1);assert.equal((await call('/risk/status')).riskRemainingMinor,'1750');assert.equal((await call('/risk/check','POST',{proposedRiskMinor:'100'})).approved,true);
const rotated=await call('/auth/refresh','POST',{refreshToken:login.refreshToken});access=rotated.accessToken;
await call('/auth/logout','POST',{},204);await call('/me','GET',undefined,401);await call('/auth/refresh','POST',{refreshToken:rotated.refreshToken},401);
console.log('PASS: real HTTP register → login → me → profile → plan → current → status → risk → refresh → logout → revoked access/refresh');
