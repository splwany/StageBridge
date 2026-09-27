# StageBridge 开发交接

更新日期：2026-09-28。当前源码版本：`0.1.0-beta.2`，构建号 `2`。

## 当前状态

原生 Swift macOS 菜单栏工具，最低目标 macOS 14，构建 arm64/x86_64 通用 App。没有第三方库、Python 运行时或网络服务依赖。仓库为 `splwany/StageBridge`，本轮没有改变仓库可见性。

本轮修复和整理已完成：异步命令超时与取消、唤醒等待独立管理、监听失败提示、后台错误常驻提示、未知系统偏好保护、迁移中断恢复、可注入服务测试、版本统一、发行文档白名单与 CI。细节见 [更新记录](../CHANGELOG.md)。

发行仍为本地临时签名，未经 Apple 公证，不代表正式 Developer ID 发行版。没有自动更新服务。

## 必须保持的产品行为

- 只有外接显示器“有/无”变化时触发：连接关闭台前调度，断开开启。
- 连接状态不变时，尊重用户手动操作；不周期强制恢复。
- 启动、重新启用、睡眠唤醒只建立基准，不补做过去的插拔。
- 显示器事件等待稳定 2 秒；唤醒等待 3 秒。暂停再启用不能提前结束唤醒等待。
- 备用检查默认 60 秒，可选 15、30、60、120、300 秒；修改立即重建定时器，保留已经排队的显示器事件。
- 关闭设置窗口后继续菜单栏运行；退出停止监听。
- 新安装默认暂停；旧版迁移导入原启用状态。
- 控制失败不自动重试，避免延迟执行覆盖手动操作；显示错误并允许用户自行调整。

## 工程结构

见 [架构说明](ARCHITECTURE.md)。`Sources/Core` 放纯策略和睡眠状态，`Sources/App` 放 UI 与协调器，`Sources/Services` 放事件源、计时器、系统读取与控制、子进程、迁移和日志。

`Tests/CoreChecks.swift` 和 `Tests/MonitorChecks.swift` 使用隔离偏好域与临时目录。真实 Stage Manager 写入、Dock 重载和旧服务停用均不在自动化测试中执行。

## 构建和打包

```sh
./scripts/test.sh
./scripts/build.sh
./scripts/package.sh
```

若 SDK 与编译器不匹配，可显式指定实际可用的 `SDKROOT`。本机验证使用 Swift 6.2 与 macOS 15.5 SDK。不要把本机路径写死进构建脚本。

运行时版本来源为 `Resources/Info.plist`。输出为 `.build/StageBridge.app`、`dist/StageBridge-0.1.0-beta.2-universal.dmg` 与 `dist/SHA256SUMS.txt`。打包脚本从已构建 App 读版本并校对源码；源码修改后须重新构建。

Xcode 工程的源文件引用也需随新增文件更新。完整 Xcode Archive 仍需在安装完整 Xcode 的机器验证。

## 设置、迁移和安装

偏好域 `org.stagebridge.StageBridge`，键为 `Enabled`、`PollSeconds`、`LegacyMigrated` 与中断恢复键 `LegacyBackupInProgress`。日志位于 `~/Library/Logs/StageBridge/events.log`，约 512 KB 轮换。

迁移停用 `com.local.stage-manager-display-watch`，将旧 plist/py 归档到 `~/Library/Application Support/StageBridge/LegacyBackup-*`。进度在移动文件前记录，设置导入后才清除。不要重新运行会注册原型服务的旧设置 App。

区分源码、构建产物和已安装 App。升级前退出运行版本；替换安装 App 后从安装位置启动。本机既有安装位置为 `~/Applications/StageBridge.app`。

## 验证边界和后续工作

已验证项见 [TESTING.md](TESTING.md)。物理插拔、多屏、合盖、真实注销/登录、Intel 实机与跨系统验证仍需对应环境；自动化模拟不能替代这些验证。

台前调度依赖未公开承诺兼容的系统偏好。偏好回读与命令成功不能证明可见界面完成切换；未知偏好会拒绝写入。若系统升级导致失效，应修复兼容性后再扩大分发。

正式站外发行仍需发布者自己的 Developer ID、公证凭据及干净 Mac 验收，见 [DISTRIBUTION.md](DISTRIBUTION.md)。不应承诺 Mac App Store 兼容。

原始交接快照保存在 [history/HANDOFF-beta.1.md](history/HANDOFF-beta.1.md)，仅作历史参考。
