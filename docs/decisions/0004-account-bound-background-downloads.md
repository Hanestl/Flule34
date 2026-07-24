# ADR-0004：账户绑定的 Android 后台下载

- 状态：已接受，真实设备回归仍待完成
- 日期：2026-07-24

## 背景

视频下载是首版核心能力。下载必须在 App 进入后台或进程暂停后继续执行，并且不能在账号切换时泄露另一个账号的任务、文件和观看偏好。

## 决策

### 分层

下载由三层组成：

1. `DownloadPlatformService`：平台任务、权限、通知、暂停、恢复、取消和打开文件；
2. `DownloadRepository`：账号边界、视频请求头、Drift 状态和业务错误；
3. UI：清晰度选择、下载列表和用户操作。

页面和 Repository 不直接依赖 `background_downloader` 的 Task 类型。未来替换插件时，数据库和 UI 不需要重写。

### Android 调度

- 使用 `background_downloader 9.5.6`；
- 用户点击下载创建 `priority: 0` 任务，使 Android 14+ 使用 UIDT；
- 低版本与其他情况由插件使用 WorkManager/前台服务；
- 任务请求状态和进度回调，并由插件持久化后台事件；
- App 启动时先注册回调，再调用 `FileDownloader.start()` 恢复后台状态。

### 权限与通知

Manifest 声明：

- `POST_NOTIFICATIONS`；
- `FOREGROUND_SERVICE`；
- `FOREGROUND_SERVICE_DATA_SYNC`；
- `RUN_USER_INITIATED_JOBS`。

WorkManager 的 `SystemForegroundService` 合并为 `dataSync` 类型。通知权限只在用户首次点击下载时请求，不在 App 首次启动时索取。

### 账户隔离

- 下载要求登录；
- 目录为 App 私有的 `downloads/<userId>/`；
- Drift 记录保存稳定用户 ID；
- 下载请求携带当前 Cookie、Referer 和 User-Agent；
- 退出或切换账号时，Repository 取消原账号的活动任务；
- 已完成文件和记录默认保留，但仅在原账号重新登录后显示。

### 用户界面

- 视频详情页选择清晰度后入队；
- 媒体库包含收藏和下载两个页签；
- 下载列表显示状态、进度和错误；
- 活动任务支持暂停、恢复和取消；
- 已完成任务可交给系统播放器打开。

## 已验证

- 静态分析通过；
- Fake 平台服务测试覆盖入队、账号目录、Cookie 请求头、进度落库、完成状态、权限拒绝和退出取消；
- Android Debug APK 构建成功；
- APK Manifest 已确认包含 UIDT、前台服务、通知权限与相应 Service。

## 尚未完成

1. 视频令牌在长时间暂停或重试后失效时，自动重新加载详情并重建任务；
2. 用户显式导出到公共 Downloads；
3. 下载并发数和文件保留设置；
4. API 33、34、35、36 真机/模拟器的后台、杀进程、重启、网络切换和文件清理回归；
5. Release 分 ABI 体积验证。
