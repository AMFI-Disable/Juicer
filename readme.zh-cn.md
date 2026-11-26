# Juicer

[English](readme.md) · [更新日志](changelog.md) · [安全策略](security.md) · [MIT 许可证](license)

[![发布版本 v1.1.3](https://img.shields.io/badge/Release-v1.1.3-blue?style=flat-square)](https://github.com/AMFI-Disable/Juicer/releases)

## 功能与工作区

Juicer 将系统维护、Homebrew 管理和开发工具集中在原生 SwiftUI 窗口中。Juicer Hub 是各工作区的入口；Juicer Store 用于管理 cask、formula、tap、服务和 Brewfile。若主要需求是软件包管理，也可使用独立的 [BrewStore](https://github.com/AMFI-Disable/BrewStore)。

- **系统与硬件、网络与端口、安全与隐私**：检查内存压力、电池、监听端口、DNS 设置及系统权限。
- **磁盘与存储、系统配置、桌面工具**：使用 Space Lens 查看目录占用；检查应用配套文件、缓存和残留目录，再决定哪些需要清理。桌面工具提供剪贴板历史、窗口排列等功能。
- **开发工具、Git、Docker 和数据库工作区**：切换工具链，查看提交或容器日志，检查本机数据库服务并管理备份。
- **AI、API、转换及 Creator 工作区**：连接本机模型，检查 API 响应，在本地转换文件，或浏览开源项目。

运行自定义脚本前请检查脚本内容。管理系统服务、修改网络配置和删除文件时，应确认目标及系统权限提示。软件包目录和远程仓库等功能需要访问所选服务。

## 安装

通过中央 Homebrew tap 安装：

```bash
brew tap AMFI-Disable/tap
brew install --cask juicer
```

手动安装时，从 [v1.1.3 发布页](https://github.com/AMFI-Disable/Juicer/releases/tag/v1.1.3) 下载 `juicer.zip` 和相应校验文件。运行 `shasum -a 256 juicer.zip`，与发布的摘要核对后再解压并将 Juicer.app 放入“应用程序”。该开源构建未经 Apple 公证；如首次打开时出现提示，核对后可在“系统设置 → 隐私与安全性”中选择“仍要打开”。

## 构建与测试

在 macOS 14 或更新版本上安装 Xcode 和 XcodeGen，然后在项目根目录执行：

```bash
brew install xcodegen
xcodegen generate
xcodebuild build -project juicer.xcodeproj -scheme juicer -configuration Release
xcodebuild test -project juicer.xcodeproj -scheme juicer -destination 'platform=macOS'
```

贡献代码前请阅读[贡献指南](contributing.zh-cn.md)。完整的工作区清单及架构说明见[英文文档](readme.md)。
