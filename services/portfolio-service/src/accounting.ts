import {HttpError} from '@tipkhun/auth';
export const SCALE=1000000n;
export function quantity(value:string):bigint {if(!/^\d{1,12}(\.\d{1,6})?$/.test(value))throw new HttpError(400,'Invalid quantity');const [whole,fraction='']=value.split('.');const n=BigInt(whole)*SCALE+BigInt(fraction.padEnd(6,'0'));if(n<=0n)throw new HttpError(400,'Invalid quantity');return n;}
export function decimal(n:bigint){return `${n/SCALE}.${(n%SCALE).toString().padStart(6,'0')}`;}
export const fee=(amount:bigint)=>(amount*10n+9999n)/10000n;
export const basisSold=(cost:bigint,held:bigint,sold:bigint)=>{if(sold>held)throw new HttpError(409,'INSUFFICIENT_HOLDINGS');return sold===held?cost:cost*sold/held;};
export const bps=(part:bigint,total:bigint)=>total>0n?Number(part*10000n/total):0;
