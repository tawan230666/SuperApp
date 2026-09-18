import type {PoolClient} from '@tipkhun/database';
import {snapshot} from './index.js';

/** Execution-only entry point. Caller holds the existing owner lock through reservation. */
export async function authorizeBroker(c:PoolClient,user:string,proposedRisk:bigint){
 const s=await snapshot(c,user,true);
 let reason:string|null=null;
 if(s.emergencyStop)reason='EMERGENCY_STOP';
 else if(s.reconciliationRequired)reason='RECONCILIATION_REQUIRED';
 else if(BigInt(s.riskUsedMinor)>=BigInt(s.dailyLossLimitMinor))reason='DAILY_LOSS_EXCEEDED';
 else if(s.drawdownReached)reason='MAX_DRAWDOWN';
 else if(s.tradesRemaining<=0)reason='MAX_TRADES_EXCEEDED';
 else if(proposedRisk>BigInt(s.riskPerTradeMinor))reason='PER_TRADE_RISK_EXCEEDED';
 else if(proposedRisk>BigInt(s.riskRemainingMinor))reason='RISK_BUDGET_EXCEEDED';
 else if(proposedRisk>0n&&s.positionsUsed>=s.maxPositions)reason='MAX_POSITIONS_EXCEEDED';
 return {approved:reason===null,reason,planVersionId:String(s.versionId),riskRemainingMinor:String(s.riskRemainingMinor)};
}
/** Revalidate the already-reserved order immediately before a broker call. */
export async function validateBrokerDispatch(c:PoolClient,user:string,reserved:bigint,planVersionId:string){
 const s=await snapshot(c,user,true);
 return !s.emergencyStop&&!s.reconciliationRequired&&!s.drawdownReached&&s.versionId===planVersionId&&
  BigInt(s.riskUsedMinor)<BigInt(s.dailyLossLimitMinor)&&reserved<=BigInt(s.riskPerTradeMinor)&&
  BigInt(s.riskUsedMinor)+BigInt(s.riskReservedMinor)<=BigInt(s.dailyLossLimitMinor)&&
  BigInt(s.riskUsedMinor)+BigInt(s.riskReservedMinor)<=BigInt(s.equityMinor)&&
  s.tradesUsed<=s.maxTrades&&s.positionsUsed<=s.maxPositions;
}
