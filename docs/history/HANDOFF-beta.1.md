# StageBridge 开发交接

更新日期：2026-09-27
代码基线：`e246fd7`（Initial standalone Swift StageBridge beta）
当前版本：`0.1.0-beta.1`

## 1. 项目状态

StageBridge 是原生 Swift macOS 菜单栏应用，根据外接显示器连接状态切换台前调度。已从 Python + LaunchAgent 原型迁移为独立工程，包含 Xcode 工程、命令行构建脚本和测试版 DMG 打包流程。

- 仓库：https://github.com/splwany/StageBridge，交接时为私有仓库。
- 主分支：`main`，已推送首次提交并关联 `origin/main`。
- 本机维护位置：用户“项目”目录中的 `StageBridge`。
- 最低部署目标：macOS 14；构建目标：arm64 / x86_64 通用二进制。
- Bundle ID：`org.stagebridge.StageBridge`；许可证：MIT。
- 当前构建为本地临时签名，未经 Apple 公证；没有发布 GitHub Release，也没有上架 Mac App Store。
- 无第三方库、Python 运行时或网络服务依赖。

本文件整理既有实现与验证记录；生成交接文档时没有重新构建、运行测试或改变正在运行的监听器。

## 2. 必须保留的产品行为

用户曾遇到自动检查反复覆盖手动操作的问题。核心约束是：**只有外接屏“有/无”状态发生变化才触发自动切换。**

| 情况 | 当前行为 |
| --- | --- |
| 无外接屏 → 有外接屏 | 关闭台前调度 |
| 有外接屏 → 无外接屏 | 开启台前调度 |
| 连接状态不变，用户手动切换 | 保留用户操作，不反复强制恢复 |
| App 启动、重新启用自动切换 | 只建立基准，不立即切换 |
| 睡眠或屏幕睡眠 | 跳过检查，取消待处理的切换 |
| 唤醒 | 等待 3 秒，重新建立基准；睡眠期间的插拔不补做切换 |
| 修改备用检查间隔 | 保存设置并立即重建定时器，从修改时重新计时 |
| 关闭设置窗口 | App 保持菜单栏运行，监听继续 |
| 菜单栏选择退出 | 停止监听并退出进程 |

其他约定：

- 检测外接显示器，不识别扩展坞 USB 硬件。
- 默认备用间隔 60 秒，可选 15、30、60、120、300 秒。
- 设置自动保存，不需要用户重启监听器。
- 设置窗口固定尺寸，隐藏绿色缩放按钮。
- 新安装默认暂停；原型迁移会导入旧启用状态。
- 保持原生 Swift 实现，继续为后续开源和站外分发整理工程。

## 3. 代码导览

| 文件 | 职责 |
| --- | --- |
| `Sources/App/StageBridgeApp.swift` | 入口、单实例检查、菜单栏、设置窗口生命周期和退出 |
| `Sources/App/SettingsView.swift` | SwiftUI 设置、状态展示、迁移入口、日志入口 |
| `Sources/App/Monitor.swift` | 显示器事件、备用定时器、防抖、睡眠处理、登录项、日志、迁移及台前调度控制 |
| `Sources/Core/ConnectionPolicy.swift` | 纯状态转换策略；仅连接状态变化时返回目标值 |
| `Tests/CoreChecks.swift` | 状态策略断言 |
| `Resources/Info.plist` | 版本、Bundle ID、最低系统、菜单栏应用属性 |
| `StageBridge.xcodeproj` | Xcode 工程及共享 Scheme |
| `scripts/build.sh` | 编译两个架构、合并通用二进制、签名校验 |
| `scripts/test.sh` | 编译并运行核心策略检查 |
| `scripts/package.sh` | 生成 DMG 与 SHA-256 文件 |
| `scripts/notarize.sh` | Developer ID 校验、上传公证、装订票据、重新打包 |
| `scripts/make-icon.swift` | 图标生成工具 |

## 4. 监听与切换实现

1. 通过 `CGDisplayRegisterReconfigurationCallback` 接收显示器变更，忽略开始配置阶段。
2. 事件转到主线程，采用 2 秒防抖；连续事件会重置等待时间。
3. `CGGetOnlineDisplayList` 获取在线显示器，存在 `CGDisplayIsBuiltin == 0` 的显示器即认为有外接屏。
4. `ConnectionPolicy.observe` 比较上次基准，仅在 Bool 值变化时返回 `!connected`。
5. `StageManagerControl.apply` 读取并写入 `com.apple.WindowManager` 的 `GloballyEnabled`，同步、回读后执行 `/usr/bin/killall Dock`。
6. 偏好已经等于目标值时直接返回，避免无必要的 Dock 重载。

备用 Timer 用于补查漏掉的事件，容差为间隔的 10%，上限 5 秒。它也经过 2 秒防抖。修改间隔立即替换 Timer，但不会因此立即切换台前调度，也不会清除已经排队的显示器事件。

暂停会注销显示器回调、取消 Timer 和待执行任务；再次启用会先重建基准。登录启动使用 `SMAppService.mainApp`，没有独立后台 Helper。因此退出 App 后无法继续监听。

## 5. 设置、日志与旧版本迁移

