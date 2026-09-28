# 台前随屏 · StageByScreen

让台前调度跟随屏幕状态自动切换：外接屏时关闭，方便多窗口并排；单独使用笔记本时开启，让小屏工作更专注。

英文名 **StageByScreen** 表达“按屏幕状态决定台前调度”。

**0.1.0-beta.4 · 实验性测试版 · macOS 14+ · Apple Silicon / Intel 通用二进制**

本项目尚未发布到 Mac App Store。当前测试构建使用本地临时签名，未经 Apple 公证；正式发布流程见 [分发说明](docs/DISTRIBUTION.md)。

## 下载

[下载 macOS 通用安装包（0.1.0-beta.4）](https://github.com/splwany/StageByScreen/releases/download/v0.1.0-beta.4/StageByScreen-0.1.0-beta.4-universal.dmg) · [全部版本与更新说明](https://github.com/splwany/StageByScreen/releases)

Apple Silicon 和 Intel 使用同一个 DMG。Release 的 Assets 中提供安装包及 SHA-256 校验文件；自动生成的 Source code 是源码，不是安装包。当前为未经苹果公证的测试版，首次打开可能被 macOS 阻止，请先阅读版本说明。

从 beta.3 及更早版本升级时，请先关闭旧版的“登录时启动”并退出。beta.4 使用新的应用标识，首次运行需重新设置自动切换和登录启动。

## 使用

1. 将 DMG 中的 台前随屏.app 拖进“应用程序”，不要直接在 DMG 中运行。
2. 首次打开默认暂停。阅读设置窗口中的测试版说明，再选择“启用自动切换”。
3. 关闭设置窗口后，程序仍在菜单栏运行。菜单栏可暂停、打开设置或退出。退出会停止全部监听。
4. “登录时启动”由 macOS 管理，可能需要在系统设置中允许。卸载前先关闭此选项并退出，然后将 App 移到废纸篓。

显示器变化优先通过 CoreGraphics 事件监听，稳定 2 秒后处理。备用检查间隔默认为 60 秒，可立即修改；不再依赖 system_profiler 或 Python。

启动、重新开启、睡眠唤醒时只建立基准，不立即更改台前调度。同一连接状态期间，用户手动开关不会被反复覆盖。睡眠期间插拔的变化在唤醒后作为新基准，不补做切换。

## 已知限制

- 台前调度控制仍采用未公开承诺兼容性的 `com.apple.WindowManager/GloballyEnabled` 偏好，切换后重载 Dock，可能造成短暂界面闪动。它不是公开的 Stage Manager 控制 API，macOS 更新后可能失效。
- 外接显示器依据 CoreGraphics 的非内置在线显示器判断。虚拟显示器、Sidecar、AirPlay 可能也被识别为外接屏；不是按 USB 扩展坞硬件识别。
- App 不请求管理员权限、辅助功能或屏幕录制权限；不采集截图，不访问网络，不含分析 SDK。
- 最低目标系统为 macOS 14；当前实际本机验证与未验证项见 [测试记录](docs/TESTING.md)。不能将编译支持等同于所有设备均已测试。

## 开发

使用 Xcode 打开 `StageByScreen.xcodeproj`。也可仅安装 Apple Command Line Tools 后运行：

```sh
./scripts/test.sh
./scripts/build.sh
./scripts/package.sh
```

构建输出为 `.build/台前随屏.app`，安装包在 `dist/`。默认生成 arm64 和 x86_64 通用版本，无第三方库或运行时依赖。如本机默认 SDK 与工具链不匹配，可显式指定 `SDKROOT` 为已安装且匹配的 SDK 路径。

贡献流程与行为约束见 [CONTRIBUTING.md](CONTRIBUTING.md) 和 [架构说明](docs/ARCHITECTURE.md)。

目录：

- `Sources/Core`：可单独验证的连接状态策略
- `Sources/App`：设置、菜单栏及监听流程协调
- `Sources/Services`：系统事件、显示器读取、命令执行、台前调度控制
- `Resources`：应用信息与图标
- `Tests`：状态策略检查
- `scripts`：构建、测试、打包、公证
- `docs`：发布、隐私、兼容性说明

## 数据与许可

设置保存在用户偏好域 `org.stagebyscreen.StageByScreen`；日志保存在 `~/Library/Logs/StageByScreen`，按 512 KB 轮换。没有网络上传。详见 [隐私说明](docs/PRIVACY.md)。

采用 MIT 许可证。发布者应在首次公开发行前确认名称、Bundle ID 和署名，并使用自己的签名身份。
