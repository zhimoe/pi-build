# Pi Windows 离线包

从固定的 npm 发布版 `@earendil-works/pi-coding-agent@1.5.0` 组装 Windows x64 便携包，不重新编译 Pi 源码。包含 Node.js 22.23.4、Portable Git 2.56.0.4、ripgrep 15.2.0、fd 10.5.2，以及 Pi 的完整运行依赖。各工具保留原发行包的许可证。npm 依赖安装禁用生命周期脚本，生成的 package-lock.json 随包交付；工具下载验证固定 SHA-256。

## 下载与启动

从 https://github.com/zhimoe/pi-build/releases/latest 下载 `pi-1.5.0-windows-x64.zip`，可用同页 SHA256SUMS.txt 校验。不要下载 GitHub 自动生成的 Source code。

1. 解压整个 ZIP 到例如 `C:\Tools\pi-offline`。无需管理员权限、npm install 或另外安装 Node/Git。
2. 打开 PowerShell，进入你希望 Pi 操作的项目目录。
3. 执行 `C:\Tools\pi-offline\pi.cmd --version`，再执行 `C:\Tools\pi-offline\pi.cmd`。

启动器保留当前工作目录，并设置 PI_OFFLINE=1，禁止 Pi 自动更新、模型目录刷新和工具下载。模型请求仍需要能访问你的服务。程序数据默认写入 `%USERPROFILE%\.pi\agent`，不会随便携目录移动。

## 配置内网 DeepSeek

将 models.example.json 复制为 `%USERPROFILE%\.pi\agent\models.json`（先创建目录；已有文件请合并，不要覆盖），替换 baseUrl 和模型 id。上下文和输出上限请按实际服务填写。配置使用 Chat Completions 协议，服务需要支持流式输出与工具调用；推理模式兼容设置取决于实际部署。

在当前 PowerShell 会话运行：

```powershell
$env:DEEPSEEK_API_KEY = '你的密钥'
C:\Tools\pi-offline\pi.cmd --provider internal-deepseek --model '你的模型ID'
```

进入 Pi 后执行 `!git --version` 验证 Bash，再让模型读取一个测试文件以验证工具调用。包内不包含密钥。完全断网时，模型服务必须运行在本机或可访问的内网。

## 构建与验证范围

GitHub Actions 页面手动运行 Build Windows offline package。成功后会上传 Actions 产物，并创建带 ZIP 和 SHA256SUMS.txt 的 GitHub Release。

构建使用 Windows Server 2022 x64。自动验证包移动到含空格路径后，移除 runner 的额外 PATH，仍能运行 Pi --version/--help、Node、Git Bash、rg 和 fd。未验证真实 Windows 10 交互终端或实际模型 API。建议在目标 Windows 10 上使用 Windows Terminal。x64 包不适用于 32 位 Windows。

这是完整运行环境包；联网安装阶段解析的间接依赖由包内 lockfile 记录，不承诺不同日期重新构建得到逐字节一致的结果。
