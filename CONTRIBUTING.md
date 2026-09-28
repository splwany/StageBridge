# 参与开发

需要 macOS 14+ 与 Apple Command Line Tools 或完整 Xcode，无第三方依赖。

```sh
./scripts/test.sh
./scripts/build.sh
./scripts/package.sh
```

如果 SDK 与 Swift 编译器不匹配，设置 `SDKROOT` 为本机已安装且匹配的 SDK，不要修改全局工具链来迁就项目。

先阅读 [架构说明](docs/ARCHITECTURE.md) 和 [测试边界](docs/TESTING.md)。行为变更应补充对应的隔离测试，保留“连接变化才切换”和“手动设置不被轮询覆盖”的约束。请勿在自动化测试中调用真实台前调度控制或修改用户登录项。

版本的唯一运行时来源为 `Resources/Info.plist`：`CFBundleShortVersionString` 为基础版本，`CFBundleVersion` 为递增构建号，`StageByScreenReleaseVersion` 为发行标识。UI 和发行脚本读取 Bundle；变更版本时同步更新更新记录和 README 的介绍。

提交前运行测试、双架构构建和 `git diff --check`。UI 变更还应检查实际窗口，包括长错误提示、滚动、暂停与关闭窗口后的菜单栏行为。Xcode 工程添加文件时，需同步命令行构建的源码范围。

不要提交构建产物、个人 Xcode 状态、证书或凭据。发行文档由打包脚本显式选择；开发文档和机器诊断不进入 DMG。仓库公开及正式签名由维护者决定。

## 图标

运行 `./scripts/make-icon.sh` 重新生成 `Resources/AppIcon.icns`。传统 macOS 图标在 1024 画布中使用 824 像素主体和透明留白，并输出全部标准尺寸。这个比例以 macOS 15 系统图标的实际可见边界为对照，不是 Liquid Glass 分层格式。

新系统的完整动态外观需要用 Icon Composer 和完整 Xcode 编译分层 `.icon`；不能把传统 ICNS 的透明边距直接套进其满画布背景。参考 [Apple 图标规范](https://developer.apple.com/design/human-interface-guidelines/app-icons) 和 [Icon Composer 文档](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)。

产品名称为“台前随屏 / StageByScreen”。Bundle ID 与用户偏好域统一为 `org.stagebyscreen.StageByScreen`，日志目录为 `Library/Logs/StageByScreen`。
