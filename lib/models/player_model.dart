/// 固定角色列表（6个角色）
const List<Map<String, String>> kCharacters = [
  {'name': '男孩', 'avatar': 'boy', 'emoji': '👦'},
  {'name': '女孩', 'avatar': 'girl', 'emoji': '👧'},
  {'name': '爸爸', 'avatar': 'dad', 'emoji': '👨'},
  {'name': '妈妈', 'avatar': 'mom', 'emoji': '👩'},
  {'name': '爷爷', 'avatar': 'grandpa', 'emoji': '👴'},
  {'name': '奶奶', 'avatar': 'grandma', 'emoji': '👵'},
];

/// 角色数据模型（基于avatar而非id）
class Player {
  final String avatar;   // 角色标识（唯一）: boy/girl/dad/mom/grandpa/grandma
  final String name;     // 角色名称
  final int totalScore;  // 总积分（永久累计）
  final int weeklyScore; // 本周积分
  final int gamesPlayed; // 游戏次数
  final int wins;        // 胜场数
  final int gobangWins;  // 五子棋胜场
  final int gobangScore;  // 五子棋累计积分
  final int best2048;    // 2048最高分
  final int game2048Score; // 2048累计积分
  final int bestMatch3;  // 消消乐最高分
  final int match3Score;  // 消消乐累计积分
  final int bestFlying;  // 飞行棋最高积分
  final int flyingScore;  // 飞行棋累计积分
  final int bestSudoku;  // 数独最快时间（秒）
  final int sudokuScore;  // 数独累计积分
  final int bestMemory;  // 翻牌最快时间（秒）
  final int memoryScore;  // 翻牌累计积分

  /// 兼容旧代码的id（返回avatar的hashCode）
  int get id => avatar.hashCode;

  const Player({
    required this.avatar,
    required this.name,
    this.totalScore = 0,
    this.weeklyScore = 0,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.gobangWins = 0,
    this.gobangScore = 0,
    this.best2048 = 0,
    this.game2048Score = 0,
    this.bestMatch3 = 0,
    this.match3Score = 0,
    this.bestFlying = 0,
    this.flyingScore = 0,
    this.bestSudoku = 0,
    this.sudokuScore = 0,
    this.bestMemory = 0,
    this.memoryScore = 0,
  });

  /// 从数据库Map转换
  factory Player.fromMap(Map<String, dynamic> map) => Player(
        avatar: map['avatar'] as String,
        name: map['name'] as String,
        totalScore: map['total_score'] as int? ?? 0,
        weeklyScore: map['weekly_score'] as int? ?? 0,
        gamesPlayed: map['games_played'] as int? ?? 0,
        wins: map['wins'] as int? ?? 0,
        gobangWins: map['gobang_wins'] as int? ?? 0,
        gobangScore: map['gobang_score'] as int? ?? 0,
        best2048: map['best_2048'] as int? ?? 0,
        game2048Score: map['game2048_score'] as int? ?? 0,
        bestMatch3: map['best_match3'] as int? ?? 0,
        match3Score: map['match3_score'] as int? ?? 0,
        bestFlying: map['best_flying'] as int? ?? 0,
        flyingScore: map['flying_score'] as int? ?? 0,
        bestSudoku: map['best_sudoku'] as int? ?? 0,
        sudokuScore: map['sudoku_score'] as int? ?? 0,
        bestMemory: map['best_memory'] as int? ?? 0,
        memoryScore: map['memory_score'] as int? ?? 0,
      );

  /// 转换为数据库Map
  Map<String, dynamic> toMap() => {
        'avatar': avatar,
        'name': name,
        'total_score': totalScore,
        'weekly_score': weeklyScore,
        'games_played': gamesPlayed,
        'wins': wins,
        'gobang_wins': gobangWins,
        'gobang_score': gobangScore,
        'best_2048': best2048,
        'game2048_score': game2048Score,
        'best_match3': bestMatch3,
        'match3_score': match3Score,
        'best_flying': bestFlying,
        'flying_score': flyingScore,
        'best_sudoku': bestSudoku,
        'sudoku_score': sudokuScore,
        'best_memory': bestMemory,
        'memory_score': memoryScore,
      };

  Player copyWith({
    String? avatar,
    String? name,
    int? totalScore,
    int? weeklyScore,
    int? gamesPlayed,
    int? wins,
    int? gobangWins,
    int? gobangScore,
    int? best2048,
    int? game2048Score,
    int? bestMatch3,
    int? match3Score,
    int? bestFlying,
    int? flyingScore,
    int? bestSudoku,
    int? sudokuScore,
    int? bestMemory,
    int? memoryScore,
  }) =>
      Player(
        avatar: avatar ?? this.avatar,
        name: name ?? this.name,
        totalScore: totalScore ?? this.totalScore,
        weeklyScore: weeklyScore ?? this.weeklyScore,
        gamesPlayed: gamesPlayed ?? this.gamesPlayed,
        wins: wins ?? this.wins,
        gobangWins: gobangWins ?? this.gobangWins,
        gobangScore: gobangScore ?? this.gobangScore,
        best2048: best2048 ?? this.best2048,
        game2048Score: game2048Score ?? this.game2048Score,
        bestMatch3: bestMatch3 ?? this.bestMatch3,
        match3Score: match3Score ?? this.match3Score,
        bestFlying: bestFlying ?? this.bestFlying,
        flyingScore: flyingScore ?? this.flyingScore,
        bestSudoku: bestSudoku ?? this.bestSudoku,
        sudokuScore: sudokuScore ?? this.sudokuScore,
        bestMemory: bestMemory ?? this.bestMemory,
        memoryScore: memoryScore ?? this.memoryScore,
      );

  /// 获取角色emoji
  String get emoji {
    final char = kCharacters.firstWhere(
      (c) => c['avatar'] == avatar,
      orElse: () => kCharacters.first,
    );
    return char['emoji']!;
  }
}
