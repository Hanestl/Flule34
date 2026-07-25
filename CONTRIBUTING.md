# 参与 Flule34 开发

感谢你帮助改进 Flule34。项目面向长期维护，提交应优先保证账号隔离、隐私、安全和可回归验证。

## 开发前

1. 阅读 `docs/product/app_information_architecture.md` 和相关 ADR；
2. 使用 Flutter 3.44.8 stable、Dart 3.12.2、JDK 17 与 Android SDK 36；
3. 不要在代码、fixture、Issue、截图或日志中提交真实账号、Cookie、下载令牌、邮箱、密码、私钥或签名文件；
4. HTML Parser 变更必须配套最小化、脱敏的 fixture 测试，不提交完整成人内容页面。

## 本地检查

```powershell
& 'D:\tools\flutter\bin\flutter.bat' pub get
& 'D:\tools\flutter\bin\dart.bat' format lib test
& 'D:\tools\flutter\bin\flutter.bat' analyze --no-pub
& 'D:\tools\flutter\bin\flutter.bat' test --no-pub
& 'D:\tools\flutter\bin\flutter.bat' build apk --debug --no-pub
```

数据库结构变化还必须更新 schema 版本、迁移、生成代码和迁移测试。品牌资源变化后运行 `python tool\generate_brand_assets.py` 并检查各密度 PNG。

## 提交与 Pull Request

- 每个提交只解决一个清晰问题，提交信息使用祈使式英文前缀，例如 `feat:`、`fix:`、`test:`、`docs:`；
- PR 说明应包含动机、行为变化、测试证据和风险；
- UI 变化附上脱敏截图；
- 不猜测未验证的网站写接口参数；
- 新增依赖必须说明用途、维护状态、许可证与 Android 权限影响；
- 不降低分析、测试、签名或敏感信息扫描门禁来“让 CI 通过”。

## 内容边界

本仓库只接受客户端工程、接口适配和必要的脱敏测试资料。禁止提交违法内容、未成年人相关内容、侵权媒体文件、真实用户私密信息或用于绕过访问控制的代码。
