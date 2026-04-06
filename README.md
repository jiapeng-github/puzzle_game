# Puzzle Game

一款基于 Flutter 开发的益智游戏合集，支持横屏显示，包含 6 款经典益智游戏。

## 功能特性

### 6 款益智游戏

| 游戏 | 描述 | 特色 |
|------|------|------|
| **五子棋** | 经典五子连珠对战 | AI 对战（3级难度）、双人对战、悔棋、计时 |
| **2048** | 数字合并挑战 | 滑动控制、高分记录、达成 2048 胜利 |
| **消消乐** | 三消益智游戏 | 8×8 网格、连击加分、目标分数 |
| **飞行棋** | 经典飞行棋 | 4人混战、特殊航点（加速/护盾/传送/陨石）、保底机制 |
| **数独** | 9×9 数字填充 | 提示功能、错误计数、连击奖励、最快时间记录 |
| **记忆翻牌** | 配对记忆游戏 | 16 张卡片配对、最快时间记录 |

### 角色系统

- 6 个可选角色：男孩、女孩、爸爸、妈妈、爷爷、奶奶
- 每个角色独立积分、胜场统计

### 排行榜系统

- **总榜**：按总积分排名
- **本周榜**：按本周积分排名
- **游戏榜**：各游戏独立排名
  - 五子棋：按胜场排名
  - 2048/消消乐/飞行棋：按最高分排名
  - 数独/翻牌：按最快用时排名

## 技术栈

- **框架**：Flutter 3.11+
- **状态管理**：Provider
- **本地数据库**：SQLite (sqflite)
- **音频**：audioplayers
- **平台**：Android、Windows

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── database/
│   ├── database_helper.dart  # 数据库初始化
│   ├── player_dao.dart       # 玩家数据操作
│   └── game_record_dao.dart  # 游戏记录操作
├── models/
│   ├── player_model.dart     # 玩家模型
│   └── game_record_model.dart # 游戏记录模型
├── providers/
│   └── game_provider.dart    # 全局状态管理
├── screens/
│   ├── home/
│   │   ├── home_screen.dart          # 首页
│   │   └── character_select_screen.dart # 角色选择
│   ├── games/
│   │   ├── gobang_screen.dart        # 五子棋
│   │   ├── game2048_screen.dart      # 2048
│   │   ├── match3_screen.dart        # 消消乐
│   │   ├── flying_chess_screen.dart  # 飞行棋
│   │   ├── sudoku_screen.dart        # 数独
│   │   └── memory_screen.dart        # 记忆翻牌
│   └── leaderboard/
│       ├── leaderboard_screen.dart   # 排行榜
│       └── full_leaderboard_screen.dart # 全屏排行榜
├── services/
│   └── audio_service.dart    # 音频服务
└── theme/
    └── app_theme.dart        # 主题配置

assets/
└── audio/
    ├── music/  # 背景音乐
    └── sfx/    # 音效
```

## 积分规则

### 五子棋
- AI 模式：入门 +10、高手 +20、大师 +30
- 双人模式：获胜 +20

### 2048
- 达成 2048：+200
- 达成 1024：+100
- 参与奖：+20

### 消消乐
- 通关：+20
- 连击奖励：+5~15

### 飞行棋
- 胜利：+50

### 数独
- 完成奖励：+50
- 时间奖励：10分钟内 +50
- 错误奖励：无错误 +50、少量错误 +30
- 连击奖励：最高 +100

### 记忆翻牌
- 通关：+10

## 运行项目

```bash
# 获取依赖
flutter pub get

# 运行项目
flutter run

# 构建 Windows 版本
flutter build windows

# 构建 Android 版本
flutter build apk
```

## 环境要求

- Flutter SDK >= 3.11.3
- Dart SDK >= 3.11.3
- Android SDK（Android 开发）
- Visual Studio（Windows 开发）

## License

MIT License
