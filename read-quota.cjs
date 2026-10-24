'use strict';
const fs=require('node:fs');
const path=require('node:path');
const registry=require('./providers/index.cjs');
function validateRows(rows){
 if(!Array.isArray(rows))throw new Error('适配器必须返回数组');
 return rows.map(r=>{
  if(!r || typeof r.name!=='string')throw new Error('额度行缺少名称');
  if(r.remaining!=null && (!Number.isFinite(r.remaining)||r.remaining<0||r.remaining>100))throw new Error('剩余百分比必须为 0–100 或 null');
  if(r.displayValue!=null && typeof r.displayValue!=='string')throw new Error('余额显示值必须为文本');
  return {name:r.name,minutes:r.minutes??null,remaining:r.remaining??null,resetsAt:r.resetsAt??null,displayValue:r.displayValue??null,detail:r.detail??null};
 });
}
async function collect(config,context,adapters=registry){
 if(!Array.isArray(config.providers)||!config.providers.length)throw new Error('配置缺少 providers 数组');
 const enabled=config.providers.filter(p=>p.enabled!==false);
 const results=await Promise.all(enabled.map(async p=>{
  try{
   if(!adapters[p.id])throw new Error('未知服务商，请先注册适配器');
      const controller=new AbortController();
   let timer;
   let raw;
   try {
    raw=await Promise.race([
     adapters[p.id].read({...context,options:p.options||{},signal:controller.signal}),
     new Promise((_,reject)=>{timer=setTimeout(()=>{controller.abort();reject(new Error('接口超时'))},context.timeoutMs||28000)})
    ]);
   } finally {clearTimeout(timer)}
   const rows=validateRows(raw);
   return {id:p.id,ok:true,rows:rows.map(r=>({...r,providerId:p.id,name:p.id==='codex'?r.name:(p.label||p.id)+' · '+r.name}))};
  }catch(e){return {id:p.id,ok:false,error:(p.label||p.id)+': '+e.message,rows:[]}}
 }));
 const errors=results.filter(r=>!r.ok).map(r=>r.error);
 return {ok:results.some(r=>r.ok),rows:results.flatMap(r=>r.rows),errors,error:errors.join('；')||(results.length?'':'未启用任何服务商'),checkedAt:new Date().toISOString()};
}
async function main(){
 const [codex,output]=process.argv.slice(2);
 let data;
 try{
  const configPath=path.join(__dirname,'providers.local.json');
  const config=fs.existsSync(configPath)?JSON.parse(fs.readFileSync(configPath,'utf8').replace(/^\uFEFF/,'')):{providers:[{id:'codex',enabled:true},{id:'deepseek',label:'DeepSeek',enabled:true},...(fs.existsSync(path.join(__dirname,'subscription.local.txt'))?[{id:'traffic',label:'V2free',enabled:true}]:[])]};
  data=await collect(config,{codex});
 }catch(e){data={ok:false,error:'配置或读取错误：'+e.message,checkedAt:new Date().toISOString()};}
 const json=JSON.stringify(data);
 if(output){fs.writeFileSync(output+'.tmp',json);fs.renameSync(output+'.tmp',output)}else console.log(json);
}
if(require.main===module)main().catch(()=>{console.error('无法保存额度结果，请检查目录写入权限');process.exitCode=1});
module.exports={collect,validateRows};
