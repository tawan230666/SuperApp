import type {AIProvider} from './provider.js';
import type {FinancialContext} from './store.js';
import {outputSchema, type CopilotMode} from './output.js';

/** Only validated data leaves this boundary; failures never produce a decision. */
export async function generateProposal(provider:AIProvider, question:string, context:FinancialContext, mode:CopilotMode, timeoutMs=5000){
 let timer:ReturnType<typeof setTimeout>|undefined;
 try {
  return await Promise.race([
   (async()=>{
    if(!(await provider.health()).available)throw new Error('AI_PROVIDER_UNAVAILABLE');
    const parsed=outputSchema.safeParse(await provider.generate(question,context,mode));
    if(!parsed.success)throw new Error('AI_PROVIDER_INVALID_OUTPUT');
    if(parsed.data.provider!==provider.id||parsed.data.capabilities.provider!==provider.id||parsed.data.model!==provider.model||parsed.data.copilotMode!==mode||parsed.data.dataAsOf!==context.observedAt||parsed.data.observedAt!==context.observedAt)throw new Error('AI_PROVIDER_INVALID_OUTPUT');
    return parsed.data;
   })(),
   new Promise<never>((_resolve,reject)=>{timer=setTimeout(()=>reject(new Error('AI_PROVIDER_TIMEOUT')),timeoutMs);}),
  ]);
 } finally {if(timer)clearTimeout(timer);}
}
