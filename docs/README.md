# Pi Windows x64 离线包

`pi-offline` 目录包含 Pi 及其完整 npm 运行依赖、Windows x64 的 `rg` 和 `fd`，以及可选的三个离线扩展。

**不包含 Node.js、npm 和 Git**，直接使用目标机器上已安装的 Node.js 与 Git for Windows。

## 目录结构

```text
pi-offline/
├── app/                         Pi 1.5.2 及 npm 运行依赖
├── tools/
│   ├── rg/                      ripgrep 15.2.0
│   └── fd/                      fd 10.5.2
├── extensions/                  三个扩展及安装脚本
│   ├── npm/
│   ├── install.ps1
│   ├── settings.example.json
│   └── README.md
├── pi.cmd
├── README.md
└── models.example.json
```

## 运行要求

- Node.js >= 22.19.0，确认 `node --version` 可以运行。
- Git for Windows，确认 `git --version` 和 Bash 可用。Pi 的 bash 工具默认使用 Git Bash。
- Windows x64，建议使用 Windows Terminal。
- 如果要使用 `context-mode` 扩展，需要 Node.js >= 24.15.0；只用 Pi 和 web 扩展时 Node 22.19+ 即可。

## 启动

1. 把整个 `pi-offline` 目录复制到例如 `C:\Tools\pi-offline`，不要在压缩包里直接运行。
2. 打开 PowerShell，进入你要让 Pi 操作的项目目录。
3. 确认系统工具：

```powershell
node --version
git --version
```

4. 启动 Pi：

```powershell
C:\Tools\pi-offline\pi.cmd --version
C:\Tools\pi-offline\pi.cmd
```

不需要运行 `npm install`。启动器会自动把 `tools\rg`、`tools\fd` 加入 PATH，并设置 `PI_OFFLINE=1` 禁用 Pi 的自动更新、模型目录刷新和工具下载。

可以把 `C:\Tools\pi-offline` 加入用户 Path，重开终端后直接运行 `pi`。这是启动脚本，不是 npm 全局安装。

## 安装扩展

先完全退出 Pi，然后执行：

```powershell
powershell -ExecutionPolicy Bypass -File C:\Tools\pi-offline\extensions\install.ps1
```

脚本会把三个扩展合并到 `%USERPROFILE%\.pi\agent\npm`，并把固定版本条目合并进 `%USERPROFILE%\.pi\agent\settings.json`。已有的其他扩展和配置会保留，修改前生成带时间戳的 `.bak-*` 备份。

重启 Pi 后执行 `C:\Tools\pi-offline\pi.cmd list`，应看到三个 `npm:` 开头的包。

详细说明、手动安装和卸载步骤见 `extensions\README.md`。

## 配置内网 DeepSeek

将 `models.example.json` 复制为 `%USERPROFILE%\.pi\agent\models.json`（先创建目录；已有文件请合并，不要覆盖），替换 `baseUrl` 和模型 id。上下文和输出上限按实际服务填写。配置使用 Chat Completions 协议，服务需要支持流式输出与工具调用。

在当前 PowerShell 会话运行：

```powershell
$env:DEEPSEEK_API_KEY = '你的密钥'
C:\Tools\pi-offline\pi.cmd --provider internal-deepseek --model '你的模型ID'
```

进入 Pi 后执行 `!git --version` 验证 Bash，再让模型读取一个测试文件验证工具调用。包内不包含密钥。完全断网时，模型服务必须运行在本机或可访问的内网。

## 说明

- 包内 `rg` 和 `fd` 保留原发行包的许可证。
- `PI_OFFLINE=1` 只关闭 Pi 自身的联网更新，不会阻止模型请求或扩展的网页访问。
- 不要在这个包上执行 `pi update`；升级 Pi 请重新获取新的构建目录。
- 本目录只适用于 Windows x64。
