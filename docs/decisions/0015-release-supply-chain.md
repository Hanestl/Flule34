# ADR-0015：Android Release 与开源供应链

- 状态：已接受
- 日期：2026-07-24

## 背景

Flule34 计划通过 GitHub 公开源码并侧载 APK。侧载绕过应用商店审核与自动签名托管，因此必须自行保证签名连续性、构建可追踪性、下载完整性和仓库 Secret 安全。

## 决策

- Android applicationId 固定为中性命名 `com.hanestl.flule34`；
- Release 构建禁止使用调试签名，缺少未跟踪的 `android/key.properties` 时直接失败；
- 正式构建输出 `armeabi-v7a`、`arm64-v8a` 和 `x86_64` 分 ABI APK；
- Release 开启 Dart 混淆并把符号文件作为受限 Actions artifact 保存；
- CI 固定 Flutter 3.44.8 和 JDK 17，执行格式、生成代码、静态分析、Android Lint、测试、Debug APK、SHA256 与敏感信息扫描；
- Windows 下若工程与 Pub 插件位于不同盘符，插件构建产物写入与源码同盘的本地缓存，避免 AGP Lint 的跨盘相对路径错误；
- Kotlin 编译使用官方支持的 `in-process` 策略，避免本机 daemon 连接失败，同时保留当前关闭跨盘增量缓存的设置；
- GitHub 官方 Action 固定到具体提交 SHA，避免浮动标签遭供应链替换；
- Tag Release 由仓库 Secrets 注入签名，生成 SHA256；公开仓库额外生成 GitHub artifact attestation；
- App 只检查构建时配置的仓库 Release，不自动安装 APK；
- 品牌图标使用仓库内 SVG 和确定性脚本生成，不依赖不可复现的外部设计源。

## 后果

- 没有正式私钥时仍可构建 Debug APK，但不能误产出 Release APK；
- 正式私钥必须由项目所有者离线生成、备份并配置为 GitHub Secrets；
- 项目主代码采用 Apache License 2.0；第三方组件继续遵循各自许可证和通知要求。

## 验证

- 本地使用临时测试密钥验证 Gradle Release 签名路径和分 ABI 输出；
- `tool/verify_release.ps1` 校验所有 Release APK 的签名与 SHA256；
- `tool/check_sensitive_files.dart` 阻止常见私钥、密钥库和会话凭据进入 Git；
- 工作流 YAML、Android 资源、静态分析、测试和 Debug/Release 构建全部纳入最终验收。
