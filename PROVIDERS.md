# 添加 AI 服务商

当前只有 Codex 已接通并进行真实账户验证。Claude、DeepSeek、Gemini、OpenAI API 是预留适配器，默认关闭；启用但未实现时会显示“接口尚未配置”。示例中的环境变量名称只是约定，不代表已经调用相应服务。

## 配置

将 providers.example.json 复制为 providers.local.json，按需启用 provider。此本地文件已被 Git 忽略。密钥只放用户环境变量，配置里仅存环境变量名，禁止把真实密钥写进源码或提交 Git。

## 接口约定

在 providers/ 中新增模块，并在 providers/index.cjs 注册：

```js
module.exports = {
  async read({ options, signal }) {
    // 根据服务商官方文档实现。网络请求必须传入 signal。
    // const key = process.env[options.apiKeyEnv];
    // 不在错误、日志、返回行中包含密钥或原始认证响应。
    return [{
      name: 'API 余额',
      remaining: null,
      displayValue: '12.50 CNY',
      detail: 'API 账户余额；不是订阅额度',
      resetsAt: null
    }];
  }
};
```

以上返回值只是接口格式示例，不用于真实展示。

每行支持 name、remaining（0–100 或 null）、minutes、resetsAt（Unix 秒）、displayValue（可选余额文本）、detail。余额类型不提供 remaining，窗口便不画百分比进度条。未知信息应返回 null；请求失败抛出脱敏错误，不能伪装成零额度。

适配器并行执行、互相隔离，每个最多 28 秒，失败项显示错误，成功项继续展示。必须遵守 AbortSignal，超时后中止网络请求。配置读取失败会显示配置错误。

订阅额度、API 余额和 API 消费统计是不同概念；接入前应核实官方接口及所需权限，不根据消费额猜测订阅剩余比例，也不要复制浏览器 Cookie。

## 检查

运行 node --test quota.test.cjs，覆盖未知数据、0/100% 边界、多额度窗口、部分失败、禁用服务商及超时。
