# Flule34 Android 客户端

Flule34 是基于 Flutter 的 Android 原生侧载客户端，直接使用网站已有的 JSON、HTML 和 MP4 接口，不以整站 WebView 作为主要界面。

项目按长期维护标准开发。产品结构、账户边界与技术决策位于 [`docs/`](docs/) 目录。

## 当前基础能力

- 首页、发现、媒体库、我的四栏独立导航；
- 首页搜索入口，以及标签、分类和艺术家自动补全；
- 综合、视频、标签、艺术家和分类搜索结果；
- 搜索排序、内容取向、上传时间、时长、验证上传者和实体筛选，支持同类严格交集、跨类型交集与排除条件；
- 最低点赞率和最低投票数客户端质量筛选，并自动继续加载后续页面；
- 账号隔离搜索历史，未登录不持久化匿名历史；
- 最新、热门、高评分与账号关注内容单列视频流；
- 首页内容取向、时长和发布时间快捷筛选；
- 标签、分类、艺术家、频道、排行榜和随机探索的结构化发现浏览与全站实体搜索；
- 统一内容集合页、自动分页及最新、热门、高评分、最长和随机排序；
- 详情页顶部固定自动播放播放器，下方信息区独立滚动；
- 两行透明控制层：左上角时间，底行统一排列播放、进度、清晰度、倍速和全屏；
- ExoPlayer 持久缓存、视频地址失效刷新、进度保存和可配置后台播放；
- 按网络类型选择清晰度、播放时屏幕常亮和可配置全屏方向；
- 视频评分、票数和分类/标签/艺术家关联票数只读展示；
- 视频分享、相关视频和卡片快捷收藏/入库/下载；
- 与账号无关的本地分类库，以及分类、艺术家和上传者订阅/取消订阅；
- 视频详情展示上传者资料入口、公开视频列表和订阅状态；
- 分类、标签和艺术家实体可直接进入统一内容集合，成员和艺术家页面显示网站头像；
- 显式登录重定向与完整 CookieJar 管理；
- 使用安全存储持久化 Cookie 和稳定用户 ID；
- Drift 账户分区数据库、播放进度与下载记录 schema；
- Android 后台下载、通知、取消、失败重试和系统杀死任务恢复；
- 下载入队前刷新视频令牌，401/403/404 自动换令牌重试；
- 下载完成后固定写入公共 `Download/Flule34`，不再要求用户选择目录；
- 下载管理会校验公共文件的存在性、可读性、文件名和体积，外部改名或删除后标记为失效；
- “我的”中的统一下载入口、并发数、Wi-Fi 策略与本机存储统计；
- 精简“我的”信息架构，保留账号、下载、调试日志、隐私、更新和关于入口；
- 已登录账号资料、头像、个人主页与网站安全管理入口；
- 脱敏诊断报告、运行时版本与开源许可页面；
- 可选的本地调试日志，支持 1～7 天保留、Dart/Flutter 与原生崩溃记录、脱敏查看和主动分享；
- 手动检查 GitHub Release、稳定/预发布通道与语义版本比较；
- 几何留白清晰的 Flule34 矢量品牌图标、Android 12 启动画面和可重复生成的品牌资源；
- Release 签名门禁、仅 arm64 APK、SHA256、构建证明和固定 Action SHA 的 CI/CD；
- 持久化主题、网络播放、隐私与下载偏好，并接入实际业务行为；
- 账号绑定的播放进度恢复、节流保存与视频地址失效自动刷新；
- 精简媒体库页签：收藏、网站历史和订阅；
- Drift v5 播放元数据、搜索历史、本地分类库与下载元数据迁移及旧数据完整性验证；
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
.\gradlew.bat :app:lintDebug
Set-Location ..
& 'D:\tools\flutter\bin\flutter.bat' build apk --debug --target-platform android-arm64
```

APK 输出位置：`build\app\outputs\flutter-apk\app-debug.apk`。

需要启用 GitHub 更新与构建追踪时，在构建命令中注入：

```powershell
& 'D:\tools\flutter\bin\flutter.bat' build apk --release `
  --target-platform android-arm64 `
  --dart-define=FLULE34_UPDATE_API_URL=https://api.github.com/repos/Hanestl/Flule34/releases `
  --dart-define=FLULE34_REPOSITORY_URL=https://github.com/Hanestl/Flule34 `
  --dart-define=FLULE34_FLUTTER_VERSION=3.44.8 `
  --dart-define=GIT_COMMIT=<commit> `
  --dart-define=BUILD_TIME=<ISO-8601>
```

未注入上述构建参数的本地开发包会在 App 中明确显示“未配置更新源”；GitHub Release 工作流会自动注入当前仓库地址。

正式签名、arm64 构建、GitHub Secrets、证书和 SHA256 校验见 [`docs/release.md`](docs/release.md)。仓库协作、安全和隐私规则分别见 [`CONTRIBUTING.md`](CONTRIBUTING.md)、[`SECURITY.md`](SECURITY.md) 与 [`PRIVACY.md`](PRIVACY.md)。

项目主代码采用 [Apache License 2.0](LICENSE)。

## Drift schema 工作流

数据库发生结构变化时必须：

1. 修改表定义、提高 `schemaVersion` 并实现迁移；
2. 运行 `dart run build_runner build`；
3. 运行 `dart run drift_dev make-migrations` 更新 schema 快照与迁移测试；
4. 运行静态分析、全部测试和 Android 构建。

当前 v1 至 v5 快照位于 `drift_schemas/app_database/`。

## 已知边界

- 列表与详情依赖 HTML 解析，页面结构变化时应更新 Parser 和真实脱敏 fixture 测试；
- 视频 URL 中的访问令牌具有时效性，播放器和下载任务必须在使用前刷新来源；
- 播放器、后台下载、固定公共下载目录和复杂网络切换仍需覆盖 Android 10–16 真机矩阵；
- `better_player_plus 1.3.4` 当前仍显式应用 Kotlin Gradle Plugin；项目固定 Flutter 3.44.8 与兼容构建配置，后续等待上游正式迁移；
- 成员资料依赖公开页面 `.channel_logo` 结构，页面变化时需更新 Parser fixture；
- App 不提供播放列表、稍后观看和用户投票写入，避免引入低价值且不稳定的账号操作；
- 正式签名私钥必须由项目所有者离线生成并妥善备份。
