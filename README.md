# Flule34 Android 客户端

Flule34 是基于 Flutter 的 Android 原生侧载客户端，直接使用网站已有的 JSON、HTML 和 MP4 接口，不以整站 WebView 作为主要界面。

项目正在按长期维护标准重建。产品结构、账户边界与技术决策位于 [`docs/`](docs/) 目录。

## 当前基础能力

- 成年人确认与本地记忆；
- 首页、发现、媒体库、我的四栏独立导航；
- 首页搜索入口，以及标签、分类和艺术家自动补全；
- 综合、视频、标签、艺术家和分类搜索结果；
- 搜索排序、内容取向、上传时间、时长、验证上传者和实体筛选；
- 账号隔离搜索历史，未登录不持久化匿名历史；
- 最新、热门与高评分单列视频流；
- 标签、分类、艺术家、频道、排行榜和随机探索的结构化发现浏览；
- 统一内容集合页、自动分页及最新、热门、高评分、最长和随机排序；
- 视频详情、元数据、清晰度选择和原生 MP4 播放；
- 播放器横屏沉浸式全屏、前后 10 秒、音量滑块和倍速控制；
- 播放器缓冲反馈、后台自动暂停、进度保存和返回键退出全屏；
- 视频喜欢/不喜欢、分类/标签/艺术家关联投票；
- 发表评论、页面评论展示与成功后详情刷新；
- 加入已有播放列表，以及分类和艺术家订阅/取消订阅；
- 分类、标签和艺术家实体可直接进入统一内容集合；
- 显式登录重定向与完整 CookieJar 管理；
- 使用安全存储持久化 Cookie 和稳定用户 ID；
- Drift 账户分区数据库、播放进度与下载记录 schema；
- 账号绑定的 Android 后台下载、通知、暂停、恢复与取消；
- 下载入队前刷新视频令牌、系统杀死任务恢复和公共下载目录导出；
- 媒体库下载列表、App 私有文件存储、单条删除与账号本地数据清理；
- 完整“我的”信息架构和独立设置路由；
- 已登录账号资料、头像、个人主页与网站安全管理入口；
- 帮助反馈、脱敏诊断报告、运行时版本与开源许可页面；
- 可配置 GitHub Releases 更新源、稳定/预发布通道与语义版本比较；
- 中性 Flule34 品牌图标、Android 12 启动画面和可重复生成的品牌资源；
- Release 签名门禁、分 ABI APK、SHA256、构建证明和固定 Action SHA 的 CI/CD；
- 持久化主题、播放、内容与下载偏好，并接入实际业务行为；
- 账号绑定的播放进度恢复、节流保存与视频地址失效自动刷新；
- 完整媒体库页签：继续观看、收藏、稍后观看、网站历史、播放列表、订阅和下载；
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
& 'D:\tools\flutter\bin\flutter.bat' build apk --debug
```

APK 输出位置：`build\app\outputs\flutter-apk\app-debug.apk`。

需要启用 GitHub 更新与构建追踪时，在构建命令中注入：

```powershell
& 'D:\tools\flutter\bin\flutter.bat' build apk --release `
  --dart-define=FLULE34_UPDATE_API_URL=https://api.github.com/repos/OWNER/REPOSITORY/releases `
  --dart-define=FLULE34_REPOSITORY_URL=https://github.com/OWNER/REPOSITORY `
  --dart-define=FLULE34_FLUTTER_VERSION=3.44.8 `
  --dart-define=GIT_COMMIT=<commit> `
  --dart-define=BUILD_TIME=<ISO-8601>
```

仓库尚未确定前不要提交占位地址；未配置的构建会在 App 中明确显示“未配置更新源”。

正式签名、分 ABI 构建、GitHub Secrets、证书和 SHA256 校验见 [`docs/release.md`](docs/release.md)。仓库协作、安全和隐私规则分别见 [`CONTRIBUTING.md`](CONTRIBUTING.md)、[`SECURITY.md`](SECURITY.md) 与 [`PRIVACY.md`](PRIVACY.md)。

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
- 下载失败后的自动换令牌重试和真机后台/文件清理回归仍待完成；
- 播放器真机旋转、令牌过期和复杂网络切换回归仍待完成；
- 成员资料依赖公开页面 `.channel_logo` 结构，页面变化时需更新 Parser fixture；
- 新建播放列表、评论分页/投票和稍后观看写操作仍待可靠接口证据；
- 主开源许可证仍需项目所有者明确选择；正式签名私钥也必须由项目所有者离线生成并妥善备份。
