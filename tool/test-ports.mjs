import net from 'node:net';
/** Refuse collisions instead of terminating processes that may belong to the user. */
export async function requireFreePorts(ports){
 await Promise.all(ports.map(port=>new Promise((resolve,reject)=>{
  const server=net.createServer();
  server.once('error',()=>reject(new Error(`Test port ${port} is occupied; no existing process was stopped`)));
  server.listen(port,'127.0.0.1',()=>server.close(error=>error?reject(error):resolve()));
 })));
}
