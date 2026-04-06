import '../models/player_model.dart';
import 'database_helper.dart';

/// 玩家数据访问对象（基于6个固定角色）
class PlayerDao {
  final _db = DatabaseHelper.instance;

  /// 获取所有角色（按总积分降序）
  Future<List<Player>> getAllPlayers() async {
    final db = await _db.database;
    final maps = await db.query('players', orderBy: 'total_score DESC');
    return maps.map(Player.fromMap).toList();
  }

  /// 根据avatar获取角色
  Future<Player?> getPlayerByAvatar(String avatar) async {
    final db = await _db.database;
    final maps = await db.query(
      'players',
      where: 'avatar = ?',
      whereArgs: [avatar],
    );
    if (maps.isEmpty) return null;
    return Player.fromMap(maps.first);
  }

  /// 更新角色积分
  Future<void> updatePlayerScore(
    String avatar,
    int addTotalScore,
    int addWeeklyScore,
  ) async {
    final db = await _db.database;
    await db.rawUpdate('''
      UPDATE players
      SET total_score = total_score + ?,
          weekly_score = weekly_score + ?,
          games_played = games_played + 1
      WHERE avatar = ?
    ''', [addTotalScore, addWeeklyScore, avatar]);
  }

  /// 更新角色胜场
  Future<void> updatePlayerWin(String avatar) async {
    final db = await _db.database;
    await db.rawUpdate('''
      UPDATE players
      SET wins = wins + 1
      WHERE avatar = ?
    ''', [avatar]);
  }

  /// 更新五子棋胜场
  Future<void> updateGobangWin(String avatar) async {
    final db = await _db.database;
    await db.rawUpdate('''
      UPDATE players
      SET gobang_wins = gobang_wins + 1
      WHERE avatar = ?
    ''', [avatar]);
  }

  /// 更新2048最高分（如果更高）
  Future<void> updateBest2048(String avatar, int score) async {
    final db = await _db.database;
    await db.rawUpdate('''
      UPDATE players
      SET best_2048 = CASE WHEN best_2048 < ? THEN ? ELSE best_2048 END
      WHERE avatar = ?
    ''', [score, score, avatar]);
  }

  /// 更新消消乐最高分（如果更高）
  Future<void> updateBestMatch3(String avatar, int score) async {
    final db = await _db.database;
    await db.rawUpdate('''
      UPDATE players
      SET best_match3 = CASE WHEN best_match3 < ? THEN ? ELSE best_match3 END
      WHERE avatar = ?
    ''', [score, score, avatar]);
  }

  /// 更新飞行棋最高积分（如果更高）
  Future<void> updateBestFlying(String avatar, int score) async {
    final db = await _db.database;
    await db.rawUpdate('''
      UPDATE players
      SET best_flying = CASE WHEN best_flying < ? THEN ? ELSE best_flying END
      WHERE avatar = ?
    ''', [score, score, avatar]);
  }

  /// 更新数独最快时间（如果更快，值更小）
  Future<void> updateBestSudoku(String avatar, int seconds) async {
    final db = await _db.database;
    // 如果当前值为0（未记录）或新时间更短，则更新
    await db.rawUpdate('''
      UPDATE players
      SET best_sudoku = CASE
        WHEN best_sudoku = 0 OR best_sudoku > ? THEN ?
        ELSE best_sudoku
      END
      WHERE avatar = ?
    ''', [seconds, seconds, avatar]);
  }

  /// 更新翻牌最快时间（如果更快）
  Future<void> updateBestMemory(String avatar, int seconds) async {
    final db = await _db.database;
    await db.rawUpdate('''
      UPDATE players
      SET best_memory = CASE
        WHEN best_memory = 0 OR best_memory > ? THEN ?
        ELSE best_memory
      END
      WHERE avatar = ?
    ''', [seconds, seconds, avatar]);
  }

  /// 获取消消乐最高分排行榜
  Future<List<Player>> getMatch3Leaderboard() async {
    final db = await _db.database;
    final maps = await db.query(
      'players',
      orderBy: 'best_match3 DESC',
    );
    return maps.map(Player.fromMap).toList();
  }

  /// 获取总排行榜（按总积分降序）
  Future<List<Player>> getTotalLeaderboard() async {
    final db = await _db.database;
    final maps = await db.query(
      'players',
      orderBy: 'total_score DESC',
    );
    return maps.map(Player.fromMap).toList();
  }

  /// 获取本周排行榜（按周积分降序）
  Future<List<Player>> getWeeklyLeaderboard() async {
    final db = await _db.database;
    final maps = await db.query(
      'players',
      orderBy: 'weekly_score DESC',
    );
    return maps.map(Player.fromMap).toList();
  }

  /// 获取五子棋胜场排行榜
  Future<List<Player>> getGobangLeaderboard() async {
    final db = await _db.database;
    final maps = await db.query(
      'players',
      orderBy: 'gobang_wins DESC',
    );
    return maps.map(Player.fromMap).toList();
  }

  /// 获取2048最高分排行榜
  Future<List<Player>> get2048Leaderboard() async {
    final db = await _db.database;
    final maps = await db.query(
      'players',
      orderBy: 'best_2048 DESC',
    );
    return maps.map(Player.fromMap).toList();
  }

  /// 获取飞行棋最高积分排行榜
  Future<List<Player>> getFlyingChessLeaderboard() async {
    final db = await _db.database;
    final maps = await db.query(
      'players',
      orderBy: 'best_flying DESC',
    );
    return maps.map(Player.fromMap).toList();
  }

  /// 获取数独最快时间排行榜（升序，越小越好）
  Future<List<Player>> getSudokuLeaderboard() async {
    final db = await _db.database;
    final maps = await db.query(
      'players',
      where: 'best_sudoku > 0',
      orderBy: 'best_sudoku ASC',
    );
    return maps.map(Player.fromMap).toList();
  }

  /// 获取翻牌最快时间排行榜（升序，越小越好）
  Future<List<Player>> getMemoryLeaderboard() async {
    final db = await _db.database;
    final maps = await db.query(
      'players',
      where: 'best_memory > 0',
      orderBy: 'best_memory ASC',
    );
    return maps.map(Player.fromMap).toList();
  }
}
