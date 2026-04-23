import 'package:flutter/foundation.dart';
import '../models/player_model.dart';
import '../database/player_dao.dart';
import '../database/game_record_dao.dart';
import '../models/game_record_model.dart';

/// 游戏状态管理 Provider（6固定角色系统）
class GameProvider extends ChangeNotifier {
  final _playerDao = PlayerDao();
  final _recordDao = GameRecordDao();

  String _currentAvatar = 'boy'; // 当前角色avatar
  List<Player> _allPlayers = []; // 所有6个角色
  bool _isLoading = false;

  String get currentAvatar => _currentAvatar;
  Player? get currentPlayer => _allPlayers.isEmpty
      ? null
      : _allPlayers.firstWhere(
          (p) => p.avatar == _currentAvatar,
          orElse: () => _allPlayers.first,
        );
  List<Player> get allPlayers => _allPlayers;
  bool get isLoading => _isLoading;

  /// 初始化：加载所有6个角色
  Future<void> loadPlayers() async {
    _isLoading = true;
    notifyListeners();

    _allPlayers = await _playerDao.getAllPlayers();

    // 确保当前角色有效
    if (_allPlayers.isNotEmpty &&
        !_allPlayers.any((p) => p.avatar == _currentAvatar)) {
      _currentAvatar = _allPlayers.first.avatar;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 切换角色（无确认，立即生效）
  void switchCharacter(String avatar) {
    if (_allPlayers.any((p) => p.avatar == avatar)) {
      _currentAvatar = avatar;
      notifyListeners();
    }
  }

  /// 选择角色（兼容旧代码）
  void selectPlayer(Player player) {
    switchCharacter(player.avatar);
  }

  /// 创建玩家（兼容旧代码，实际6角色已预置）
  Future<Player> createPlayer(String name, String avatar) async {
    // 6个角色已预置，直接返回对应角色
    final player = _allPlayers.firstWhere(
      (p) => p.avatar == avatar,
      orElse: () => _allPlayers.first,
    );
    switchCharacter(avatar);
    return player;
  }

  /// 获取排行榜（兼容旧接口）
  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    final players = await getWeeklyLeaderboard();
    return players.map((p) => {
      'avatar': p.avatar,
      'name': p.name,
      'score': p.weeklyScore,
      'total_score': p.totalScore,
      'wins': p.wins,
    }).toList();
  }

  /// 保存游戏结果
  /// - 胜利：使用传入的score（五子棋按难度：10/20/30）
  /// - 平局：总积分+5，周积分+5
  Future<void> saveGameResult({
    required String gameType,
    required int score,
    required int duration,
    required bool isWin,
    bool isDraw = false,
  }) async {
    final player = currentPlayer;
    if (player == null) return;

    // 使用传入的score作为积分增加值（五子棋根据难度已计算好）
    int addScore = score;

    // 保存记录
    final record = GameRecord(
      avatar: _currentAvatar,
      gameType: gameType,
      score: score,
      duration: duration,
      isWin: isWin,
      playedAt: DateTime.now(),
    );
    await _recordDao.insertRecord(record);

    // 更新角色统计（积分和局数）
    await _playerDao.updatePlayerScore(_currentAvatar, addScore, addScore);

    // 更新胜场
    if (isWin) {
      await _playerDao.updatePlayerWin(_currentAvatar);

      // 游戏特定统计
      if (gameType == GameType.gobang) {
        await _playerDao.updateGobangWin(_currentAvatar);
      }
    }

    // 更新2048最高分
    if (gameType == GameType.game2048 && score > 0) {
      await _playerDao.updateBest2048(_currentAvatar, score);
      await _playerDao.update2048Score(_currentAvatar, score);
    }

    // 更新消消乐最高分
    if (gameType == GameType.match3 && score > 0) {
      await _playerDao.updateBestMatch3(_currentAvatar, score);
      await _playerDao.updateMatch3Score(_currentAvatar, score);
    }

    // 更新飞行棋最高积分
    if (gameType == GameType.flyingChess && score > 0) {
      await _playerDao.updateBestFlying(_currentAvatar, score);
      await _playerDao.updateFlyingChessScore(_currentAvatar, score);
    }

    // 更新数独最快时间（胜利时）
    if (gameType == GameType.sudoku && isWin && duration > 0) {
      await _playerDao.updateBestSudoku(_currentAvatar, duration);
      await _playerDao.updateSudokuScore(_currentAvatar, duration);
    }

    // 更新翻牌最快时间（胜利时）
    if (gameType == GameType.memory && isWin && duration > 0) {
      await _playerDao.updateBestMemory(_currentAvatar, duration);
      await _playerDao.updateMemoryScore(_currentAvatar, duration);
    }

    // 更新五子棋累计积分
    if (gameType == GameType.gobang && score > 0) {
      await _playerDao.updateGobangScore(_currentAvatar, score);
    }

    // 刷新数据
    await loadPlayers();
  }

  /// 为指定玩家保存游戏结果（双人模式使用）
  Future<void> saveGameResultForPlayer({
    required String playerAvatar,
    required String gameType,
    required int score,
    required int duration,
    required bool isWin,
  }) async {
    // 使用传入的score作为积分增加值
    int addScore = score;

    // 保存记录
    final record = GameRecord(
      avatar: playerAvatar,
      gameType: gameType,
      score: score,
      duration: duration,
      isWin: isWin,
      playedAt: DateTime.now(),
    );
    await _recordDao.insertRecord(record);

    // 更新角色统计（积分和局数）
    await _playerDao.updatePlayerScore(playerAvatar, addScore, addScore);

    // 更新胜场
    if (isWin) {
      await _playerDao.updatePlayerWin(playerAvatar);

      // 游戏特定统计
      if (gameType == GameType.gobang) {
        await _playerDao.updateGobangWin(playerAvatar);
      }
    }

    // 更新飞行棋最高积分
    if (gameType == GameType.flyingChess && score > 0) {
      await _playerDao.updateBestFlying(playerAvatar, score);
      await _playerDao.updateFlyingChessScore(playerAvatar, score);
    }

    // 刷新数据
    await loadPlayers();
  }

  /// 获取总排行榜
  Future<List<Player>> getTotalLeaderboard() async {
    return _playerDao.getTotalLeaderboard();
  }

  /// 获取本周排行榜
  Future<List<Player>> getWeeklyLeaderboard() async {
    return _playerDao.getWeeklyLeaderboard();
  }

  /// 获取五子棋排行榜
  Future<List<Player>> getGobangLeaderboard() async {
    return _playerDao.getGobangLeaderboard();
  }

  /// 获取2048排行榜
  Future<List<Player>> get2048Leaderboard() async {
    return _playerDao.get2048Leaderboard();
  }

  /// 获取消消乐排行榜
  Future<List<Player>> getMatch3Leaderboard() async {
    return _playerDao.getMatch3Leaderboard();
  }

  /// 获取飞行棋排行榜
  Future<List<Player>> getFlyingChessLeaderboard() async {
    return _playerDao.getFlyingChessLeaderboard();
  }

  /// 获取数独排行榜
  Future<List<Player>> getSudokuLeaderboard() async {
    return _playerDao.getSudokuLeaderboard();
  }

  /// 获取翻牌排行榜
  Future<List<Player>> getMemoryLeaderboard() async {
    return _playerDao.getMemoryLeaderboard();
  }

  /// 获取某游戏的排行榜数据（包含总积分和游戏最佳记录）
  Future<List<Map<String, dynamic>>> getGameLeaderboard(String gameType) async {
    // 先获取按积分排序的所有玩家
    final allPlayers = await _playerDao.getTotalLeaderboard();

    switch (gameType) {
      case GameType.gobang:
        return allPlayers
            .map((p) => {
              'avatar': p.avatar,
              'name': p.name,
              'score': p.gobangWins,
              'totalScore': p.totalScore,
            })
            .toList();
      case GameType.game2048:
        return allPlayers
            .map((p) => {
              'avatar': p.avatar,
              'name': p.name,
              'score': p.best2048,
              'totalScore': p.totalScore,
            })
            .toList();
      case GameType.match3:
        return allPlayers
            .map((p) => {
              'avatar': p.avatar,
              'name': p.name,
              'score': p.bestMatch3,
              'totalScore': p.totalScore,
            })
            .toList();
      case GameType.flyingChess:
        return allPlayers
            .map((p) => {
              'avatar': p.avatar,
              'name': p.name,
              'score': p.bestFlying,
              'totalScore': p.totalScore,
            })
            .toList();
      case GameType.sudoku:
        return allPlayers
            .map((p) => {
              'avatar': p.avatar,
              'name': p.name,
              'score': p.bestSudoku,
              'totalScore': p.totalScore,
              'isTime': true, // 标记为时间类型
            })
            .toList();
      case GameType.memory:
        return allPlayers
            .map((p) => {
              'avatar': p.avatar,
              'name': p.name,
              'score': p.bestMemory,
              'totalScore': p.totalScore,
              'isTime': true, // 标记为时间类型
            })
            .toList();
      default:
        return [];
    }
  }

  /// 重置本周积分（每周一调用）
  Future<void> resetWeeklyScores() async {
    // 实际应由后台任务调用
    // 这里仅作为演示
  }
}
