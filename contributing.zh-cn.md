# 参与 Juicer 开发

[报告缺陷](https://github.com/AMFI-Disable/Juicer/issues/new?title=%5BBUG%5D+&body=%23%23+Environment+%2F+%E8%BF%90%E8%A1%8C%E7%8E%AF%E5%A2%83%0A%0A%23%23+Steps+To+Reproduce+%2F+%E5%A4%8D%E7%8E%B0%E6%AD%A5%E9%AA%A4%0A%0A%23%23+Expected+And+Actual+Results+%2F+%E9%A2%84%E6%9C%9F%E4%B8%8E%E5%AE%9E%E9%99%85%E7%BB%93%E6%9E%9C%0A%0A) · [提出功能建议](https://github.com/AMFI-Disable/Juicer/issues/new?title=%5BFEATURE%5D+&body=%23%23+User+Need+%2F+%E4%BD%BF%E7%94%A8%E9%9C%80%E6%B1%82%0A%0A%23%23+Proposed+Change+%2F+%E6%94%B9%E8%BF%9B%E6%96%B9%E6%A1%88%0A%0A%23%23+Acceptance+Criteria+%2F+%E9%AA%8C%E6%94%B6%E6%9D%A1%E4%BB%B6%0A%0A)

[English](contributing.md) · [项目文档](readme.zh-cn.md)

## 开发环境

安装 Xcode 15 或更高版本和 XcodeGen，然后在项目根目录执行以下命令：

```bash
brew install xcodegen
xcodegen generate
open juicer.xcodeproj
```

在 Xcode 中按 Command-R 编译并启动，按 Command-U 运行单元测试。

## 提交改动

新增文件及目录使用小写名称。提交说明采用 `type: three lowercase words` 格式，例如 `fix: resolve timing warning`。发起拉取请求时请关联议题、列出运行过的检查及结果，并说明实际操作验证的功能。参与协作前请阅读[行为准则](code_of_conduct.md)。
