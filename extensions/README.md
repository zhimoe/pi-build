# Pi 扩展离线安装（Windows x64）

`pi-offline/extensions` 目录用于在不能访问 npm 的 Windows x64 机器上安装以下 Pi 扩展：

| 扩展 | 版本 | 运行时要求 |
| --- | --- | --- |
| `context-mode` | 2.1.7 | Node.js >= 24.15.0，Windows 上还需要 Git Bash |
| `pi-web-access` | 0.47.0 | Node.js >= 22.19.0 |
| `pi-smart-fetch` | 0.3.23 | Node.js >= 22.19.0 |

目录已包含三个扩展及其全部 npm 运行依赖，不需要联网，也不需要目标机器安装 npm。**不包含 Node.js 和 Git**，使用目标机器已有的 Node 和 Git for Windows。

安装脚本会把扩展放到 Pi 支持的用户目录 `%USERPROFILE%\.pi\agent`，不会修改 `pi-offline\app`。

离线安装只是把文件放到位。`pi-web-access` 的搜索/抓取和 `pi-smart-fetch` 的网页抓取在使用时仍然需要能访问对应服务；`context-mode` 的沙箱、索引和搜索完全在本机运行。

> 仅适用于 Windows x64。`pi-smart-fetch` 的 `wreq-js` 原生模块只保留了 `win32-x64-msvc`。

## 目录结构

```text
pi-offline/
├── app/                         Pi 1.5.2
├── tools/                       rg 和 fd
├── extensions/
│   ├── npm/                     扩展的 npm 目录（含 node_modules 全部依赖）
│   │   ├── package.json
│   │   ├── package-lock.json
│   │   └── node_modules/
│   ├── settings.example.json    settings.json 合并示例
│   ├── install.ps1              安装脚本
│   └── README.md
├── pi.cmd
├── README.md
└── models.example.json
```

## 安装步骤

先完全退出 Pi，然后执行：

```powershell
powershell -ExecutionPolicy Bypass -File C:\Tools\pi-offline\extensions\install.ps1
```

脚本会：

1. 把 `extensions\npm\node_modules` 合并到 `%USERPROFILE%\.pi\agent\npm\node_modules`。
2. 把三个固定版本依赖合并进 `%USERPROFILE%\.pi\agent\npm\package.json`。
3. 把三个 `npm:` 条目合并进 `%USERPROFILE%\.pi\agent\settings.json` 的 `packages` 数组。

已有的其他扩展和配置会保留。`package.json`、`settings.json` 修改前会生成带时间戳的 `.bak-*` 备份。如果机器上已有其他 Pi 扩展，建议先额外备份整个 `%USERPROFILE%\.pi\agent\npm` 目录。

也可以用 `-AgentDir` 指定其他 Pi 用户目录：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -AgentDir D:\pi-agent
```

### 手动安装

1. 把 `extensions\npm` 目录内容合并到 `%USERPROFILE%\.pi\agent\npm`：
   - 如果目录不存在，直接创建并复制 `package.json`、`package-lock.json`、`node_modules`。
   - 如果已存在，把 `node_modules` 下的内容合并进去，并把 `package.json` 中的 `dependencies` 合并到已有文件，不要覆盖原有依赖。
2. 打开 `%USERPROFILE%\.pi\agent\settings.json`，把下面三个条目追加到 `packages` 数组中，已有条目保留：

```json
{
  "packages": [
    "npm:context-mode@2.1.7",
    "npm:pi-web-access@0.47.0",
    "npm:pi-smart-fetch@0.3.23"
  ]
}
```

如果 `settings.json` 不存在，可以直接使用 `extensions\settings.example.json`。

3. 确认系统 Node 版本：

```powershell
node --version
```

只使用 `pi-web-access` 和 `pi-smart-fetch` 时需要 >= 22.19.0；使用 `context-mode` 时需要 >= 24.15.0。`context-mode` 还需要 Git Bash，确认 `git --version` 和 Bash 可用。

## 验证

重新启动 Pi 后执行：

```powershell
C:\Tools\pi-offline\pi.cmd list
```

应看到：

```text
User packages:
  npm:context-mode@2.1.7
    ...\.pi\agent\npm\node_modules\context-mode
  npm:pi-web-access@0.47.0
    ...\.pi\agent\npm\node_modules\pi-web-access
  npm:pi-smart-fetch@0.3.23
    ...\.pi\agent\npm\node_modules\pi-smart-fetch
```

进入 Pi 后可以进一步检查：

- 让模型调用 `ctx_doctor`（`context-mode`），应显示 Node、`node:sqlite`、Git Bash 等检查结果。
- 让模型调用 `web_search`（`pi-web-access`）；无额外配置时默认尝试 Exa MCP，需要能访问互联网。
- 让模型调用 `web_fetch`（`pi-smart-fetch`），同样需要网络。

## 注意事项

- 不要在这个离线环境中执行 `pi install npm:context-mode`、`pi update --extensions` 或 `pi update --all`。这些命令会调用 npm 访问 registry，离线时会失败；`extensions` 目录已经预先放好了对应版本。
- 扩展版本固定，`pi list` 显示的来源是 `npm:`。以后要升级，需要联网获取新版本并重新构建。
- 卸载：执行 `pi remove npm:context-mode`、`pi remove npm:pi-web-access`、`pi remove npm:pi-smart-fetch`，或者从 `settings.json` 的 `packages` 中删除对应条目，再删除 `%USERPROFILE%\.pi\agent\npm\node_modules` 中对应目录。
- `pi-web-access` 的额外 API key 配置在 `%USERPROFILE%\.pi\agent\web-search.json`，不是本安装包的一部分。没有 key 时默认的零配置搜索仍然需要联网。
- `settings.json` 是标准 JSON，不支持注释。修改前请保持备份。
