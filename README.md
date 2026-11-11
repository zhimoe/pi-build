# Pi Windows 离线包构建

一条命令构建一个可直接拷贝的 Windows x64 目录：

```bash
node build.mjs
```

产物：

```text
dist/pi-offline/
├── app/                         Pi 1.5.2 及 npm 运行依赖
├── tools/
│   ├── rg/                      ripgrep 15.2.0
│   └── fd/                      fd 10.5.2
├── extensions/                  三个扩展及安装脚本
│   ├── npm/                     context-mode、pi-web-access、pi-smart-fetch 及依赖
│   ├── install.ps1
│   ├── settings.example.json
│   └── README.md
├── pi.cmd
├── README.md
└── models.example.json
```

构建完成后只需要拷贝 `dist/pi-offline` 这一个目录。目录中不包含 Node.js、npm 和 Git，使用目标机器已有的 Node 和 Git for Windows。

## 构建要求

- Node.js >= 22.19.0
- `7z` 可执行

固定版本：

| 组件 | 版本 |
| --- | --- |
| Pi | 1.5.2（可用环境变量 `PI_VERSION` 覆盖） |
| context-mode | 2.1.7 |
| pi-web-access | 0.47.0 |
| pi-smart-fetch | 0.3.23 |
| ripgrep | 15.2.0 |
| fd | 10.5.2 |

下载文件缓存在 `downloads/`，校验失败会自动重新下载。`rg`、`fd` 的下载固定 SHA256；npm 依赖由 package-lock 的完整性校验保证。

## 安装 Pi

目标机器需要：

- Node.js >= 22.19.0（`node --version` 可运行）
- Git for Windows（`git --version` 可运行，提供 Bash）

1. 把 `dist/pi-offline` 复制到例如 `C:\Tools\pi-offline`。
2. 进入项目目录，执行：

```powershell
C:\Tools\pi-offline\pi.cmd --version
C:\Tools\pi-offline\pi.cmd
```

不需要运行 `npm install`。`pi.cmd` 会自动把 `tools\rg`、`tools\fd` 加入 PATH，并设置 `PI_OFFLINE=1` 关闭 Pi 的自动更新、模型目录刷新和工具下载。

## 安装扩展

先完全退出 Pi，然后执行：

```powershell
powershell -ExecutionPolicy Bypass -File C:\Tools\pi-offline\extensions\install.ps1
```

脚本会把扩展安装到 Pi 支持的用户目录 `%USERPROFILE%\.pi\agent\npm`，并把三个固定版本条目合并进 `%USERPROFILE%\.pi\agent\settings.json`。已有的其他扩展和配置会保留，修改前生成带时间戳的 `.bak-*` 备份。

验证：

```powershell
C:\Tools\pi-offline\pi.cmd list
```

应看到三个 `npm:` 开头的包。详细说明、手动安装和卸载步骤见 `dist/pi-offline/extensions/README.md`。

### Node 版本

- `pi-web-access`、`pi-smart-fetch` 需要 Node >= 22.19.0。
- `context-mode` 需要 Node >= 24.15.0，并且 Windows 上需要 Git Bash。

如果要用 `context-mode`，请先安装 Node 24.15+。

## 说明

- 离线安装只解决“装”。`pi-web-access` 和 `pi-smart-fetch` 使用时仍需要网络；`context-mode` 完全本地运行。
- 不要在这个环境执行 `pi install npm:...` 或 `pi update --extensions`，它们会访问 npm registry。
- `PI_OFFLINE=1` 只关闭 Pi 自身的联网更新，不会阻止模型请求或扩展的网页访问。
- 产物只适用于 Windows x64。扩展中 `wreq-js` 只保留 `win32-x64-msvc` 原生模块。
