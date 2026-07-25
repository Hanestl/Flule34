# Flule34 Android 发布流程

## 1. 一次性准备签名密钥

正式发布必须始终使用同一把私钥。密钥库、密码和 `android/key.properties` 不得提交到 Git，也不要通过聊天、Issue 或构建日志传递。

```powershell
New-Item -ItemType Directory -Force -Path 'D:\secure\flule34' | Out-Null
keytool -genkeypair `
  -keystore 'D:\secure\flule34\flule34-release.jks' `
  -alias flule34 `
  -keyalg RSA `
  -keysize 4096 `
  -validity 10000
```

把密钥库复制到本地 `android\app\release-keystore.jks`，再从 `android\key.properties.example` 创建未跟踪的 `android\key.properties`。发布前至少保留两份加密离线备份；丢失私钥后，已安装用户将无法无缝升级到新签名。

## 2. 本地 Release 构建

构建前先执行与 CI 一致的质量门：

```powershell
& 'D:\tools\flutter\bin\dart.bat' format --output=none --set-exit-if-changed lib test tool
& 'D:\tools\flutter\bin\flutter.bat' analyze --no-pub
& 'D:\tools\flutter\bin\flutter.bat' test --no-pub
& 'D:\tools\flutter\bin\dart.bat' run tool\check_sensitive_files.dart
Set-Location android
.\gradlew.bat :app:lintDebug --no-daemon
Set-Location ..
```

```powershell
$flutter = 'D:\tools\flutter\bin\flutter.bat'
$version = '1.0.0'
$buildNumber = '1'
$commit = git rev-parse HEAD
$buildTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

& $flutter build apk `
  --release `
  --split-per-abi `
  --obfuscate `
  --split-debug-info=build\symbols `
  --build-name=$version `
  --build-number=$buildNumber `
  --dart-define=FLULE34_UPDATE_API_URL=https://api.github.com/repos/OWNER/REPOSITORY/releases `
  --dart-define=FLULE34_REPOSITORY_URL=https://github.com/OWNER/REPOSITORY `
  --dart-define=FLULE34_FLUTTER_VERSION=3.44.8 `
  --dart-define=GIT_COMMIT=$commit `
  --dart-define=BUILD_TIME=$buildTime
```

输出包括 `armeabi-v7a`、`arm64-v8a` 和 `x86_64` APK。绝大多数现代手机使用 `arm64-v8a`；不确定时可提供全部文件和对应 SHA256。

## 3. 签名与完整性校验

```powershell
$buildTools = Get-ChildItem 'D:\tools\android-sdk\build-tools' -Directory |
  Sort-Object Name -Descending |
  Select-Object -First 1

& (Join-Path $buildTools.FullName 'apksigner.bat') verify `
  --verbose `
  --print-certs `
  'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk'

Get-ChildItem 'build\app\outputs\flutter-apk\*-release.apk' |
  Get-FileHash -Algorithm SHA256

# 一次检查签名、包名、ABI、ELF 调试 section 和 SHA256
.\tool\verify_release.ps1
```

首次公开发布后，把证书 SHA256 指纹记录在 GitHub Release 说明中。后续版本必须核对指纹完全一致。

## 4. GitHub Actions Secrets

Release 工作流需要以下仓库 Secrets：

- `ANDROID_KEYSTORE_BASE64`：JKS 文件的 Base64 文本；
- `ANDROID_KEYSTORE_PASSWORD`；
- `ANDROID_KEY_ALIAS`；
- `ANDROID_KEY_PASSWORD`。

Windows 生成单行 Base64：

```powershell
[Convert]::ToBase64String(
  [IO.File]::ReadAllBytes('D:\secure\flule34\flule34-release.jks')
) | Set-Clipboard
```

推送形如 `v1.0.0` 的已审核标签后，工作流会运行测试、构建分 ABI APK、生成 SHA256、生成公开仓库构建证明并创建 GitHub Release。符号文件只作为 Actions artifact 保存，不上传到公开 Release。

## 5. 发布前验收

1. `dart format`、`flutter analyze` 和全部测试通过；
2. Drift 生成文件与仓库一致；
3. 三个 Release APK 均通过 `apksigner verify`；
4. 在 Android 10、12、14、16 至少各完成一次安装/升级、登录、播放、下载、导出和退出回归；
5. 从旧版本覆盖安装后数据库迁移成功，账号数据没有串用；
6. 更新页指向当前仓库，Release APK、SHA256、版本号和签名指纹一致；
7. 检查 Release 中不包含密钥库、`key.properties`、Cookie、真实账号或符号文件。
