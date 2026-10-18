const {spawn} = require('node:child_process');
const {createInterface} = require('node:readline');
const {writeFileSync,renameSync} = require('node:fs');
const [exe, output] = process.argv.slice(2);
let done = false;
const child = spawn(exe, ['app-server','--listen','stdio://'], {windowsHide:true, stdio:['pipe','pipe','ignore']});
const timer = setTimeout(()=>finish({ok:false,error:'读取超时，请检查网络或 Codex 登录状态'}),25000);
function finish(data) {
  if(done) return; done=true; clearTimeout(timer);
  const result=JSON.stringify({...data,checkedAt:new Date().toISOString()});
  if(output) {writeFileSync(output+'.tmp',result);renameSync(output+'.tmp',output);}
  else console.log(result);
  child.kill();
}
function send(data){ child.stdin.write(JSON.stringify(data)+'\n'); }
child.on('error',()=>finish({ok:false,error:'无法启动 Codex，请确认已安装桌面应用'}));
child.stdin.on('error',()=>{});
child.on('exit',()=>{if(!done)finish({ok:false,error:'Codex 服务退出，请重新登录后重试'});});
createInterface({input:child.stdout}).on('line',line=>{
  let msg;try{msg=JSON.parse(line)}catch{return}
  if(msg.id===1){
    if(msg.error)return finish({ok:false,error:'Codex 初始化失败'});
    send({method:'initialized'});
    send({id:2,method:'account/rateLimits/read'});
  }
  if(msg.id===2){
    if(msg.error)return finish({ok:false,error:'额度读取失败，请检查网络并确认 Codex 已登录'});
    const r=msg.result;
    const buckets=r.rateLimitsByLimitId && Object.keys(r.rateLimitsByLimitId).length ? Object.values(r.rateLimitsByLimitId) : r.rateLimits ? [r.rateLimits] : [];
    const rows=buckets.flatMap(b=>['primary','secondary'].filter(k=>b[k]).map(k=>({name:b.limitName||b.limitId||'Codex',minutes:b[k].windowDurationMins,remaining:typeof b[k].usedPercent==='number'?Math.max(0,Math.min(100,100-b[k].usedPercent)):null,resetsAt:b[k].resetsAt})));
    finish({ok:true,rows});
  }
});
send({id:1,method:'initialize',params:{clientInfo:{name:'codex_quota_widget',title:'Codex quota widget',version:'1.0.0'}}});
