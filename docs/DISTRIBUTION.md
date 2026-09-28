# 分发

## 当前分发状态

`./scripts/package.sh` 生成本地签名 DMG。它不是 Developer ID 签名，也未经苹果公证。下载到其他 Mac 后可能被 Gatekeeper 阻止。向测试者明确说明来源和状态；不要要求关闭 Gatekeeper 或其他系统安全保护。技术测试者也可以从源码自行构建。

## 正式站外发布

1. 加入 Apple Developer Program，在钥匙串中配置自己的 Developer ID Application 证书。
2. 确认应用名、Bundle ID、许可证和署名。仓库不得包含私钥、证书密码或 API 密钥。
3. 设置 `DEVELOPER_ID_APPLICATION` 为证书名称，然后运行 `./scripts/build.sh`。脚本会启用 Hardened Runtime 并附可信时间戳。
4. 用 `xcrun notarytool store-credentials` 在钥匙串保存公证凭据；不要把凭据写入脚本。
5. 设置 `NOTARY_PROFILE` 为钥匙串配置名，运行 `./scripts/notarize.sh`。该操作会上传构建到苹果，需由发布者主动执行。
6. 安装包与源码可放在 GitHub Releases，附 SHA-256、版本说明、支持系统和已知限制。发布前在另一台干净 Mac 上验证下载、安装、登录启动和卸载。

公证仅代表苹果的恶意软件检查，不保证未公开系统偏好未来兼容。Mac App Store 还要求沙盒和公开 API；本版本未按商店审核要求实现，不能承诺上架。

官方参考：
- https://developer.apple.com/macos/distribution/
- https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- https://developer.apple.com/app-store/review/guidelines/

## 维护

### 创建 GitHub Release

1. 确认对应提交的 CI 通过，运行构建与打包脚本，检查 DMG 和 SHA-256。
2. 打开仓库的 Releases → Draft a new release，为本次构建对应的提交创建版本标签，例如 `v0.1.0-beta.3`。
3. 填写版本说明、系统要求、安装步骤和已知限制。未经 Developer ID 签名和苹果公证时明确注明。
4. 上传 `dist/` 中对应版本的 DMG 和校验文件。校验文件中的文件名应与上传的安装包名称一致，不带本机目录前缀。
5. 测试版本勾选 Set as a pre-release，检查附件后发布。公开仓库的 Release 可供用户直接下载，无需克隆源码。
6. 验证未登录状态下能够访问版本和下载安装包，并更新 README 下载入口。测试版链接使用具体版本或 Releases 列表，避免依赖只定位正式版的 `/releases/latest`。

## 带自动更新的发行流程

v0.1.0 尚未包含更新器，用户需先手动安装一次带 Sparkle 的版本。后续版本使用以下流程：

1. 修改 `CFBundleShortVersionString` 与 `StageByScreenReleaseVersion`，递增 `CFBundleVersion`，在 CHANGELOG 添加对应版本章节。
2. 测试、构建、打包（使用公证时先完成 `notarize.sh`）；最终 DMG 不得在签名更新信息后修改。
3. 提交并推送 main，等待 CI 通过。
4. 运行 `python3 scripts/publish-release.py`。脚本验证本机提交与远端 main、CI 状态、包内信息以及公钥；调用钥匙串内专用签名密钥生成 `appcast.xml`，先上传 DMG、SHA256SUMS.txt 和 appcast 到草稿，再发布为 Latest。
5. 检查未登录下载，以及现有安装的“检查更新…”。发布后禁止替换附件；有修复请增加版本和构建号。

更新地址为 `https://github.com/splwany/StageByScreen/releases/latest/download/appcast.xml`。不可手工发布一个不含签名 appcast 的 Latest，否则自动检查会失败。beta/pre-release 不进入正式更新渠道。

签名密钥账户为 `org.stagebyscreen.StageByScreen`，由 Sparkle `generate_keys --account org.stagebyscreen.StageByScreen` 在登录钥匙串管理。私钥不要写入 Git、日志或命令行参数。新维护设备必须安全导入同一密钥；丢失私钥会使已安装版本无法信任后续更新。公钥在 Info.plist，脚本会检查其一致性。脚本采用现有 GitHub Git 凭据或 `GITHUB_TOKEN`，不在输出中打印凭据。

若发布中断，草稿保持不可见；检查并删除未完成草稿后重试，不要绕过资产校验直接发布。使用 `python3 scripts/make-appcast.py` 可仅生成签名订阅而不发布。
