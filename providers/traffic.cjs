'use strict';
const fs=require('node:fs');
const path=require('node:path');
const defaultUrlFile=path.join(__dirname,'..','subscription.local.txt');
const gb=bytes=>Number((bytes/1073741824).toFixed(2)).toString();
function normalizeUserInfo(header){
 const fields={};
 for(const part of String(header||'').split(';')){
  const match=part.trim().match(/^(upload|download|total)\s*=\s*(\d+)$/);
  if(match)fields[match[1]]=Number(match[2]);
 }
 if(!['upload','download','total'].every(key=>Number.isSafeInteger(fields[key]))||fields.total<=0||!Number.isSafeInteger(fields.upload+fields.download)){
  throw Error('订阅未提供有效的流量统计，请确认链接或服务商支持情况');
 }
 const used=fields.upload+fields.download;
 const remaining=Math.max(0,fields.total-used);
 return [{name:'主套餐剩余流量',remaining:Math.round(remaining/fields.total*10000)/100,
  displayValue:gb(remaining)+' GB',resetsAt:null,
  detail:'已用 / 总量：'+gb(used)+' / '+gb(fields.total)+' GB · 每分钟刷新'}];
}
async function read({options={},signal,fetchImpl=fetch}){
 let raw=options.url;
 if(!raw){
  try{raw=fs.readFileSync(options.urlFile||defaultUrlFile,'utf8').replace(/^\uFEFF/,'').trim()}
  catch{throw Error('请将本站订阅链接保存到 subscription.local.txt')}
 }
 let url;
 try{url=new URL(raw)}catch{throw Error('订阅链接格式无效')}
 if(url.protocol!=='https:'||url.username||url.password)throw Error('订阅链接必须使用 HTTPS，且不能包含用户名密码');
 let response;
 try{
  response=await fetchImpl(url.href,{signal,redirect:'manual',headers:{'User-Agent':'clash.meta'}});
  // The node list is unnecessary; never retain or log the subscription body.
  const header=response.headers.get('subscription-userinfo');
  if(!response.ok)throw Error('response');
  return normalizeUserInfo(header);
 }catch(error){
  if(error.message.startsWith('订阅未提供'))throw error;
  throw Error('流量读取失败，请检查网络或订阅链接是否有效');
 }finally{if(response?.body)await response.body.cancel().catch(()=>{})}
}
module.exports={read,normalizeUserInfo};
