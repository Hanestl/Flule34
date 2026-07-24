# Flule34 Android 客户端

Flule34 是基于 Flutter 的 Android 原生侧载客户端，直接使用网站已有的 JSON、HTML 和 MP4 接口，不以整站 WebView 作为主要界面。

项目正在按长期维护标准重建。产品结构、账户边界与技术决策位于 [`docs/`](docs/) 目录。

## 当前基础能力

- 成年人确认与本地记忆；
- 首页、发现、媒体库、我的四栏独立导航；
- 首页搜索入口、标签自动补全与视频搜索；
- 最新、热门与高评分单列视频流；
- 视频详情、元数据、清晰度选择和原生 MP4 播放；
- 显式登录重定向与完整 CookieJar 管理；
- 使用安全存储持久化 Cookie 和稳定用户 ID；
- Drift 账户分区数据库、播放进度与下载记录 schema；
- 账号绑定的 Android 后台下载、通知、暂停、恢复与取消；
- 媒体库下载列表、App 私有文件存储、单条删除与账号本地数据清理；
- 完整“我的”信息架构和独立设置路由；
- 持久化主题、播放、内容与下载偏好，并接入实际业务行为；
- 账号绑定的播放进度恢复、节流保存与视频地址失效自动刷新；
- 完整媒体库页签：继续观看、收藏、稍后观看、网站历史、播放列表、订阅和下载；
- Drift v2 播放元数据迁移及旧数据完整性验证；
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

## Drift schema 工作流

数据库发生结构变化时必须：

1. 修改表定义、提高 `schemaVersion` 并实现迁移；
2. 运行 `dart run build_runner build`；
3. 运行 `dart run drift_dev make-migrations` 更新 schema 快照与迁移测试；
4. 运行静态分析、全部测试和 Android 构建。

当前 v1 快照位于 `drift_schemas/app_database/`。

## 已知边界

- 列表与详情依赖 HTML 解析，页面结构变化时应更新 Parser 和真实脱敏 fixture 测试；
- 视频 URL 中的访问令牌具有时效性，播放器和下载任务必须在使用前刷新来源；
- 下载令牌自动刷新、公共目录导出和真机后台/文件清理回归仍待完成；
- 播放器横竖屏全屏、真机令牌过期和复杂网络切换回归仍待完成；
- 账号资料解析、帮助反馈、评论、播放列表、观看历史同步和发现页数据仍在分阶段接入；
- 订阅解析、播放列表写操作和稍后观看写操作仍在分阶段接入；
- Release 签名、更新机制、CI 和 GitHub 开源交付尚未完成。
