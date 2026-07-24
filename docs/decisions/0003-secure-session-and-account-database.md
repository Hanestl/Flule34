# ADR-0003：安全会话、稳定用户身份与账户数据库

- 状态：已接受
- 日期：2026-07-24

## 背景

原型只从响应头截取 `PHPSESSID`，并把 Cookie 是否存在直接当作登录状态。这会丢失其他 Cookie 的域、路径、过期和安全属性，也无法为播放进度和下载任务提供稳定的账号归属。

## 决策

### Cookie

1. 使用 `PersistCookieJar` 管理完整 Cookie 集合。
2. 使用 `dio_cookie_manager` 将 CookieJar 接入 Dio。
3. 自定义 CookieJar Storage，把序列化内容写入 `flutter_secure_storage`。
4. 不把 Cookie 明文写入普通文件、SharedPreferences 或数据库。
5. 播放器开始播放前，按目标网站 URI 动态生成 Cookie 请求头。

### 登录和重定向

1. Dio 关闭自动重定向。
2. 登录 POST 后由应用最多显式跟随 5 次 3xx。
3. 每次重定向都经过 CookieManager，确保中间响应的 `Set-Cookie` 被保存。
4. 最终 HTML 必须解析到 `pageContext.userId`，否则登录失败并清理新会话。

### 稳定用户身份

1. 登录状态以服务器页面中的数字用户 ID 为准，不以 Session Cookie 是否存在为准。
2. 安全存储只保存当前活动用户 ID；个人资料元数据进入数据库。
3. 启动时加载本地身份，并尝试向网站验证。
4. 网络暂时不可用时保留本地账号，不把离线误判为退出登录。
5. 服务器成功响应但没有用户 ID 时，判定会话已过期并清除身份与 Cookie。

### Drift 数据库 v1

数据库首版包含：

- `user_accounts`：稳定用户 ID、展示信息与最近认证时间；
- `playback_positions`：按用户 ID 与视频 ID 组成复合主键；
- `download_records`：下载任务、质量、文件位置、进度、状态与错误。

播放进度和下载记录均通过外键关联账号，删除账号本地数据时级联删除。数据库启用外键、WAL、NORMAL synchronous 和 5 秒 busy timeout。

数据库 schema v1 保存于 `drift_schemas/app_database/`。未来 schema 变更必须更新版本号、生成新快照并验证旧版本数据迁移。

## 依赖版本约束

Flutter 3.44.8 的 `flutter_test` 固定了部分 Analyzer 依赖：

- `build_runner 2.15.2` 与当前 `meta` 固定版本冲突；精确使用 `2.15.1`。
- `drift_dev 2.34.1+` 需要 Analyzer 13；精确使用 `2.34.0`。
- `drift_dev 2.34.0` 的迁移 CLI 与 `drift 2.34.2` 存在内部 API 不兼容；运行时也精确使用 `drift 2.34.0`。

`drift_flutter 0.3.1` 声明的 `sqlite3_flutter_libs` 与 `sqlcipher_flutter_libs` EOL 包是无功能占位依赖，用于阻止旧版 Flutter 构建脚本被解析；实际 SQLite 由 `sqlite3` Hooks/Native Assets 提供。

## 测试要求

- 同一视频在不同用户下的播放进度不得互相覆盖。
- 删除账号本地数据必须级联清除其播放进度和下载记录。
- 用户 ID 与 Cookie 必须能够从安全存储恢复。
- 清除会话后不得保留活动身份或可发送 Cookie。
- 非数字用户 ID 不得建立会话。
