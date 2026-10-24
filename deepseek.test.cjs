const {test}=require('node:test');
const assert=require('node:assert/strict');
const {normalizeBalance,read}=require('./providers/deepseek.cjs');
test('DeepSeek preserves total balance, currency and zero without inventing a percentage',()=>{
 const rows=normalizeBalance({is_available:false,balance_infos:[{currency:'CNY',total_balance:'0.00',granted_balance:'0.00',topped_up_balance:'0.00'},{currency:'USD',total_balance:'12.3456'}]});
 assert.deepEqual(rows.map(r=>[r.displayValue,r.remaining]),[['¥ 0.00',null],['$ 12.3456',null]]);
 assert.match(rows[0].detail,/API/);
});
test('DeepSeek rejects missing and malformed balances rather than displaying zero',()=>{
 for(const data of [{},{balance_infos:[]},{balance_infos:[{currency:'CNY',total_balance:''}]},{balance_infos:[{currency:'CNY',total_balance:'NaN'}]},{balance_infos:[{currency:'EUR',total_balance:'1.00'}]}])assert.throws(()=>normalizeBalance(data));
});
test('DeepSeek sends a key only to the official endpoint, with cancellation and no redirects',async()=>{
 const controller=new AbortController();let called=false;
 const rows=await read({env:{DEEPSEEK_API_KEY:'private-test-key'},signal:controller.signal,fetchImpl:async(url,options)=>{
  called=true;assert.equal(url,'https://api.deepseek.com/user/balance');assert.equal(options.signal,controller.signal);
  assert.equal(options.redirect,'error');assert.equal(options.headers.Authorization,'Bearer private-test-key');
  return {ok:true,json:async()=>({balance_infos:[{currency:'CNY',total_balance:'26.80'}]})};
 }});assert.equal(called,true);assert.equal(rows[0].displayValue,'¥ 26.80');
});
test('DeepSeek errors never expose credentials or server response text',async()=>{
 for(const fetchImpl of [async()=>{throw Error('private-test-key')},async()=>({ok:false,status:401,text:async()=> 'private-test-key'}),async()=>({ok:true,json:async()=>{throw Error('private-test-key')}})]){
  await assert.rejects(read({env:{DEEPSEEK_API_KEY:'private-test-key'},fetchImpl}),error=>!error.message.includes('private-test-key'));
 }
 await assert.rejects(read({env:{},keyFile:'does-not-exist.local.txt'}),/deepseek-key.local.txt/);
});
test('a failed DeepSeek lookup leaves Codex quota available and source identity intact',async()=>{
 const {collect}=require('./read-quota.cjs');
 const result=await collect({providers:[{id:'codex'},{id:'deepseek',label:'DeepSeek'}]},{},{
  codex:{read:async()=>[{name:'codex',remaining:80}]},
  deepseek:{read:async()=>{throw Error('DeepSeek 余额读取失败')}}
 });
 assert.equal(result.ok,true);assert.equal(result.rows[0].providerId,'codex');assert.equal(result.rows[0].remaining,80);assert.equal(result.errors.length,1);
});
