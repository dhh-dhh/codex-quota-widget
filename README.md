# Codex Quota Widget

一个轻量的 Windows 桌面额度小组件，显示当前 Codex 账户的剩余额度和重置时间。使用 PowerShell WPF + Node.js，无第三方 npm 依赖。

## 功能

- 每 60 秒自动刷新，支持手动刷新
- 按账户返回的数据分别展示额度窗口，剩余比例为 `100 - usedPercent`
- 显示本地时区的重置时间
- 可拖动、记忆位置、置顶、可选开机启动
- 网络或登录异常时显示提示，不把失败当成零额度
- 单实例运行

## 运行

1. 使用 Windows 10/11，自带 Windows PowerShell 5.1 和 WPF。
2. 安装 Node.js 22 或更新版本，并安装、登录 Codex。
3. 下载本仓库 ZIP 并解压到可写的固定文件夹。
4. 双击 `启动额度小组件.vbs`。

也可以在项目文件夹运行：

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\widget.ps1
```

优先从 PATH 查找 Node.js 和 codex.exe，再尝试 Windows Codex 安装位置及其运行环境。若自动查找失败，可设置用户环境变量 `CODEX_WIDGET_NODE` 和 `CODEX_WIDGET_CODEX`，分别指定 node.exe、codex.exe 的完整路径。更新环境变量后重新启动小组件。

勾选“开机自动显示”会在当前用户的启动文件夹创建快捷方式；取消勾选会移除该快捷方式。卸载前先取消勾选，再关闭窗口并删除项目文件夹。

## 数据与隐私

通过本机 Codex app-server 的官方 `account/rateLimits/read` 只读接口获取账户额度，复用 Codex 登录状态，不发起模型对话，不要求复制 API Key，也不读取聊天记录。

额度查询需要联网访问 Codex 服务。项目目录中的 `quota.json` 保存最近一次查询结果，`position.json` 保存窗口位置；日志和预览图也只保存在本地。这些运行时文件已加入 `.gitignore`，不要手动上传自己的凭证或运行数据。

参考：[Codex App Server 官方文档](https://learn.chatgpt.com/docs/app-server)。本项目是非官方小工具，与 OpenAI 无隶属关系。接口或桌面安装路径变更可能需要适配。额度缺失表示暂不可用，不代表零额度；重置后以服务端重新获取的数据为准。

## 文件

- `widget.ps1`：窗口、刷新、开机启动管理
- `read-quota.cjs`：只读额度查询及超时处理
- `启动额度小组件.vbs`：隐藏控制台启动窗口

## 验证

```powershell
node --check .\read-quota.cjs
node .\read-quota.cjs "C:\path\to\codex.exe"
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\widget.ps1 -SmokeTest
```

关闭已运行的小组件后再进行窗口验证。SmokeTest 在额度查询成功后保存本地 `preview.png` 并退出；网络或登录失败时仍显示错误，可手动关闭。

## 多 AI 接口扩展（v1.1）

已预留 Claude、DeepSeek、Gemini、OpenAI API 的适配位置，默认关闭，尚未接通。详见 [适配器说明](PROVIDERS.md) 和 providers.example.json。当前真实可用的仍是 Codex。

窗口支持滚动显示多个额度，也支持余额文本；服务商部分失败不会阻断其他服务商。配置文件 providers.local.json 不上传 Git，密钥只使用环境变量。

运行 `node --test quota.test.cjs` 执行边界和异常测试。SmokeTest 使用独立窗口锁，并在 40 秒后结束等待。
