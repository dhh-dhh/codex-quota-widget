'use strict';
// Reserved adapters: do not infer subscription quota from API spend or balance.
const pending = name => ({read:async()=>{throw new Error(name+' 接口尚未配置；请实现对应 provider 适配器')}});
module.exports={
 codex:require('./codex.cjs'),
 traffic:require('./traffic.cjs'),
 claude:pending('Claude'),
 deepseek:require('./deepseek.cjs'),
 gemini:pending('Gemini'),
 openai:pending('OpenAI API'),
};
