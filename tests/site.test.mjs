import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { buildServer } from '../src/server.mjs';
import project from '../project.json' with { type: 'json' };

let server, base;
test('site server', async t => {
  server=buildServer(); await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  base=`http://127.0.0.1:${server.address().port}`;
  t.after(()=>new Promise(resolve=>server.close(resolve)));
  const request=(path='/',headers={})=>new Promise((resolve,reject)=>{const req=http.request(new URL(path,base),{headers:{Host:project.hostname,'X-Forwarded-Proto':'https',...headers}},res=>{const chunks=[];res.on('data',c=>chunks.push(c));res.on('end',()=>resolve({status:res.statusCode,headers:new Map(Object.entries(res.headers)),text:async()=>Buffer.concat(chunks).toString()}));});req.on('error',reject);req.end();});
  await t.test('serves unique identity health without runtime details',async()=>{const r=await request('/healthz');assert.equal(r.status,200);assert.equal(await r.text(),`${project.id}-ready`);});
  await t.test('serves portal with security headers and identity',async()=>{const r=await request('/');const body=await r.text();assert.equal(r.status,200);assert.match(body,new RegExp(project.id,'i'));assert.equal(r.headers.get('x-content-type-options'),'nosniff');assert.match(r.headers.get('content-security-policy'),/frame-ancestors 'none'/);assert.equal(r.headers.get('strict-transport-security'),'max-age=604800');});
  await t.test('redirects HTTP to same-host HTTPS once',async()=>{const r=await request('/architecture.html?view=full',{'X-Forwarded-Proto':'http','redirect':'manual'});assert.equal(r.status,308);assert.equal(r.headers.get('location'),`https://${project.hostname}/architecture.html?view=full`);});
  await t.test('rejects unknown hosts and methods',async()=>{assert.equal((await request('/',{Host:'unapproved.example'})).status,421);const res=await new Promise((resolve,reject)=>{const req=http.request(base,{method:'POST',headers:{Host:project.hostname,'X-Forwarded-Proto':'https'}},r=>{r.resume();r.on('end',()=>resolve(r));});req.on('error',reject);req.end();});assert.equal(res.statusCode,405);});
  await t.test('returns the branded 404 document with a real 404 status',async()=>{const r=await request('/missing.html');assert.equal(r.status,404);assert.match(await r.text(),/404/);});
  await t.test('rejects traversal and does not disclose project metadata',async()=>{const r=await request('/..%2fproject.json');assert.equal(r.status,400);assert.doesNotMatch(await r.text(),/health_identity|hostname/);});
  await t.test('HEAD omits body while retaining identity headers',async()=>{const r=await new Promise((resolve,reject)=>{const req=http.request(new URL('/healthz',base),{method:'HEAD',headers:{Host:project.hostname,'X-Forwarded-Proto':'https'}},res=>{const chunks=[];res.on('data',c=>chunks.push(c));res.on('end',()=>resolve({status:res.statusCode,headers:new Map(Object.entries(res.headers)),body:Buffer.concat(chunks)}));});req.on('error',reject);req.end();});assert.equal(r.status,200);assert.equal(r.body.length,0);assert.equal(r.headers.get('strict-transport-security'),'max-age=604800');});
});
