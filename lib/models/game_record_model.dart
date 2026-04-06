/// 游戏记录模型（使用avatar而非playerId）
class GameRecord {
  final int? id;
  final String avatar;   // 角色标识
  final String gameType; // 游戏类型
  final int score;       // 得分
  final int duration;    // 游戏时长(秒)
  final bool isWin;      // 是否胜利
  final DateTime playedAt;

  const GameRecord({
    this.id,
    required this.avatar,
    required this.gameType,
    required this.score,
    required this.duration,
    required this.isWin,
    required this.playedAt,
  });

  factory GameRecord.fromMap(Map<String, dynamic> map) => GameRecord(
        id: map['id'] as int?,
        avatar: map['avatar'] as String,
        gameType: map['game_type'] as String,
        score: map['score'] as int,
        duration: map['duration'] as int,
        isWin: (map['is_win'] as int) == 1,
        playedAt: DateTime.parse(map['played_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'avatar': avatar,
        'game_type': gameType,
        'score': score,
        'duration': duration,
        'is_win': isWin ? 1 : 0,
        'played_at': playedAt.toIso8601String(),
      };
}

/// 游戏类型常量
class GameType {
  static const String gobang = 'gobang';       // 五子棋
  static const String game2048 = '2048';        // 2048
  static const String match3 = 'match3';        // 消消乐
  static const String flyingChess = 'flying';   // 飞行棋
  static const String sudoku = 'sudoku';         // 数独
  static const String memory = 'memory';         // 记忆翻牌

  static const Map<String, String> names = {
    gobang: '五子棋',
    game2048: '2048',
    match3: '消消乐',
    flyingChess: '飞行棋',
    sudoku: '数独',
    memory: '记忆翻牌',
  };

  static const Map<String, String> emojis = {
    gobang: '⚫',
    game2048: '🔢',
    match3: '💎',
    flyingChess: '✈️',
    sudoku: '🔢',
    memory: '🃏',
  };

  static const Map<String, String> icons = {
    gobang: '⚫⚪',
    game2048: '2️⃣0️⃣4️⃣8️⃣',
    match3: '💎',
    flyingChess: '✈️',
    sudoku: '📝',
    memory: '🃏',
  };
}
