# 额度与流量适配器

## V2free 流量

支持读取 Clash 订阅响应的 `Subscription-Userinfo`，已通过本机真实订阅读取验证，显示剩余 GB、剩余比例及已用 / 总量。数据以订阅接口口径为准，可能与网页单独展示的主套餐统计不同；首次接入请核对。界面中的 GB 按 1024³ 字节换算。套餐到期时间不会作为流量重置时间。

1. 将用户中心提供的 HTTPS Clash 订阅链接保存到项目根目录 `subscription.local.txt`（一行一个链接，仅填写一条）。无需提供网站密码或 Cookie。
2. 没有 `providers.local.json` 时，存在该文本文件便自动启用流量显示；如已有配置，请加入 `{"id":"traffic","label":"V2free","enabled":true}`。
3. 重启组件，或等待下一次分钟刷新。链接失效或响应不含有效统计时显示读取错误。

`subscription.local.txt` 和 `providers.local.json` 均已加入 Git 忽略规则。订阅链接视同凭证，不要上传或截图公开。组件只向链接所指向的 HTTPS 服务请求，不跟随重定向、不保存节点配置正文、不在日志中输出链接。

协议参考：[MetaCubeX 官方面板说明](https://github.com/MetaCubeX/metacubexd/blob/main/README.md)。订阅接口的过期时间不等于主套餐重置日期。

## AI 服务商

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

运行 `node --test quota.test.cjs traffic.test.cjs`，覆盖未知数据、0/100% 边界、多额度窗口、部分失败、禁用服务商、超时、订阅流量解析及错误脱敏。
