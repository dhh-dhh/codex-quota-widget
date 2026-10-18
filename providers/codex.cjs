'use strict';
const {spawn} = require('node:child_process');
const {createInterface} = require('node:readline');
function normalize(result) {
  if (!result || typeof result !== 'object') throw new Error('额度响应格式错误');
  const map = result.rateLimitsByLimitId;
  const buckets = map && Object.keys(map).length ? Object.values(map) : result.rateLimits ? [result.rateLimits] : [];
  return buckets.flatMap(b => ['primary','secondary'].filter(k => b?.[k]).map(k => {
    const w=b[k];
    return {name:b.limitName||b.limitId||'Codex',minutes:w.windowDurationMins,
      remaining:Number.isFinite(w.usedPercent)?Math.max(0,Math.min(100,100-w.usedPercent)):null,
      resetsAt:Number.isFinite(w.resetsAt)?w.resetsAt:null};
  }));
}
function read({codex, timeoutMs=25000}) {
  return new Promise((resolve,reject)=>{
    if(!codex) return reject(new Error('找不到 Codex，请安装登录或设置 CODEX_WIDGET_CODEX'));
    const child=spawn(codex,['app-server','--listen','stdio://'],{windowsHide:true,stdio:['pipe','pipe','ignore']});
    let done=false;
    const timer=setTimeout(()=>finish(new Error('读取超时，请检查网络或登录状态')),timeoutMs);
    function finish(error,rows){if(done)return;done=true;clearTimeout(timer);child.kill();error?reject(error):resolve(rows);}
    child.on('error',()=>finish(new Error('无法启动 Codex')));
    child.on('exit',()=>finish(new Error('Codex 服务提前退出')));
    child.stdin.on('error',()=>{});
    const send=m=>{if(!done)child.stdin.write(JSON.stringify(m)+'\n');};
    createInterface({input:child.stdout}).on('line',line=>{
      let m;try{m=JSON.parse(line)}catch{return}
      if(m.id===1){if(m.error)return finish(new Error('Codex 初始化失败'));send({method:'initialized'});send({id:2,method:'account/rateLimits/read'});}
      if(m.id===2){if(m.error)return finish(new Error('额度读取失败，请检查网络和登录状态'));try{finish(null,normalize(m.result))}catch(e){finish(e)}}
    });
    send({id:1,method:'initialize',params:{clientInfo:{name:'codex_quota_widget',title:'AI quota widget',version:'1.1.0'}}});
  });
}
module.exports={read,normalize};
