# ADR-0002：应用基础架构与核心依赖

- 状态：已接受，播放器与 Cookie 组件待专项验证
- 日期：2026-07-24
- 适用基线：Flutter 3.44.8 / Dart 3.12.2 / Android SDK 36

## 背景

现有原型由 Widget 直接调用网络接口并管理异步状态，适合验证接口，但无法可靠承载多账户、分页筛选、数据库迁移、后台下载、深链接和系统化测试。项目需要一个可以长期演进、允许替换 HTML 数据源和平台插件的基础架构。

## 总体架构

采用“按功能组织、层内职责清晰”的结构：

```text
lib/
├─ app/                       # 启动、路由、主题、全局生命周期
├─ core/                      # 错误、结果、网络、数据库、日志、通用组件
└─ features/
   └─ <feature>/
      ├─ data/                # API、HTML 解析、数据库、DTO、Repository 实现
      ├─ domain/              # 领域模型、Repository 接口、必要的用例
      └─ presentation/        # 页面、组件、ViewModel/Notifier
```

简单功能可以省略独立用例类，但不得绕过 Repository 让页面直接访问 Dio、数据库或平台插件。

## 状态管理与依赖注入

采用 `flutter_riverpod` 3.x：

- 使用 `Notifier` 和 `AsyncNotifier` 表达页面状态及命令；
- 使用 Provider 注入 Service、Repository、数据库和平台适配器；
- 测试通过 Provider override 注入 Fake；
- 页面只渲染状态和发送用户意图，不保存业务真相；
- 不在 ViewModel 中持有 `BuildContext` 或直接执行导航；
- 使用 Riverpod lint；代码生成与 Drift 共用统一的 `build_runner` 工作流。

首次接入按 2026-07-24 的稳定版本 `flutter_riverpod 3.3.2` 评估，实际修改依赖时再次运行版本与兼容性检查。

## 路由

采用 Flutter 官方维护的 `go_router`：

- `StatefulShellRoute.indexedStack` 承载首页、发现、媒体库和我的四个分支；
- 每个一级分支保留独立导航栈和页面状态；
- 搜索、观看和集合详情使用根导航器，进入后隐藏底部栏；
- 路由显式承载视频 ID、集合类型和筛选参数，支持后续深链接；
- 登录守卫只负责访问控制，不把登录逻辑写入路由配置。

首次接入按 2026-07-24 的稳定版本 `go_router 17.3.0` 评估。

## 本地数据库

采用 Drift 管理结构化本地数据：

- 账号身份与本地账号分区；
- 播放进度和待同步历史；
- 下载任务与文件索引；
- 搜索历史与筛选偏好；
- 必要的缓存元数据。

所有用户数据表必须包含稳定用户 ID 或通过外键关联账号表。每次 schema 变更必须提供迁移和迁移测试，不允许开发阶段简单删除生产数据库重新创建。

首次接入按 2026-07-24 的稳定版本 `drift 2.34.2` 评估。

`SharedPreferences` 只用于少量非敏感设备设置；Session、Cookie 或其他凭据只能进入安全存储。

## 后台下载

采用 `background_downloader`，但必须封装在自有接口之后：

```text
DownloadRepository
├─ Drift：业务记录与账户归属
└─ DownloadService：平台任务调度
   └─ background_downloader
```

选择理由：

- Android 14+ 高优先级用户下载使用 UIDT；
- 低版本使用 WorkManager/长期 Worker；
- 支持前台进度通知、暂停、恢复、取消、重试和网络约束；
- 支持 App 私有目录与显式共享存储导出；
- 能通过任务 metadata 关联自有下载记录。

首次接入按 2026-07-24 的稳定版本 `background_downloader 9.5.6` 评估。

下载实现约束：

1. UI 不直接保存插件 Task 对象作为业务状态。
2. 下载前或恢复前通过 Repository 获取新的带时效令牌视频源。
3. Session 过期后任务进入“等待登录”，不得使用其他账号凭据重试。
4. 默认保存到 App 私有目录；导出公共 Downloads 必须由用户显式触发。
5. 首次开始下载时再解释并申请通知权限，不在首次启动时索取。
6. 必须在 API 33、34、35、36 设备或模拟器上验证通知、后台存活和恢复。

## 网络与网站契约

网络层分为：

- HTTP Client：超时、Cookie、请求头、重试策略和日志脱敏；
- Site Service：请求网站页面或 JSON 接口；
- Parser：将 HTML、脚本和 JSON 转换为 DTO；
- Repository：合并远端数据、本地缓存和会话状态。

解析器必须使用脱敏真实页面 fixture 测试。任何 DOM 选择器或脚本字段变化都应在 Parser 层失败，不能把 HTML 细节泄漏到页面和领域模型。

Cookie 组件将在登录、重定向、多 Cookie、过期与持久化专项测试后确定。无论选用何种实现，都必须保存完整适用 Cookie，而不是只截取 `PHPSESSID`。

## 播放器

播放器暂不在本 ADR 中绑定具体第三方控制器。专项原型必须验证：

- 带 Referer、User-Agent 和 Cookie 的 MP4；
- 清晰度切换并保持播放位置；
- 令牌过期刷新；
- 全屏、旋转、系统返回键和生命周期；
- 长视频拖动、缓冲和错误恢复；
- 画中画的可行性。

优先评估 Flutter 官方 `video_player` 与自定义控制层；只有其无法满足核心需求时才引入更重的播放器方案。

## 测试要求

- Parser：真实脱敏 fixture 的单元测试；
- Repository：Fake Service、Fake Database 和错误映射测试；
- ViewModel：加载、刷新、分页、并发、失败和会话过期测试；
- Widget：四栏导航、登录门槛、空状态和错误状态；
- Integration：登录、浏览、播放、收藏和下载完整流程；
- Migration：每个 Drift schema 版本的迁移验证；
- Android：后台下载、进程被杀、重启、网络切换和存储不足。

## 被拒绝的方向

- 继续让 Widget 直接调用 API；
- 把所有逻辑放入全局 ChangeNotifier；
- 让下载插件自己的数据库成为业务唯一数据源；
- 使用匿名本地媒体库并在登录时尝试自动合并；
- 把完整网站放进 WebView 作为主要 App；
- 在没有迁移测试的情况下使用本地数据库。
