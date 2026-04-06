import '../models/game_record_model.dart';
import 'database_helper.dart';

/// 游戏记录数据访问对象（基于avatar）
class GameRecordDao {
  final _db = DatabaseHelper.instance;

  /// 插入游戏记录
  Future<int> insertRecord(GameRecord record) async {
    final db = await _db.database;
    return db.insert('game_records', record.toMap());
  }

  /// 获取角色的所有游戏记录
  Future<List<GameRecord>> getRecordsByAvatar(String avatar) async {
    final db = await _db.database;
    final maps = await db.query(
      'game_records',
      where: 'avatar = ?',
      whereArgs: [avatar],
      orderBy: 'played_at DESC',
    );
    return maps.map(GameRecord.fromMap).toList();
  }

  /// 获取某游戏的记录
  Future<List<GameRecord>> getRecordsByGame(String gameType) async {
    final db = await _db.database;
    final maps = await db.query(
      'game_records',
      where: 'game_type = ?',
      whereArgs: [gameType],
      orderBy: 'played_at DESC',
    );
    return maps.map(GameRecord.fromMap).toList();
  }

  /// 获取某游戏的最高分排行
  Future<List<Map<String, dynamic>>> getTopScoresByGame(
    String gameType, {
    int limit = 10,
  }) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT p.name, p.avatar, gr.score, gr.played_at
      FROM game_records gr
      JOIN players p ON gr.avatar = p.avatar
      WHERE gr.game_type = ?
      ORDER BY gr.score DESC
      LIMIT ?
    ''', [gameType, limit]);
  }

  /// 获取总排行榜（按总积分降序）
  Future<List<Map<String, dynamic>>> getGlobalLeaderboard({
    int limit = 20,
  }) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT avatar, name, total_score, games_played, wins
      FROM players
      ORDER BY total_score DESC
      LIMIT ?
    ''', [limit]);
  }

  /// 获取本周排行榜（基于weekly_score字段）
  Future<List<Map<String, dynamic>>> getWeeklyLeaderboard({
    int limit = 20,
  }) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT avatar, name, weekly_score, games_played, wins
      FROM players
      ORDER BY weekly_score DESC
      LIMIT ?
    ''', [limit]);
  }

  /// 获取五子棋胜场排行榜
  Future<List<Map<String, dynamic>>> getGobangLeaderboard({
    int limit = 20,
  }) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT avatar, name, gobang_wins
      FROM players
      ORDER BY gobang_wins DESC
      LIMIT ?
    ''', [limit]);
  }

  /// 获取2048最高分排行榜
  Future<List<Map<String, dynamic>>> get2048Leaderboard({
    int limit = 20,
  }) async {
    final db = await _db.database;
    return db.rawQuery('''
      SELECT avatar, name, best_2048 as score
      FROM players
      ORDER BY best_2048 DESC
      LIMIT ?
    ''', [limit]);
  }

  /// 获取角色在某游戏的最高分
  Future<int> getPlayerBestScore(String avatar, String gameType) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT MAX(score) as best
      FROM game_records
      WHERE avatar = ? AND game_type = ?
    ''', [avatar, gameType]);
    return (result.first['best'] as int?) ?? 0;
  }
}
