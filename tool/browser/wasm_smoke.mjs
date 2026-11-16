import {chromium} from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import assert from 'node:assert/strict';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const root=fileURLToPath(new URL('../../',import.meta.url));
const dir=process.env.PDFIUM_ASSETS || path.join(root,'build/web/assets/packages/pdfrx/assets');
const server=http.createServer((req,res)=>{
 if(req.url==='/') {
   res.setHeader('Content-Type','text/html');
   res.end('<!doctype html><meta http-equiv="Content-Security-Policy" content="default-src \'self\'; script-src \'self\' blob: \'wasm-unsafe-eval\'; worker-src \'self\' blob:; connect-src \'self\' blob:"><title>Backend test</title>');
 } else if(['/pdfium_worker.js','/pdfium.wasm'].includes(req.url)) {
   res.setHeader('Content-Type',req.url.endsWith('.wasm')?'application/wasm':'text/javascript');
   fs.createReadStream(dir+req.url).pipe(res);
 } else {res.writeHead(404).end();}
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const origin=`http://127.0.0.1:${server.address().port}`;
let browser;
try {
 browser=await chromium.launch({executablePath:process.env.CHROME_EXECUTABLE || '/usr/bin/chromium',headless:true,args:['--no-sandbox']});
 const context=await browser.newContext();
 const page=await context.newPage();
 const requests=[]; page.on('request',r=>requests.push({method:r.method(),url:r.url()}));
 await page.goto(origin);
 const fixtures={};for(const n of ['valid','rotated','arabic','encrypted','empty-password','malformed']) fixtures[n]=fs.readFileSync(path.join(root,`test/fixtures/${n}.pdf`)).toString('base64');
 await page.evaluate(async()=>{
   const blob=new Blob([`const pdfiumWasmUrl='${location.origin}/pdfium.wasm';importScripts('${location.origin}/pdfium_worker.js');`],{type:'text/javascript'});
   const worker=new Worker(URL.createObjectURL(blob));
   let seq=0;const pending=new Map();
   worker.onmessage=e=>{const d=e.data;if(!d.id)return;const p=pending.get(d.id);pending.delete(d.id);if(d.status==='success')p.resolve(d.result);else p.reject(new Error(d.error));};
   globalThis.command=(command,parameters={})=>new Promise((resolve,reject)=>{const id=++seq;pending.set(id,{resolve,reject});worker.postMessage({id,command,parameters});});
   await globalThis.command('init');
 });
 await context.setOffline(true);
 const results=await page.evaluate(async fixtures=>{
   const check=(condition,label)=>{if(!condition)throw new Error(label);results.push(label);};
   const results=[];const cmd=globalThis.command;
   let id=0;
   const open=async name=>cmd('loadDocumentFromData',{data:Uint8Array.from(atob(fixtures[name]),c=>c.charCodeAt(0)).buffer,url:`fixture:${id++}`});
   const roundtrip=async(refs)=>{
     const dest=await cmd('createNewDocument');
     const imports={};refs.forEach((r,i)=>imports[-i-1]={docHandle:r.doc.docHandle,pageNumber:r.page});
     await cmd('assemble',{docHandle:dest.docHandle,pageIndices:refs.map((_,i)=>-i-1),importedPages:imports,rotations:refs.map(r=>r.rotation??null)});
     const bytes=await cmd('encodePdf',{docHandle:dest.docHandle});
     const verified=await cmd('loadDocumentFromData',{data:bytes.data,url:`output:${id++}`});
     return verified;
   };
   const a=await open('valid'),b=await open('valid');
   check(a.pages.length===3&&b.pages.length===3,'import valid PDFs');
   let out=await roundtrip([0,1,2].map(page=>({doc:a,page})).concat([0,1,2].map(page=>({doc:b,page}))));
   check(JSON.stringify(out.pages.map(p=>p.width))==='[200,300,400,200,300,400]','merge round trip');
   out=await roundtrip([{doc:a,page:1}]);check(out.pages.length===1&&out.pages[0].width===300,'split/extract round trip');
   const r=await open('rotated');out=await roundtrip([{doc:r,page:2,rotation:1},{doc:r,page:0,rotation:2}]);
   check(out.pages.length===2&&out.pages[0].height===400&&out.pages[1].width===200&&out.pages[0].rotation===1&&out.pages[1].rotation===2,'reorder and additive rotation round trip');
   const arabic=await open('arabic');out=await roundtrip([{doc:arabic,page:0,rotation:1}]);
   const text=await cmd('loadText',{docHandle:out.docHandle,pageIndex:0});
   check(/[\u0600-\u06ff\ufb50-\ufdff\ufe70-\ufeff]/.test(text.fullText),'Arabic embedded text preservation');
   check((await open('encrypted')).errorCode===4,'password-protected input rejected');
   const empty=await open('empty-password');check(empty.securityHandlerRevision>=0,'empty-password encryption detected');
   check((await open('malformed')).errorCode===3,'malformed PDF rejected');
   return results;
 },fixtures);
 assert(requests.every(r=>r.method==='GET'&&(r.url.startsWith(origin)||r.url.startsWith('blob:'+origin))));
 const report={scope:'Direct PDFium WASM backend; Flutter application not exercised',backend:'pdfrx 2.12.1 bundled PDFium WASM',wasmSha256:createHash('sha256').update(fs.readFileSync(path.join(dir,'pdfium.wasm'))).digest('hex'),browser:await browser.version(),offline:true,passed:results,noDocumentHttpRequests:true};
 console.log(JSON.stringify(report,null,2));
 if(process.env.PDF_BACKEND_REPORT) fs.writeFileSync(process.env.PDF_BACKEND_REPORT,JSON.stringify(report,null,2)+'\n');
} finally {await browser?.close();server.close();}
