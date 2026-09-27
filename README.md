# StageBridge

一个 Swift 编写的 macOS 菜单栏工具：外接显示器连接时关闭台前调度，断开时开启。

**0.1.0-beta.2 · 实验性测试版 · macOS 14+ · Apple Silicon / Intel 通用二进制**

本项目尚未发布到 Mac App Store。当前测试构建使用本地临时签名，未经 Apple 公证；正式发布流程见 [分发说明](docs/DISTRIBUTION.md)。

## 使用

1. 将 DMG 中的 StageBridge.app 拖进“应用程序”，不要直接在 DMG 中运行。
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

使用 Xcode 打开 `StageBridge.xcodeproj`。也可仅安装 Apple Command Line Tools 后运行：

```sh
./scripts/test.sh
./scripts/build.sh
./scripts/package.sh
```

构建输出为 `.build/StageBridge.app`，安装包在 `dist/`。默认生成 arm64 和 x86_64 通用版本，无第三方库或运行时依赖。如本机默认 SDK 与工具链不匹配，可显式指定 `SDKROOT` 为已安装且匹配的 SDK 路径。

贡献流程与行为约束见 [CONTRIBUTING.md](CONTRIBUTING.md) 和 [架构说明](docs/ARCHITECTURE.md)。

目录：

- `Sources/Core`：可单独验证的连接状态策略
- `Sources/App`：设置、菜单栏及监听流程协调
- `Sources/Services`：系统事件、显示器读取、命令执行、台前调度控制和迁移
- `Resources`：应用信息与图标
- `Tests`：状态策略检查
- `scripts`：构建、测试、打包、公证
- `docs`：发布、隐私、兼容性说明

## 从原型迁移

若检测到旧的 `com.local.stage-manager-display-watch` LaunchAgent，新版会暂停并显示迁移入口。点击后停止并禁用旧进程，将旧 `.plist` 和 `.py` 移到 `~/Library/Application Support/StageBridge/LegacyBackup-*`，再导入启用状态和间隔。迁移不会删除备份，也不会创建新的散装 Python 脚本。

完成迁移后，可退出并移除旧的“台前调度自动切换设置.app”。请勿同时运行旧版设置程序，否则它可能重新注册旧服务。

## 数据与许可

设置保存在用户偏好域 `org.stagebridge.StageBridge`；日志保存在 `~/Library/Logs/StageBridge`，按 512 KB 轮换。没有网络上传。详见 [隐私说明](docs/PRIVACY.md)。

采用 MIT 许可证。发布者应在首次公开发行前确认名称、Bundle ID 和署名，并使用自己的签名身份。
