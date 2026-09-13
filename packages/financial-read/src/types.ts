/** Dependency-injected read capability. Never expose this to the AI provider. */
export interface ReadQuery { query(sql:string,values?:any[]):Promise<{rows:any[];rowCount:number|null}> }
export class FinancialReadError extends Error { constructor(public status:number,message:string){super(message);} }
