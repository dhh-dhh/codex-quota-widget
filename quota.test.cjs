const {test}=require('node:test');
const assert=require('node:assert/strict');
const {collect,validateRows}=require('./read-quota.cjs');
const {normalize}=require('./providers/codex.cjs');
test('missing quota is unknown; zero and full consumption are preserved',()=>{
 const rows=normalize({rateLimitsByLimitId:{a:{primary:{usedPercent:null}},b:{primary:{usedPercent:0}},c:{secondary:{usedPercent:100}}}});
 assert.deepEqual(rows.map(r=>r.remaining),[null,100,0]);
});
test('multi bucket values take precedence over legacy value',()=>{
 assert.equal(normalize({rateLimits:{primary:{usedPercent:99}},rateLimitsByLimitId:{a:{primary:{usedPercent:20}}}})[0].remaining,80);
});
test('one failing provider does not hide another provider',async()=>{
 const r=await collect({providers:[{id:'a'},{id:'b'}]}, {},{a:{read:async()=>[{name:'余额',remaining:null,displayValue:'12 CNY'}]},b:{read:async()=>{throw Error('offline')}}});
 assert.equal(r.ok,true);assert.equal(r.rows[0].displayValue,'12 CNY');assert.equal(r.errors.length,1);
});
test('disabled providers never run',async()=>{
 const r=await collect({providers:[{id:'a',enabled:false}]},{},{a:{read:()=>assert.fail()}});assert.equal(r.ok,false);
});
test('malformed percentage is rejected',()=>assert.throws(()=>validateRows([{name:'x',remaining:'50'}])));
test('hanging adapter has a bounded timeout',async()=>{
 const r=await collect({providers:[{id:'hang'}]},{timeoutMs:20},{hang:{read:()=>new Promise(()=>{})}});assert.equal(r.ok,false);assert.match(r.error,/超时/);
});
