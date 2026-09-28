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

当前没有自动更新组件。用户下载新版、退出旧版、替换 App 即可；设置仍保留。未来可单独评估安全的更新渠道。