- 用户偏好域：`org.stagebridge.StageBridge`。
- 设置键：`Enabled`、`PollSeconds`、`LegacyMigrated`。
- 日志：`~/Library/Logs/StageBridge/events.log`；达到约 512 KB 后轮换为 `events.log.previous`。
- 旧服务标识：`com.local.stage-manager-display-watch`。
- 旧文件：`~/Library/LaunchAgents/com.local.stage-manager-display-watch.plist` 和同目录 `stage-manager-display-watch.py`。
- 显式点击迁移后，旧服务被停止并禁用，文件归档到 `~/Library/Application Support/StageBridge/LegacyBackup-*`，随后导入设置。

当前开发机器已完成旧版迁移，安装 App 位于 `~/Applications/StageBridge.app`。不要重新启用旧设置 App，否则可能重新注册原型服务。新源码构建不会自动替换已安装的 App，安装前先退出运行中的版本。

## 6. 构建与打包

在仓库根目录执行：

```sh
./scripts/build.sh
./scripts/package.sh
```

输出：

- `.build/StageBridge.app`
- `dist/StageBridge-0.1.0-beta.1-universal.dmg`
- `dist/SHA256SUMS.txt`

当前开发机曾遇到默认 SDK 与工具链不匹配。已成功使用的配置为：

```sh
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk ./scripts/build.sh
```

这是该机器的已知可用路径，其他机器应选择实际安装且匹配工具链的 SDK。编译脚本使用 Swift 5 语言模式；历史构建编译器为 Swift 6.2。

需要验证核心策略时执行：

```sh
./scripts/test.sh
# 若同样遇到 SDK 不匹配，可给该命令传入 SDKROOT。
```

也可使用 Xcode 打开 `StageBridge.xcodeproj`。当前记录中尚未用完整 Xcode 执行 Build/Archive。

仓库迁移时已移出包含旧绝对路径的 `.build` 缓存，后续首次构建会生成新缓存。`.build/`、`dist/`、用户 Xcode 状态、私钥和本地环境文件均不应提交。

打包采用系统临时目录暂存 App，并清除扩展属性，避免同步目录引入的元数据破坏签名。`package.sh` 会把整个 `docs/` 放入 DMG，因此不要在文档中放凭据或私人机器诊断信息。

## 7. 验证边界与已知限制

既有测试记录见 [TESTING.md](TESTING.md)。已记录通过的项目包括：两个架构编译、9 项策略断言、本机设置 UI、间隔修改、暂停/恢复、设置持久化、旧版迁移、登录项注册、临时签名校验。

仍未完成：

- 实体显示器插拔后实际台前调度切换、多屏、合盖和连接抖动测试。
- 各系统版本上内部偏好与 Dock 重载的效果。
- Intel 实机和 macOS 14 等系统运行测试。
- 完整 Xcode Build/Archive。
- 实际注销/登录自动启动、干净机器安装和卸载。
- Developer ID 签名、公证、Gatekeeper 下载后首次运行。

实现边界：

- 台前调度后端依赖未公开承诺兼容的系统偏好，系统升级后可能失效。偏好回读成功不能证明界面实际切换成功。
- 当前按“至少一块外接屏”判断；两块变一块仍为已连接，不触发切换。Sidecar、AirPlay 或虚拟屏可能也算外接屏。
- 查询失败会跳过该次处理；启动基准未知时，第一次成功读取只建立基准。
- 策略在执行切换前已经更新基准；切换失败后，同一连接状态不会自动重试。未来若添加恢复机制，必须防止重新覆盖用户手动操作。
- `ProcessRunner` 当前同步等待子进程，且丢弃标准错误；后续可改为异步、超时和更明确的错误诊断。
- 尚未测量实际长期耗电量，不能用检查间隔推算精确续航损耗。
- 没有自动更新组件，升级依靠退出旧 App 后手动替换。

## 8. 后续优先级

1. **补齐真实场景验证**：物理插拔、手动切换共存、多屏、睡眠、登录启动；记录实际系统与硬件版本。
2. **完善失败处理**：检查偏好写入失败、Dock 重载失败、系统兼容性异常时的可理解提示；谨慎设计重试策略。
3. **整理发行流程**：统一版本来源。目前版本分散在 Info.plist、设置 UI、打包/公证脚本及文档中，升级时需保持一致。
4. **完成正式签名与公证**：由发布者配置自己的证书和钥匙串公证凭据，验证另一台干净 Mac 的完整安装流程。
5. **公开与分发**：确认名称、Bundle ID 和许可署名后，再决定公开仓库及创建 GitHub Release。当前测试版未按商店要求实现，不能承诺可以上架。

发布细节见 [DISTRIBUTION.md](DISTRIBUTION.md)，数据处理说明见 [PRIVACY.md](PRIVACY.md)。

## 9. 接手检查清单

- 阅读本文件、README 和现有测试记录，再检查当前代码与 Git 状态。
- 以实际源码为准，文档中的提交和验证日期只是交接快照。
- 修改策略时保留“状态变化才触发”和“手动操作不被周期覆盖”两项约束。
- 调整运行代码后，区分源码、构建产物和已安装 App；避免同时启动多个版本。
- 按需要执行构建和验证，逐项记录完成与未完成的场景。
- 不把本地临时签名构建描述为已公证正式版本，不把编译成功描述为实机验证通过。
