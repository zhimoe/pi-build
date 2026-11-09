Windows x64 离线便携包，固定 Pi npm 发布版本 1.5.0。

- 已安装 Node.js >=22.19.0、Git for Windows、rg、fd：下载 `pi-1.5.0-windows-x64-lite.zip`，仅包含 Pi 和完整 npm 运行依赖。
- 需要自带所有工具：下载 `pi-1.5.0-windows-x64.zip`，包含 Node.js、Portable Git、rg、fd。

完整解压后从项目目录调用其中的 `pi.cmd`，无需运行 npm install。两个版本默认关闭自动联网更新。DeepSeek 接口和密钥按包内 README.md 配置。

`SHA256SUMS.txt` 用于校验下载。自动测试运行于 Windows Server 2022 x64，未验证真实 Windows 10 终端或模型 API。不要下载自动生成的 Source code 压缩包。
