'use strict';
const fs=require('node:fs');
const path=require('node:path');
const defaultKeyFile=path.join(__dirname,'..','deepseek-key.local.txt');
function normalizeBalance(data){
 if(!Array.isArray(data?.balance_infos)||!data.balance_infos.length)throw Error('余额响应格式无效');
 return data.balance_infos.map(info=>{
  const total=info?.total_balance;
  if(!['CNY','USD'].includes(info?.currency)||typeof total!=='string'||total.length>40||! /^-?\d+(\.\d+)?$/.test(total)||!Number.isFinite(Number(total)))throw Error('余额响应格式无效');
  return {name:'API 余额',remaining:null,resetsAt:null,displayValue:(info.currency==='CNY'?'¥ ':'$ ')+total,detail:'API 账户余额 · '+info.currency};
 });
}
async function read({options={},signal,fetchImpl=fetch,env=process.env,keyFile=options.keyFile||defaultKeyFile}={}){
 let key=env[options.apiKeyEnv||'DEEPSEEK_API_KEY'];
 if(!key){try{key=fs.readFileSync(keyFile,'utf8').replace(/^\uFEFF/,'').trim()}catch{}}
 if(typeof key!=='string'||!key.trim())throw Error('请配置 DEEPSEEK_API_KEY 或 deepseek-key.local.txt');
 key=key.trim();
 if(/[\r\n\s]/.test(key))throw Error('DeepSeek 密钥格式无效，请检查本机配置');
 try{
  const response=await fetchImpl('https://api.deepseek.com/user/balance',{signal,redirect:'error',headers:{Authorization:'Bearer '+key,Accept:'application/json'}});
  if(!response.ok){if(response.status===401||response.status===403)throw Error('密钥无效或无权限');throw Error('服务暂不可用')}
  return normalizeBalance(await response.json());
 }catch(error){
  if(error.message==='密钥无效或无权限')throw Error('DeepSeek 密钥无效或无权限');
  throw Error('DeepSeek 余额读取失败，请检查网络或密钥');
 }
}
module.exports={read,normalizeBalance};
