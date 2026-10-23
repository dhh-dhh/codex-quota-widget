'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {normalizeUserInfo,read}=require('./providers/traffic.cjs');
test('subscription bytes produce remaining GB and percentage without confusing expiration with reset',()=>{
 const row=normalizeUserInfo('upload=1073741824; download=1610612736; total=107374182400; expire=1823875200')[0];
 assert.equal(row.displayValue,'97.5 GB');
 assert.equal(row.remaining,97.5);
 assert.equal(row.resetsAt,null);
 assert.match(row.detail,/2.5 \/ 100 GB/);
});
test('zero and exhausted traffic are valid, but malformed or missing counters are not zero',()=>{
 assert.equal(normalizeUserInfo('upload=0;download=0;total=1024')[0].remaining,100);
 assert.equal(normalizeUserInfo('upload=1024;download=1024;total=1024')[0].remaining,0);
 for(const header of ['', 'upload=0;download=0', 'upload=-1;download=0;total=100', 'upload=0;download=oops;total=100', 'upload=0;download=0;total=0']){
  assert.throws(()=>normalizeUserInfo(header));
 }
});
test('subscription request uses provided abort signal, reads only metadata and does not follow redirects',async()=>{
 const signal=new AbortController().signal;
 let cancelled=false;
 const rows=await read({options:{url:'https://w1.soxo.top/link/test-fixture'},signal,fetchImpl:async(url,init)=>{
  assert.equal(url,'https://w1.soxo.top/link/test-fixture');
  assert.equal(init.signal,signal);assert.equal(init.redirect,'manual');
  return {ok:true,headers:new Headers({'subscription-userinfo':'upload=0;download=0;total=1073741824'}),body:{cancel:async()=>{cancelled=true}}};
 }});
 assert.equal(rows[0].displayValue,'1 GB');assert.equal(cancelled,true);
});
test('failed requests never disclose the private subscription URL',async()=>{
 await assert.rejects(read({options:{url:'https://w1.soxo.top/link/SECRET'},fetchImpl:async()=>{throw Error('https://w1.soxo.top/link/SECRET')}}),e=>!e.message.includes('SECRET'));
 await assert.rejects(read({options:{url:'http://w1.soxo.top/link/SECRET'}}),/HTTPS/);
});
