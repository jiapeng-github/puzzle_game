# 趣玩小岛

Flutter 离线家庭益智游戏，包含五子棋、2048、消消乐、趣味航线、数独、记忆翻牌。V2 使用独立 Dart 规则包、统一结算及 SQLite 存储，界面采用 Stitch 确认的活泼卡通风格。

## 在 VS Code 开发

1. 安装 Flutter SDK 和 Android SDK；VS Code 安装工程推荐的 Dart、Flutter 扩展。
2. 用 `Flutter: Change SDK` 选择自己的长期 Flutter 安装目录，运行 `flutter doctor -v` 检查 Android 工具链与设备。
3. 在工程根目录运行：

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

选择安卓模拟器或已开启 USB 调试的安卓设备，然后按 F5。`.vscode/launch.json` 已配置调试和性能检查入口。应用锁定横屏，保留 `com.family.puzzle_game` applicationId。

本轮验证工具链：Flutter 3.47.6 / Dart 3.13.5（macOS ARM64）。临时 SDK 位于 `/tmp/puzzle-flutter-sdk`，不作为工程固定 SDK 路径。依赖锁定文件已更新，其他 SDK 版本请先运行 `flutter pub get` 验证兼容性。

Android 构建配置为 Gradle 9.3.1、AGP 9.1.1、Kotlin Gradle Plugin 2.4.0。`compileSdk` 和 `targetSdk` 均显式设为 37（Android 17），`minSdk` 继续跟随 Flutter，升级目标版本不意味着只支持 Android 17。SDK Manager 需要安装 Android SDK Platform 37；AGP 默认 Build Tools 仍为 36.0.0。可使用 JDK 25 运行 Gradle，应用的 Java/Kotlin 字节码目标仍为 17。Gradle 的 Java 25 支持见[官方兼容表](https://docs.gradle.org/current/userguide/compatibility.html)。

Manifest 声明 `android:appCategory="game"`，符合 Android 17 对游戏保留的横屏限制例外，见[官方说明](https://developer.android.com/about/versions/17/changes/ff-restrictions-ignored)。仍需在手机、平板和分屏环境验证布局与音频前后台切换。

目前保留 Flutter 模板的 `android.newDsl=false` 和 `android.builtInKotlin=false` 兼容配置，继续使用独立 Kotlin 插件，待应用和 Android 插件统一迁移后再启用内置 Kotlin。Flutter 通常优先使用 Android Studio 自带的 JDK；如需指定其他 JDK，可运行 `flutter config --jdk-dir="你的 JDK 25 安装目录"`，此设置会影响本机其他 Flutter 工程。用 `flutter doctor -v` 核对 SDK，安装完成后用 `cd android && ./gradlew --version` 核对实际运行 JVM。

```sh
flutter build apk --debug
# 发布前需自行配置正式签名；当前 Android 工程仍沿用原调试签名配置。
```

2026-10-04 已完成 Android Debug APK 构建，并在 Android Studio 内的 Pixel Tablet API 37 ARM64 模拟器（`emulator-5554`）安装启动，确认进入六游戏大厅。构建使用 Java 25，已补齐 NDK 28.2.13676358、CMake 3.22.1，以及插件需要的 Platform 35/36。Release 构建和真机音频仍未验证。

本机首次构建遇到 Maven TLS 握手失败和 Google 存储下载慢的问题。成功运行时仅为该进程指定 TLS 1.2、清空继承的代理，并使用 [Flutter 文档列出的 CFUG 镜像](https://docs.flutter.dev/community/china)下载引擎；没有关闭证书验证或修改全局代理。以下为本机已验证的启动配置，其他机器需替换 JDK、Flutter 路径及设备 ID：

```sh
FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn \
GRADLE_OPTS="-Dorg.gradle.java.home=/Library/Java/JavaVirtualMachines/jdk-25.jdk/Contents/Home -Dhttps.protocols=TLSv1.2 -Djava.net.useSystemProxies=false -Dhttp.proxyHost= -Dhttps.proxyHost= -DsocksProxyHost= -Dhttp.nonProxyHosts=* -Dhttps.nonProxyHosts=*" \
  /Users/penn/Development/flutter/bin/flutter --no-version-check run -d emulator-5554
```

Java 25 的 `restricted method` 警告本身不代表构建失败，应查看后面的 `What went wrong`。当前使用的独立 Kotlin 插件兼容模式也会产生迁移警告，但本次 Debug 构建已通过。

Android Studio 顶栏启动已验证：`android/build.gradle.kts` 为 `io.flutter` 引擎依赖优先配置 CFUG Maven 镜像，避免 IDE 未继承终端环境变量时卡在 Google 存储下载。该仓库仅匹配 `io.flutter`，保留其余仓库及 HTTPS 校验。选择 Pixel Tablet 与 `main.dart` 后运行即可；Java native access、Kotlin 迁移和 SDK XML 警告在当前工具链仍可能出现，不等于构建失败。

## 代码结构

- `packages/puzzle_rules/`：无 Flutter/SQLite 依赖的纯 Dart 包。包含可序列化随机源、不可变规则状态、六游戏转换、数独唯一解及策略分级、奖励和榜单比较。
- `lib/v2/controller.dart`：单调时钟、暂停与恢复、异步 AI、输入串行化、存档及结算协调。
- `lib/v2/storage.dart`：SQLite v4 增量迁移、快照、事务结算、奖励账本、历史数据与设置。
- `lib/v2/app.dart`、`play.dart`、`records.dart`：大厅、角色与开局配置、六游戏、公共暂停/结算、排行榜及个人历史。
- `lib/v2/design.dart`、`boards.dart`、`illustrations.dart`：Stitch 风格的主题、组件、棋盘和原创矢量插画。
- `lib/v2/sound.dart`：按场景复用原音乐与音效，支持音量、静音及后台暂停；未映射或缺失的音效静默处理。
- `test/`：规则、事务、恢复、分组排行和横屏布局测试。

旧页面和旧积分更新入口已移除；旧实现可通过 Git 历史查阅。没有移除原音频文件。

## 规则与数据

以 [V2 规则](docs/GAME_RULES_V2.md) 为规则依据，以 [UI目录](docs/UI_V2_CATALOG.md) 为设计依据。[实现与验收记录](docs/IMPLEMENTATION_V2.md) 说明本轮验证范围。

- 正常返回大厅保存可续局，只有明确放弃才以0积分结束；每游戏最多一份活动存档。
- 角色、模式、难度、随机状态在局内冻结。系统返回和后台切换均进入遮挡盘面的暂停状态。
- 游戏成绩与家庭积分分开。结果和多人奖励同事务保存；相同结果重试返回原收据，不重复发奖。
- 周榜按上海时间周一划分，以结束时间归属；旧版总积分单独保留，不混入新版榜单。
- 升级沿用原 `puzzle_game_v2.db`，数据库版本升至4；迁移前保留 `.pre-v4` 备份以及存在的 WAL/SHM，保留原 `players` 和 `game_records` 表。
- 新账户表使用稳定角色ID `boy/girl/dad/mom/grandpa/grandma`，不再使用名字或 `hashCode`。

## 飞行棋冒险模式

新开局默认冒险，可切回经典。棋盘铺满横屏主区域，无常驻侧栏；新增加速、单次护盾与陨石格，模式分别进入游戏纪录榜。

[规则与实现说明](docs/FLIGHT_ADVENTURE_V3.md) · [Stitch 定稿与 Flutter 对照](docs/flight-v3-comparison.html)

## 视觉预览与素材

[Stitch 原稿与实际界面对照](docs/stitch-comparison.html) · [大厅实际 Flutter 截图](docs/previews/home.png) · [横屏手机数独截图](docs/previews/sudoku.png) · [消消乐截图](docs/previews/match3.png)

六个家庭头像、动物及水果图案由内置 image_gen 生成并保存在 `assets/images/stitch/`；棋盘、入口几何图案和装饰由 Flutter 绘制，不依赖联网图片。图标使用 Flutter Material Icons。Noto Sans SC、Rubik、Plus Jakarta Sans 已随应用离线打包，字体及 OFL 许可证位于 `assets/fonts/`，预览加载同一套字体。

需要重新导出实际界面截图时：

```sh
flutter test tool/preview_test.dart
```

该命令写入 `docs/previews/`；普通 `flutter test` 不会更新截图。

## 音频映射

| 场景 | 现有素材 |
| --- | --- |
| 大厅、排行 | `home_music.mp3` |
| 六款游戏 | 按顺序使用 `game1_music.mp3` 至 `game6_music.mp3` |
| 五子棋落子、2048移动 | `piece.mp3`、`move.mp3` |
| 三消、掷骰、飞机移动 | `eliminate.mp3`、`dice.mp3`、`plane.mp3` |
| 数独正确填写、翻牌/配对、完成 | `fixed.mp3`、`turn.mp3`、`right.mp3`、`winning.mp3` |

音频位于 `assets/audio/`。错误、按钮点击等无适配素材的场景暂不播放音效，不复用不合适的声音。
