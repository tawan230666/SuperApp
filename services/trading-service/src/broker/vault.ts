import {createCipheriv,createDecipheriv,randomBytes} from 'node:crypto';
import type {PoolClient} from '@tipkhun/database';
import {BrokerError} from './domain.js';

/** Secret values never appear in connection DTOs. A vault/HSM can replace this adapter. */
export interface CredentialVault {
 put(c:PoolClient,reference:string,connection:string,owner:string,secret:string):Promise<void>;
 read(c:PoolClient,reference:string,connection:string,owner:string):Promise<string>;
 revoke(c:PoolClient,reference:string,owner:string):Promise<void>;
}
export class EncryptedCredentialVault implements CredentialVault {
 constructor(private readonly key:Buffer,private readonly keyId='sandbox-v1'){
  if(key.length!==32)throw new BrokerError('BROKER_VAULT_UNAVAILABLE');
 }
 async put(c:PoolClient,reference:string,connection:string,owner:string,secret:string){
  if(!secret.startsWith('sandbox-only:'))throw new BrokerError('SANDBOX_CREDENTIAL_REQUIRED');
  const nonce=randomBytes(12),cipher=createCipheriv('aes-256-gcm',this.key,nonce);
  cipher.setAAD(Buffer.from(`${this.keyId}:${reference}:${connection}:${owner}`));
  const ciphertext=Buffer.concat([cipher.update(secret,'utf8'),cipher.final()]);
  await c.query('INSERT INTO broker_credentials(id,connection_id,user_id,key_id,ciphertext,nonce,tag) VALUES($1,$2,$3,$4,$5,$6,$7)',[reference,connection,owner,this.keyId,ciphertext.toString('base64'),nonce.toString('base64'),cipher.getAuthTag().toString('base64')]);
 }
 async read(c:PoolClient,reference:string,connection:string,owner:string){
  const row=(await c.query<{key_id:string;ciphertext:string;nonce:string;tag:string}>('SELECT key_id,ciphertext,nonce,tag FROM broker_credentials WHERE id=$1 AND connection_id=$2 AND user_id=$3 AND revoked_at IS NULL',[reference,connection,owner])).rows[0];
  if(!row||row.key_id!==this.keyId)throw new BrokerError('BROKER_CREDENTIAL_UNAVAILABLE');
  try{const cipher=createDecipheriv('aes-256-gcm',this.key,Buffer.from(row.nonce,'base64'));cipher.setAAD(Buffer.from(`${this.keyId}:${reference}:${connection}:${owner}`));cipher.setAuthTag(Buffer.from(row.tag,'base64'));return Buffer.concat([cipher.update(Buffer.from(row.ciphertext,'base64')),cipher.final()]).toString('utf8');}
  catch{throw new BrokerError('BROKER_CREDENTIAL_UNAVAILABLE');}
 }
 async revoke(c:PoolClient,reference:string,owner:string){await c.query('UPDATE broker_credentials SET revoked_at=coalesce(revoked_at,now()) WHERE id=$1 AND user_id=$2',[reference,owner]);}
}
