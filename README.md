# Flule34 Android 客户端

Flule34 是基于 Flutter 的 Android 原生侧载客户端，直接使用网站已有的 JSON、HTML 和 MP4 接口，不以整站 WebView 作为主要界面。

项目按长期维护标准开发。产品结构、账户边界与技术决策位于 [`docs/`](docs/) 目录。

## 当前基础能力

- 首页、发现、媒体库、我的四栏独立导航；
- 首页搜索入口，以及标签、分类和艺术家自动补全；
- 综合、视频、标签、艺术家和分类搜索结果；
- 搜索排序、内容取向、上传时间、时长、验证上传者和实体筛选；
- 账号隔离搜索历史，未登录不持久化匿名历史；
- 最新、热门、高评分与账号关注内容单列视频流；
- 首页内容取向、时长和发布时间快捷筛选；
- 标签、分类、艺术家、频道、排行榜和随机探索的结构化发现浏览；
- 统一内容集合页、自动分页及最新、热门、高评分、最长和随机排序；
- 详情页顶部固定自动播放播放器，下方信息区独立滚动；
- 单行透明控制栏、独立清晰度/倍速选择、保持比例的沉浸式全屏；
- ExoPlayer 持久缓存、视频地址失效刷新、进度保存和可配置后台播放；
- 按网络类型选择清晰度、播放时屏幕常亮和可配置全屏方向；
- 视频喜欢/不喜欢、分类/标签/艺术家关联投票；
- 视频分享、相关视频、卡片快捷收藏/播放列表/下载和长按短预览；
- 加入已有播放列表，以及分类和艺术家订阅/取消订阅；
- 分类、标签和艺术家实体可直接进入统一内容集合；
- 显式登录重定向与完整 CookieJar 管理；
- 使用安全存储持久化 Cookie 和稳定用户 ID；
- Drift 账户分区数据库、播放进度与下载记录 schema；
- Android 后台下载、通知、暂停、恢复、取消和系统杀死任务恢复；
- 下载入队前刷新视频令牌，401/403/404 自动换令牌重试；
- 直接写入公共/自选目录，默认显示为 `Downloads/Flule34`；
- “我的”中的下载管理、可配置并发数、Wi-Fi 策略与本机存储统计；
- 完整“我的”信息架构和独立设置路由；
- 已登录账号资料、头像、个人主页与网站安全管理入口；
- 帮助反馈、脱敏诊断报告、运行时版本与开源许可页面；
- 冷启动自动检查 GitHub Release、稳定/预发布通道与语义版本比较；
- 中性 Flule34 品牌图标、Android 12 启动画面和可重复生成的品牌资源；
- Release 签名门禁、分 ABI APK、SHA256、构建证明和固定 Action SHA 的 CI/CD；
- 持久化主题、网络播放、内容预览、隐私与下载偏好，并接入实际业务行为；
- 账号绑定的播放进度恢复、节流保存与视频地址失效自动刷新；
- 完整媒体库页签：继续观看、收藏、稍后观看、网站历史、播放列表和订阅；
- Drift v3 播放元数据与搜索历史迁移及旧数据完整性验证；
- 单列视频流下拉刷新与接近底部自动分页；
- 收藏和账号媒体库基础能力。

## 开发环境

当前已验证环境：

- Flutter 3.44.8 stable；
- Dart 3.12.2；
- Android SDK 36；
- minSdk 24，targetSdk 36。

## 本地构建

```powershell
Set-Location D:\path\to\flule34
& 'D:\tools\flutter\bin\flutter.bat' pub get
& 'D:\tools\flutter\bin\dart.bat' run build_runner build
& 'D:\tools\flutter\bin\flutter.bat' analyze
& 'D:\tools\flutter\bin\flutter.bat' test
Set-Location android
.\gradlew.bat :app:lintDebug --no-daemon
Set-Location ..
& 'D:\tools\flutter\bin\flutter.bat' build apk --debug
```

APK 输出位置：`build\app\outputs\flutter-apk\app-debug.apk`。

需要启用 GitHub 更新与构建追踪时，在构建命令中注入：

```powershell
& 'D:\tools\flutter\bin\flutter.bat' build apk --release `
  --dart-define=FLULE34_UPDATE_API_URL=https://api.github.com/repos/Hanestl/Flule34/releases `
  --dart-define=FLULE34_REPOSITORY_URL=https://github.com/Hanestl/Flule34 `
  --dart-define=FLULE34_FLUTTER_VERSION=3.44.8 `
  --dart-define=GIT_COMMIT=<commit> `
  --dart-define=BUILD_TIME=<ISO-8601>
```

未注入上述构建参数的本地开发包会在 App 中明确显示“未配置更新源”；GitHub Release 工作流会自动注入当前仓库地址。

正式签名、分 ABI 构建、GitHub Secrets、证书和 SHA256 校验见 [`docs/release.md`](docs/release.md)。仓库协作、安全和隐私规则分别见 [`CONTRIBUTING.md`](CONTRIBUTING.md)、[`SECURITY.md`](SECURITY.md) 与 [`PRIVACY.md`](PRIVACY.md)。

项目主代码采用 [Apache License 2.0](LICENSE)。

## Drift schema 工作流

数据库发生结构变化时必须：

1. 修改表定义、提高 `schemaVersion` 并实现迁移；
2. 运行 `dart run build_runner build`；
3. 运行 `dart run drift_dev make-migrations` 更新 schema 快照与迁移测试；
4. 运行静态分析、全部测试和 Android 构建。

当前 v1、v2 和 v3 快照位于 `drift_schemas/app_database/`。

## 已知边界

- 列表与详情依赖 HTML 解析，页面结构变化时应更新 Parser 和真实脱敏 fixture 测试；
- 视频 URL 中的访问令牌具有时效性，播放器和下载任务必须在使用前刷新来源；
- 播放器、后台下载、SAF 公共目录和复杂网络切换仍需覆盖 Android 10–16 真机矩阵；
- `better_player_plus 1.3.4` 当前仍显式应用 Kotlin Gradle Plugin；未来升级 Flutter/AGP 时需确认其已迁移到内建 Kotlin；
- 成员资料依赖公开页面 `.channel_logo` 结构，页面变化时需更新 Parser fixture；
- 新建播放列表和稍后观看写操作仍待可靠接口证据；App 不会猜测参数修改账号数据；
- 正式签名私钥必须由项目所有者离线生成并妥善备份。
