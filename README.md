# Flule34 Android 客户端

这是基于 Flutter 的 Android 侧载客户端。首个 MVP 使用原生 Flutter 界面，直接访问网站已有的 JSON、RSS/HTML 和 MP4 接口，不使用整站 WebView。

## 已实现

- 成年人确认与本地记忆
- 最新、热门与高评分视频列表
- 按关键词搜索和标签自动补全
- 详情页、标签元数据和清晰度选择
- 原生 MP4 播放器
- 登录、加密保存 PHPSESSID 会话、收藏与收藏列表

## 本地构建

```powershell
Set-Location D:\path\to\flule34
flutter pub get
flutter analyze
flutter build apk --debug
```

输出文件为 `build\app\outputs\flutter-apk\app-debug.apk`。

## 已知边界

- 列表与详情主要依赖 HTML 解析；站点页面结构发生变化时，应优先更新 `lib/core/api/site_parser.dart`。
- 视频 URL 中的访问令牌具有时效性；播放器进入前会重新加载视频详情页。
- 该项目尚未接入下载、评论、注册、播放列表和推送通知；这些功能应在核心浏览与播放回归测试后逐项添加。
