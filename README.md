# Codex Quota Widget

一个轻量的 Windows 桌面额度小组件，显示当前 Codex 账户的剩余额度和重置时间。使用 PowerShell WPF + Node.js，无第三方 npm 依赖。

最新版本 **v1.6**：DeepSeek API 余额与 Codex 额度并排显示，标题右侧新增每秒更新的上传 / 下载网速，适配浅灰和紫黑两种主题。详见 [更新日志与升级说明](CHANGELOG.md)。

采用 300 宽的浅灰网格紧凑界面，搭配低饱和蓝灰读数，流量卡片以单行标题和数值减少高度。在底部“开机启动”右侧勾选“深色模式”即可切换为紫黑票券主题。两种主题均包含细网格、底部虚线和票券缺口，重启后会恢复上次选择。此偏好保存在本机 `appearance.json`，不上传 Git。票券主题参考 [zeeshan_2112 的 Uiverse 卡片](https://uiverse.io/zeeshan_2112/shy-rattlesnake-3)，授权说明见 [第三方声明](THIRD_PARTY_NOTICES.md)。

本机还可配置 V2free 流量显示，接入步骤及数据口径见 [流量配置说明](PROVIDERS.md)。

顶部可并排显示 Codex 额度与 DeepSeek API 账户余额。将 DeepSeek API Key 保存到本机 `deepseek-key.local.txt`，或设置 `DEEPSEEK_API_KEY`，即可每分钟读取官方余额；密钥文件不会上传 Git。详细配置见 [DeepSeek 接入说明](PROVIDERS.md#deepseek-api-余额)。

标题右侧显示实时上传（↑）与下载（↓）速度，每秒采样本机运行中的物理网卡，汇总字节每秒并自动切换 KB/s、MB/s、GB/s。首次采样或暂无可用网卡时显示 `--`。升级时请同时更新新增的 `network.ps1`。

流量卡片上方展示剩余 GB、进度及已用 / 总量，下方通过“系统代理”开关控制 Windows 当前使用的 Clash Verge 本地代理，每 2 秒核对系统实际状态。Clash Verge 需保持运行，且当前代理地址必须与其配置一致。它不修改 Clash 节点、规则、TUN 或应用内部偏好；Clash 再次应用自身设置或重启时可能重新接管系统代理。遇到其他代理、PAC 或代理守卫时开关会禁用并显示原因。

## 功能

- 每 60 秒自动刷新，支持手动刷新
- 按账户返回的数据分别展示额度窗口，剩余比例为 `100 - usedPercent`
- 显示本地时区的重置时间
- 可拖动、记忆位置、置顶、可选开机启动
- 网络或登录异常时显示提示，不把失败当成零额度
- 单实例运行
- 同屏显示本机 NVIDIA 显卡占用率、物理内存占用率和已用/总容量，每 2 秒异步采样，不阻塞窗口；额度仍每 60 秒刷新。显卡通过驱动自带的 `nvidia-smi` 读取，多个显卡分别显示；驱动不可用时显示暂无数据。

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

勾选“开机启动”会在当前用户的启动文件夹创建快捷方式；取消勾选会移除该快捷方式。卸载前先取消勾选，再关闭窗口并删除项目文件夹。

## 数据与隐私

通过本机 Codex app-server 的官方 `account/rateLimits/read` 只读接口获取账户额度，复用 Codex 登录状态，不发起模型对话，不要求复制 API Key，也不读取聊天记录。

额度查询需要联网访问 Codex 服务。项目目录中的 `quota.json` 保存最近一次查询结果，`position.json` 保存窗口位置；日志和预览图也只保存在本地。这些运行时文件已加入 `.gitignore`，不要手动上传自己的凭证或运行数据。

参考：[Codex App Server 官方文档](https://learn.chatgpt.com/docs/app-server)。本项目是非官方小工具，与 OpenAI 无隶属关系。接口或桌面安装路径变更可能需要适配。额度缺失表示暂不可用，不代表零额度；重置后以服务端重新获取的数据为准。

## 文件

- `widget.ps1`：窗口、刷新、开机启动管理
- `read-quota.cjs`：只读额度查询及超时处理
- `启动额度小组件.vbs`：隐藏控制台启动窗口
- `hardware.ps1`：本机内存与 NVIDIA 显卡占用采集
- `widget-ui.ps1`：浅色 / 深色主题、额度圆环、流量卡片和硬件列表；更新时需与 `widget.ps1` 一并替换
- `proxy-control.ps1`：读取 Windows 系统代理状态，并在确认地址属于 Clash Verge 后通过 WinINet 切换手动代理

## 验证

```powershell
node --check .\read-quota.cjs
node --test .\quota.test.cjs .\traffic.test.cjs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\hardware.test.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\proxy.test.ps1
node .\read-quota.cjs "C:\path\to\codex.exe"
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\widget.ps1 -SmokeTest
```

SmokeTest 使用独立窗口锁，额度和硬件读取成功后保存 `preview.png`、`preview-light.png`、`preview-dark.png` 并退出，分别核对当前、浅色和黑色主题。它不会改变保存的主题偏好；网络或登录失败时最多等待约 40 秒后退出。

## 多 AI 接口扩展（v1.1）

已预留 Claude、DeepSeek、Gemini、OpenAI API 的适配位置，默认关闭，尚未接通。详见 [适配器说明](PROVIDERS.md) 和 providers.example.json。当前真实可用的仍是 Codex。

窗口支持滚动显示多个额度，也支持余额文本；服务商部分失败不会阻断其他服务商。配置文件 providers.local.json 不上传 Git，密钥只使用环境变量。

运行 `node --test quota.test.cjs` 执行边界和异常测试。SmokeTest 使用独立窗口锁，并在 40 秒后结束等待。
