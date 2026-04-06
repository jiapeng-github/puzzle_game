import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/player_model.dart';
import '../../models/game_record_model.dart';
import '../../services/audio_service.dart';

/// 五子棋游戏页面 - 新中式禅意风格（完整升级版）
class GobangScreen extends StatefulWidget {
  const GobangScreen({super.key});

  @override
  State<GobangScreen> createState() => _GobangScreenState();
}

class _GobangScreenState extends State<GobangScreen>
    with TickerProviderStateMixin {
  static const int boardSize = 15;
  final GlobalKey _boardKey = GlobalKey();

  // 游戏状态
  late List<List<int>> _board;
  bool _isPlayerTurn = true;
  bool _gameOver = false;
  int _winner = 0;
  late DateTime _startTime;
  bool _hasStarted = false; // 是否已开始落子

  // 模式与难度
  bool _isAiMode = true;
  int _aiDifficulty = 0; // 0=入门, 1=高手, 2=大师
  final List<String> _difficultyNames = ['入门', '高手', '大师'];
  final List<Color> _difficultyColors = [
    const Color(0xFF4CAF50), // 入门-绿
    const Color(0xFFFF9800), // 高手-橙
    const Color(0xFFF44336), // 大师-红
  ];

  // 双人模式对手
  Player? _opponent;

  // 再来一局时互换先手
  bool _swapSides = false;

  // 悔棋
  int _blackUndoCount = 1;
  int _whiteUndoCount = 1;
  List<_Move> _history = [];

  // 计时
  bool _timerEnabled = true;
  int _blackTime = 0;
  int _whiteTime = 0;


  // 步数统计
  int _blackSteps = 0;
  int _whiteSteps = 0;

  // 动画
  late AnimationController _pieceAnimController;
  late AnimationController _breathController;
  late AnimationController _dropAnimController;
  late AnimationController _glowController;
  Offset? _lastMovePos;
  List<Offset> _winningLine = [];

  // 悬停预览
  Offset? _hoverPos;
  bool _isHoverValid = false;

  // 粒子动画
  final List<_Particle> _particles = [];

  // 积分动画
  int _displayScore = 0;
  int _targetScore = 0;

  @override
  void initState() {
    super.initState();
    _pieceAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _dropAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _initBoard();
    _startTimer();
  }

  @override
  void dispose() {
    _pieceAnimController.dispose();
    _breathController.dispose();
    _dropAnimController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _gameOver) return;
      setState(() {
        if (_timerEnabled) {
          if (_isPlayerTurn) {
            _blackTime++;
          } else {
            _whiteTime++;
          }
        }
      });
      _startTimer();
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _initBoard() {
    _board = List.generate(boardSize, (_) => List.filled(boardSize, 0));
    _isPlayerTurn = true;
    _gameOver = false;
    _winner = 0;
    _blackUndoCount = 1;
    _whiteUndoCount = 1;
    _history = [];
    _blackTime = 0;
    _whiteTime = 0;
    _blackSteps = 0;
    _whiteSteps = 0;
    _lastMovePos = null;
    _winningLine = [];
    _particles.clear();
    _hasStarted = false;
    _startTime = DateTime.now();
  }

  // 获取当前玩家
  Player? get _currentPlayer => context.read<GameProvider>().currentPlayer;

  void _onTap(int row, int col) {
    if (_gameOver || _board[row][col] != 0) return;

    if (!_hasStarted) _hasStarted = true;

    // 双人模式下，轮流落子
    if (!_isAiMode) {
      _placePiece(row, col, _isPlayerTurn ? 1 : 2);
      return;
    }

    // AI模式：只有黑方（玩家）可以落子
    if (!_isPlayerTurn) return;
    _placePiece(row, col, 1);

    if (!_gameOver) {
      final delay = switch (_aiDifficulty) {
        0 => 300, // 入门-快
        1 => 600, // 高手-中等
        2 => 900, // 大师-慢
        _ => 500,
      };
      Future.delayed(Duration(milliseconds: delay), _aiMove);
    }
  }

  void _placePiece(int row, int col, int player) {
    setState(() {
      _board[row][col] = player;
      _history.add(_Move(row, col, player));
      _lastMovePos = Offset(col.toDouble(), row.toDouble());

      if (player == 1) {
        _blackSteps++;
      } else {
        _whiteSteps++;
      }

      // 播放落子音效
      AudioService().playPieceSfx();

      _dropAnimController.forward(from: 0);
      _pieceAnimController.forward(from: 0);

      final winLine = _checkWin(row, col, player);
      if (winLine != null) {
        _gameOver = true;
        _winner = player;
        _winningLine = winLine;
        _generateParticles();
        _calculateAndShowResult();
        return;
      }

      if (_isBoardFull()) {
        _gameOver = true;
        _calculateAndShowResult();
        return;
      }

      _isPlayerTurn = !_isPlayerTurn;
    });
  }

  List<Offset>? _checkWin(int row, int col, int player) {
    final dirs = const [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1]
    ];
    for (final d in dirs) {
      List<Offset> line = [Offset(col.toDouble(), row.toDouble())];
      for (int i = 1; i < 5; i++) {
        final nr = row + d[0] * i;
        final nc = col + d[1] * i;
        if (_inBounds(nr, nc) && _board[nr][nc] == player) {
          line.add(Offset(nc.toDouble(), nr.toDouble()));
        } else {
          break;
        }
      }
      for (int i = 1; i < 5; i++) {
        final nr = row - d[0] * i;
        final nc = col - d[1] * i;
        if (_inBounds(nr, nc) && _board[nr][nc] == player) {
          line.add(Offset(nc.toDouble(), nr.toDouble()));
        } else {
          break;
        }
      }
      if (line.length >= 5) return line;
    }
    return null;
  }

  bool _isBoardFull() {
    for (final row in _board) {
      if (row.contains(0)) return false;
    }
    return true;
  }

  bool _inBounds(int r, int c) =>
      r >= 0 && r < boardSize && c >= 0 && c < boardSize;

  void _generateParticles() {
    _particles.clear();
    for (final pos in _winningLine) {
      for (int i = 0; i < 10; i++) {
        _particles.add(_Particle(
          position: pos,
          angle: (i / 10) * 2 * math.pi,
          speed: 0.8 + (i % 4) * 0.4,
          size: 4.0 + (i % 5),
        ));
      }
    }
  }

  // ==================== AI 算法 ====================

  void _aiMove() {
    if (_gameOver) return;

    final pos = switch (_aiDifficulty) {
      0 => _aiRandomMove(),
      1 => _aiAdvancedMove(),
      2 => _aiMasterMove(),
      _ => _aiRandomMove(),
    };

    _placePiece(pos.$1, pos.$2, 2);
  }

  // 入门：随机落子 + 简单防守
  (int, int) _aiRandomMove() {
    // 先检查是否需要防守（玩家连四）
    final blockPos = _findThreat(1, 4);
    if (blockPos != null) return blockPos;

    // 再找附近有空位的位置
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (_board[r][c] == 0 && _hasNeighbor(r, c)) {
          // 30%概率随机跳过，增加不确定性
          if (math.Random().nextDouble() > 0.3) return (r, c);
        }
      }
    }

    // 中心附近
    return (boardSize ~/ 2, boardSize ~/ 2);
  }

  // 高手：3层搜索 + 基础进攻
  (int, int) _aiAdvancedMove() {
    // 检查自己能否连五
    final winPos = _findThreat(2, 5);
    if (winPos != null) return winPos;

    // 防守玩家连五
    final blockPos = _findThreat(1, 5);
    if (blockPos != null) return blockPos;

    // 进攻连四
    final attack4 = _findThreat(2, 4);
    if (attack4 != null) return attack4;

    // 防守连四
    final block4 = _findThreat(1, 4);
    if (block4 != null) return block4;

    // 评分选择最佳位置
    return _findBestScoredMove();
  }

  // 大师：5层搜索 + 杀棋识别
  (int, int) _aiMasterMove() {
    // 杀棋识别
    final killerMove = _findKillerMove();
    if (killerMove != null) return killerMove;

    // 检查自己能否连五
    final winPos = _findThreat(2, 5);
    if (winPos != null) return winPos;

    // 防守玩家连五
    final blockPos = _findThreat(1, 5);
    if (blockPos != null) return blockPos;

    // 进攻活四
    final attack4 = _findOpenFour(2);
    if (attack4 != null) return attack4;

    // 防守活四
    final block4 = _findOpenFour(1);
    if (block4 != null) return block4;

    // 进攻冲四
    final rush4 = _findThreat(2, 4);
    if (rush4 != null) return rush4;

    // 防守冲四
    final blockRush4 = _findThreat(1, 4);
    if (blockRush4 != null) return blockRush4;

    // 深度评分搜索
    return _deepSearchMove(3);
  }

  // 寻找杀棋（必胜局面）
  (int, int)? _findKillerMove() {
    // 检查是否有双四或四三杀棋
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (_board[r][c] != 0) continue;

        int fourCount = 0;
        int threeCount = 0;

        final dirs = const [
          [0, 1],
          [1, 0],
          [1, 1],
          [1, -1]
        ];

        for (final d in dirs) {
          final count = _countInDirection(r, c, 2, d[0], d[1]);
          if (count >= 4) fourCount++;
          else if (count == 3 && _isOpen(r, c, d[0], d[1], 2)) threeCount++;
        }

        if (fourCount >= 2 || (fourCount >= 1 && threeCount >= 1)) {
          return (r, c);
        }
      }
    }
    return null;
  }

  int _countInDirection(int r, int c, int player, int dr, int dc) {
    int count = 1;
    int nr = r + dr, nc = c + dc;
    while (_inBounds(nr, nc) && _board[nr][nc] == player) {
      count++;
      nr += dr;
      nc += dc;
    }
    nr = r - dr;
    nc = c - dc;
    while (_inBounds(nr, nc) && _board[nr][nc] == player) {
      count++;
      nr -= dr;
      nc -= dc;
    }
    return count;
  }

  bool _isOpen(int r, int c, int dr, int dc, int player) {
    int nr = r + dr, nc = c + dc;
    while (_inBounds(nr, nc) && _board[nr][nc] == player) {
      nr += dr;
      nc += dc;
    }
    if (!_inBounds(nr, nc) || _board[nr][nc] != 0) return false;

    nr = r - dr;
    nc = c - dc;
    while (_inBounds(nr, nc) && _board[nr][nc] == player) {
      nr -= dr;
      nc -= dc;
    }
    return _inBounds(nr, nc) && _board[nr][nc] == 0;
  }

  (int, int)? _findOpenFour(int player) {
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (_board[r][c] != 0) continue;
        final dirs = const [
          [0, 1],
          [1, 0],
          [1, 1],
          [1, -1]
        ];
        for (final d in dirs) {
          if (_countInDirection(r, c, player, d[0], d[1]) >= 4 &&
              _isOpen(r, c, d[0], d[1], player)) {
            return (r, c);
          }
        }
      }
    }
    return null;
  }

  (int, int) _deepSearchMove(int depth) {
    int bestScore = -999999;
    (int, int)? bestPos;

    // 生成候选位置
    final candidates = _generateCandidates();

    for (final pos in candidates) {
      final score = _evaluatePosition(pos.$1, pos.$2, depth);
      if (score > bestScore) {
        bestScore = score;
        bestPos = pos;
      }
    }

    return bestPos ?? (boardSize ~/ 2, boardSize ~/ 2);
  }

  List<(int, int)> _generateCandidates() {
    final candidates = <(int, int)>[];
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (_board[r][c] == 0 && _hasNeighbor(r, c)) {
          candidates.add((r, c));
        }
      }
    }
    // 按评分排序，只取前20个
    candidates.sort((a, b) =>
        _quickEvaluate(b.$1, b.$2).compareTo(_quickEvaluate(a.$1, a.$2)));
    return candidates.take(20).toList();
  }

  int _quickEvaluate(int r, int c) {
    return _evaluatePoint(r, c, 2) + _evaluatePoint(r, c, 1);
  }

  int _evaluatePosition(int r, int c, int depth) {
    // 模拟落子
    _board[r][c] = 2;
    final attackScore = _evaluatePoint(r, c, 2) * 2;
    _board[r][c] = 0;

    // 评估防守
    _board[r][c] = 1;
    final defenseScore = _evaluatePoint(r, c, 1);
    _board[r][c] = 0;

    return attackScore + defenseScore;
  }

  int _evaluatePoint(int r, int c, int player) {
    int score = 0;
    final dirs = const [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1]
    ];

    for (final d in dirs) {
      final count = _countInDirection(r, c, player, d[0], d[1]);
      final open = _isOpen(r, c, d[0], d[1], player);

      if (count >= 5) score += 100000;
      else if (count == 4 && open) score += 10000;
      else if (count == 4) score += 1000;
      else if (count == 3 && open) score += 1000;
      else if (count == 3) score += 100;
      else if (count == 2 && open) score += 100;
      else if (count == 2) score += 10;
    }

    // 位置权重（中心加分）
    final centerDist = (r - boardSize ~/ 2).abs() + (c - boardSize ~/ 2).abs();
    score += (10 - centerDist) * 5;

    return score;
  }

  (int, int) _findBestScoredMove() {
    int bestScore = -1;
    (int, int)? bestPos;

    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (_board[r][c] != 0) continue;
        final score = _evaluatePoint(r, c, 2) + _evaluatePoint(r, c, 1) ~/ 2;
        if (score > bestScore) {
          bestScore = score;
          bestPos = (r, c);
        }
      }
    }

    return bestPos ?? (boardSize ~/ 2, boardSize ~/ 2);
  }

  (int, int)? _findThreat(int player, int count) {
    final dirs = const [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1]
    ];
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (_board[r][c] != 0) continue;
        for (final d in dirs) {
          if (_countInDirection(r, c, player, d[0], d[1]) >= count) {
            return (r, c);
          }
        }
      }
    }
    return null;
  }

  bool _hasNeighbor(int r, int c) {
    for (int dr = -2; dr <= 2; dr++) {
      for (int dc = -2; dc <= 2; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = r + dr;
        final nc = c + dc;
        if (_inBounds(nr, nc) && _board[nr][nc] != 0) return true;
      }
    }
    return false;
  }

  // ==================== 悔棋与提示 ====================

  void _showUndoConfirm() {
    final canUndo = _isAiMode
        ? (_isPlayerTurn && _blackUndoCount > 0 && _history.length >= 2)
        : ((_isPlayerTurn && _blackUndoCount > 0) ||
            (!_isPlayerTurn && _whiteUndoCount > 0));

    if (!canUndo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('本局已使用悔棋次数'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF8B6914),
        ),
      );
      return;
    }

    final remainingCount = _isPlayerTurn ? _blackUndoCount : _whiteUndoCount;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFFF8F4E8),
        title: const Text(
          '确认悔棋',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3D2914),
          ),
        ),
        content: Text(
          '确定要悔棋吗？剩余次数: $remainingCount',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Color(0xFF5D4037)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消', style: TextStyle(color: Color(0xFF8B6914))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _undo();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _undo() {
    if (_gameOver || _history.isEmpty) return;

    if (_isAiMode) {
      if (_history.length < 2) return;
      if (_blackUndoCount <= 0) return;

      setState(() {
        final last1 = _history.removeLast();
        _board[last1.row][last1.col] = 0;
        if (last1.player == 2) _whiteSteps--;
        final last2 = _history.removeLast();
        _board[last2.row][last2.col] = 0;
        if (last2.player == 1) _blackSteps--;
        _blackUndoCount = 0;
        _isPlayerTurn = true;
        _lastMovePos = _history.isNotEmpty
            ? Offset(_history.last.col.toDouble(), _history.last.row.toDouble())
            : null;
      });
    } else {
      final canUndo = _isPlayerTurn ? _blackUndoCount > 0 : _whiteUndoCount > 0;
      if (!canUndo) return;

      setState(() {
        final last = _history.removeLast();
        _board[last.row][last.col] = 0;
        if (last.player == 1) _blackSteps--;
        if (last.player == 2) _whiteSteps--;
        if (_isPlayerTurn) {
          _blackUndoCount = 0;
        } else {
          _whiteUndoCount = 0;
        }
        _isPlayerTurn = !_isPlayerTurn;
        _lastMovePos = _history.isNotEmpty
            ? Offset(_history.last.col.toDouble(), _history.last.row.toDouble())
            : null;
      });
    }
  }

  // ==================== 积分与结算 ====================

  void _calculateAndShowResult() {
    final currentPlayer = _currentPlayer;
    if (currentPlayer == null) return;

    int scoreChange = 0;
    bool isWin = false;
    String resultTitle;
    String resultSubtitle;

    if (_winner == 0) {
      // 平局
      resultTitle = '🤝 平局';
      resultSubtitle = '旗鼓相当';
      scoreChange = 5; // 平局给少量积分
    } else if (_isAiMode) {
      // 单人AI模式 - 根据难度差异化积分
      if (_winner == 1) {
        // 玩家获胜，根据AI难度给分
        isWin = true;
        resultTitle = '🎉 获胜！';
        resultSubtitle = '战胜 ${_difficultyNames[_aiDifficulty]}电脑';
        // 难度积分：入门+10，高手+20，大师+30
        scoreChange = switch (_aiDifficulty) {
          0 => 10,  // 入门
          1 => 20,  // 高手
          2 => 30,  // 大师
          _ => 10,
        };
      } else {
        // 玩家失败，不给积分
        resultTitle = '😔 惜败';
        resultSubtitle = '再接再厉';
        scoreChange = 0;
      }
    } else {
      // 双人对战模式 - 对称积分规则
      // 获胜方 +20 分，失败方 +0 分
      isWin = _isCurrentPlayerWinner();
      if (_winner != 0) {
        resultTitle = '🎉 获胜！';
        resultSubtitle = '技高一筹';
        scoreChange = 20; // 获胜方固定 +20 分
      } else {
        resultTitle = '😔 惜败';
        resultSubtitle = '下次加油';
        scoreChange = 0;
      }
    }

    _targetScore = scoreChange;
    _displayScore = 0;
    _saveResult(isWin);
    _showResultDialog(resultTitle, resultSubtitle, scoreChange, isWin);
  }

  Future<void> _saveResult(bool isWin) async {
    final duration = DateTime.now().difference(_startTime).inSeconds;

    if (_isAiMode) {
      // 单人AI模式：只给人类玩家加分
      await context.read<GameProvider>().saveGameResult(
            gameType: GameType.gobang,
            score: _targetScore,
            duration: duration,
            isWin: isWin,
          );
    } else {
      // 双人模式：给获胜方加分
      if (_winner != 0) {
        // 判断获胜方是谁
        String winnerAvatar;

        if (_swapSides) {
          // 互换后：黑方=对手，白方=当前玩家
          winnerAvatar = (_winner == 1) ? (_opponent?.avatar ?? 'girl') : (_currentPlayer?.avatar ?? 'boy');
        } else {
          // 未互换：黑方=当前玩家，白方=对手
          winnerAvatar = (_winner == 1) ? (_currentPlayer?.avatar ?? 'boy') : (_opponent?.avatar ?? 'girl');
        }

        // 只给获胜方加分（+20分）
        await context.read<GameProvider>().saveGameResultForPlayer(
              playerAvatar: winnerAvatar,
              gameType: GameType.gobang,
              score: 20,
              duration: duration,
              isWin: true,
            );
      }
    }
  }

  // 判断当前玩家是否获胜（考虑互换先手）
  bool _isCurrentPlayerWinner() {
    if (_winner == 0) return false;

    // 在双人模式互换先手后：
    // 如果_swapSides=true，黑方是原来的对手，白方是原来的玩家
    // _winner=1 表示黑方获胜，_winner=2 表示白方获胜
    if (_swapSides) {
      return _winner == 2; // 白方获胜时，原来的玩家获胜
    } else {
      return _winner == 1; // 黑方获胜时，原来的玩家获胜
    }
  }

  void _showResultDialog(String title, String subtitle, int scoreChange, bool isWin) {
    // 播放结算音效
    AudioService().playWinningSfx();

    // 获取获胜玩家信息
    String winnerName;
    String winnerAvatar;
    String winMessage = ''; // 获胜提示信息
    if (_winner == 0) {
      winnerName = '平局';
      winnerAvatar = '';
      winMessage = '旗鼓相当';
    } else if (_isAiMode) {
      // AI模式
      if (_winner == 1) {
        winnerName = _currentPlayer?.name ?? '玩家';
        winnerAvatar = _currentPlayer?.avatar ?? 'boy';
        winMessage = '战胜${_difficultyNames[_aiDifficulty]}电脑！';
      } else {
        winnerName = '电脑-${_difficultyNames[_aiDifficulty]}';
        winnerAvatar = 'robot';
        winMessage = '再接再厉';
      }
    } else {
      // 双人模式，考虑互换先手
      if (_winner == 1) {
        // 黑方获胜
        if (_swapSides) {
          winnerName = _opponent?.name ?? '玩家2';
          winnerAvatar = _opponent?.avatar ?? 'girl';
        } else {
          winnerName = _currentPlayer?.name ?? '玩家';
          winnerAvatar = _currentPlayer?.avatar ?? 'boy';
        }
      } else {
        // 白方获胜
        if (_swapSides) {
          winnerName = _currentPlayer?.name ?? '玩家';
          winnerAvatar = _currentPlayer?.avatar ?? 'boy';
        } else {
          winnerName = _opponent?.name ?? '玩家2';
          winnerAvatar = _opponent?.avatar ?? 'girl';
        }
      }
      winMessage = '$winnerName 获胜！'; // 双人模式显示"xxx获胜！"
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          // 在弹窗创建后启动积分动画
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (scoreChange > 0 && _displayScore == 0) {
              _animateScore(scoreChange, setDialogState);
            }
          });

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: const Color(0xFFF8F4E8),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 获胜玩家信息
                if (_winner != 0) ...[
                  // 庆祝效果 - 金色光环
                  AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.4 + (_glowController.value * 0.3)),
                              blurRadius: 20 + (_glowController.value * 10),
                              spreadRadius: 5 + (_glowController.value * 5),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFFDEB887),
                          child: _buildAvatar(winnerAvatar, 80),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    winnerName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3D2914),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    winMessage,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isWin ? const Color(0xFFFFD700) : const Color(0xFF5D4037).withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                // 结果标题
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3D2914),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color(0xFF5D4037).withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
                // 积分动画
                if (scoreChange > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.white, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          '积分 +$_displayScore',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                // 统计信息
                _buildResultStats(),
                const SizedBox(height: 24),
                // 按钮
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).pop();
                          AudioService().playHomeBgm();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('返回首页', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _playAgain();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('再来一局', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _playAgain() async {
    // 先刷新玩家数据，获取最新积分
    await context.read<GameProvider>().loadPlayers();

    // 重新播放游戏背景音乐
    AudioService().playBgm(BgmType.gobang);

    setState(() {
      // 互换先手
      _swapSides = !_swapSides;
      _initBoard();
    });
  }

  void _animateScore(int target, void Function(void Function()) setState) {
    if (target <= 0) {
      setState(() => _displayScore = target);
      return;
    }

    const duration = Duration(milliseconds: 1500);
    const frames = 60;
    final increment = target / frames;
    int current = 0;

    Timer.periodic(duration ~/ frames, (timer) {
      current++;
      if (mounted) {
        setState(() {
          _displayScore = math.min((increment * current).round(), target);
        });
      }
      if (current >= frames) {
        timer.cancel();
      }
    });
  }

  Widget _buildResultStats() {
    final duration = DateTime.now().difference(_startTime);
    final durationStr = '${duration.inMinutes}分${duration.inSeconds % 60}秒';
    final steps = _history.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('时长', durationStr),
          Container(width: 1, height: 30, color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
          _buildStatItem('步数', '$steps步'),
          Container(width: 1, height: 30, color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
          _buildStatItem('模式', _isAiMode ? '单人' : '双人'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8B6914))),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3D2914))),
      ],
    );
  }

  // ==================== UI 组件 ====================

  void _showDifficultySelector() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFF8F4E8),
        title: const Text(
          '选择 AI 难度',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3D2914),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDifficultyOption(0, '🟢', '入门', '随机落子，简单防守', const Color(0xFF4CAF50)),
            const SizedBox(height: 12),
            _buildDifficultyOption(1, '🟠', '高手', '3层搜索，基础进攻', const Color(0xFFFF9800)),
            const SizedBox(height: 12),
            _buildDifficultyOption(2, '🔴', '大师', '5层搜索，杀棋识别', const Color(0xFFF44336)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '取消',
              style: TextStyle(color: Color(0xFF8B6914), fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyOption(int level, String emoji, String name, String desc, Color color) {
    final isSelected = _aiDifficulty == level;

    return InkWell(
      onTap: () {
        setState(() {
          _isAiMode = true;
          _aiDifficulty = level;
          _initBoard();
        });
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFD4AF37).withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : const Color(0xFF3D2914),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? color.withValues(alpha: 0.7) : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFFF8F4E8),
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.settings, color: Color(0xFF8B6914)),
              SizedBox(width: 8),
              Text(
                '游戏设置',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3D2914),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 计时开关
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Color(0xFF8B6914)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '显示计时',
                        style: TextStyle(fontSize: 16, color: Color(0xFF3D2914)),
                      ),
                    ),
                    Switch(
                      value: _timerEnabled,
                      onChanged: (value) {
                        setDialogState(() {
                          _timerEnabled = value;
                        });
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 音效开关（占位）
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.volume_up, color: Color(0xFF8B6914)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '游戏音效',
                        style: TextStyle(fontSize: 16, color: Color(0xFF3D2914)),
                      ),
                    ),
                    Text('开发中...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 游戏说明
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '游戏规则：',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B6914),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• 黑方先行，轮流落子\n• 五子连珠即为胜利\n• 每局限悔棋1次\n• 单人模式可使用3次提示',
                      style: TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('关闭', style: TextStyle(color: Color(0xFF8B6914))),
            ),
          ],
        ),
      ),
    );
  }

  void _showOpponentSelector() {
    final allPlayers = context.read<GameProvider>().allPlayers;
    final currentPlayer = _currentPlayer;
    final opponents = allPlayers.where((p) => p.avatar != currentPlayer?.avatar).toList();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFF8F4E8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 400,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '选择对手',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3D2914)),
              ),
              const SizedBox(height: 16),
              if (opponents.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('暂无其他玩家，请先创建新角色', style: TextStyle(color: Colors.grey)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: opponents.length,
                    itemBuilder: (context, index) {
                      final opponent = opponents[index];
                      return _buildOpponentTile(opponent, ctx);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpponentTile(Player opponent, BuildContext dialogCtx) {
    return InkWell(
      onTap: () {
        setState(() {
          _isAiMode = false;
          _opponent = opponent;
          _initBoard();
        });
        Navigator.pop(dialogCtx);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            _buildAvatar(opponent.avatar, 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(opponent.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3D2914))),
                  Text('积分: ${opponent.totalScore}', style: const TextStyle(fontSize: 12, color: Color(0xFF8B6914))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF8B6914)),
          ],
        ),
      ),
    );
  }

  // ==================== 构建方法 ====================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 1024;

    return Scaffold(
        backgroundColor: const Color(0xFFF8F4E8),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF8F4E8), Color(0xFFF0EBE0)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _buildPlayerPanel(isBlack: true, isSmall: isSmall),
                        const SizedBox(width: 16),
                        Expanded(child: Center(child: _buildBoard(isSmall))),
                        const SizedBox(width: 16),
                        _buildPlayerPanel(isBlack: false, isSmall: isSmall),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
        ),
    );
  }

  void _onBackPress() {
    // 游戏未开始或已结束，直接返回
    if (!_hasStarted || _gameOver) {
      Navigator.pop(context);
      AudioService().playHomeBgm();
      return;
    }
    // 游戏进行中，弹出确认对话框
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFFF8F4E8),
        title: const Text(
          '退出游戏',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3D2914),
          ),
        ),
        content: const Text(
          '游戏尚未结束，确定要退出吗？',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Color(0xFF5D4037)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('继续游戏', style: TextStyle(color: Color(0xFF8B6914))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              AudioService().playHomeBgm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('确定退出'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4E8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Tooltip(
            message: '返回 (长按快速返回)',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _onBackPress(),
                onLongPress: () {
                  Navigator.pop(context);
                  AudioService().playHomeBgm();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: const Icon(Icons.arrow_back, color: Color(0xFF3D2914), size: 24),
                ),
              ),
            ),
          ),
          const Spacer(),
          const Text('五子棋', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF3D2914))),
          const Spacer(),
          _buildIconButton(Icons.refresh, '新局', () => setState(_initBoard)),
          const SizedBox(width: 8),
          _buildIconButton(Icons.settings, '设置', _showSettingsDialog),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: const Color(0xFFD4AF37).withValues(alpha: 0.4),
          child: Container(padding: const EdgeInsets.all(10), child: Icon(icon, color: const Color(0xFF3D2914), size: 22)),
        ),
      ),
    );
  }

  Widget _buildPlayerPanel({required bool isBlack, required bool isSmall}) {
    final isActive = isBlack == _isPlayerTurn && !_gameOver;
    final currentPlayer = _currentPlayer;

    // 确定玩家信息（支持互换先手）
    String name;
    String avatar;
    int score;

    if (isBlack) {
      // 黑方
      if (_swapSides && !_isAiMode) {
        // 双人模式且互换后，黑方是原来的对手
        name = _opponent?.name ?? '玩家2';
        avatar = _opponent?.avatar ?? 'girl';
        score = _opponent?.totalScore ?? 0;
      } else {
        name = currentPlayer?.name ?? '玩家';
        avatar = currentPlayer?.avatar ?? 'boy';
        score = currentPlayer?.totalScore ?? 0;
      }
    } else {
      // 白方
      if (_isAiMode) {
        name = '电脑-${_difficultyNames[_aiDifficulty]}';
        avatar = 'robot';
        score = 0;
      } else if (_swapSides) {
        // 双人模式且互换后，白方是原来的玩家
        name = currentPlayer?.name ?? '玩家';
        avatar = currentPlayer?.avatar ?? 'boy';
        score = currentPlayer?.totalScore ?? 0;
      } else {
        name = _opponent?.name ?? '玩家2';
        avatar = _opponent?.avatar ?? 'girl';
        score = _opponent?.totalScore ?? 0;
      }
    }

    final steps = isBlack ? _blackSteps : _whiteSteps;
    final undoCount = isBlack ? _blackUndoCount : _whiteUndoCount;

    return AnimatedBuilder(
      animation: _breathController,
      builder: (context, child) {
        final glowIntensity = isActive ? 0.3 + (_breathController.value * 0.2) : 0.0;

        return Container(
          width: isSmall ? 140 : 180,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isActive
                  ? [const Color(0xFFF5F0E6), const Color(0xFFFFFFFF)]
                  : [const Color(0xFFF5F0E6).withValues(alpha: 0.8), const Color(0xFFFFFFFF).withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? const Color(0xFFFFD700) : Colors.transparent,
              width: isActive ? 3 : 0,
            ),
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? const Color(0xFFFFD700).withValues(alpha: glowIntensity)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: isActive ? 20 : 8,
                spreadRadius: isActive ? 4 : 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 头像（带金色呼吸边框）
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? const Color(0xFFFFD700) : const Color(0xFFCCCCCC),
                    width: isActive ? 3 : 2,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.5 + (_breathController.value * 0.3)),
                            blurRadius: 10 + (_breathController.value * 6),
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: CircleAvatar(
                  radius: isSmall ? 28 : 30,
                  backgroundColor: const Color(0xFFDEB887),
                  child: _buildAvatar(avatar, isSmall ? 50 : 60),
                ),
              ),
              const SizedBox(height: 12),
              // 玩家名称
              Text(
                name,
                style: TextStyle(
                  fontSize: isSmall ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3D2914),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // 积分显示（金色）
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '积分: $score',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB8941F),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 步数统计
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app, size: 14, color: Color(0xFF8B6914)),
                    const SizedBox(width: 4),
                    Text('步数:$steps', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B6914))),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 悔棋次数
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.undo, size: 14, color: undoCount > 0 ? const Color(0xFF8B6914) : Colors.grey),
                  const SizedBox(width: 4),
                  Text('悔棋:$undoCount', style: TextStyle(fontSize: 11, color: undoCount > 0 ? const Color(0xFF8B6914) : Colors.grey)),
                ],
              ),
              const SizedBox(height: 8),
              // 计时（AI模式隐藏）
              if (_timerEnabled && !(isBlack == false && _isAiMode))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFFF7043).withValues(alpha: 0.1) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer, size: 12, color: isActive ? const Color(0xFFFF7043) : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        isBlack ? _formatTime(_blackTime) : _formatTime(_whiteTime),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFFFF7043) : Colors.grey),
                      ),
                    ],
                  ),
                )
              else if (!isBlack && _isAiMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.all_inclusive, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text('无限', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                    ],
                  ),
                ),
              // 难度徽章（AI模式白方）
              if (!isBlack && _isAiMode) ...[
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _difficultyColors[_aiDifficulty].withValues(alpha: 0.9),
                            _difficultyColors[_aiDifficulty],
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _aiDifficulty == 2
                            ? [
                                BoxShadow(
                                  color: _difficultyColors[_aiDifficulty].withValues(alpha: 0.4 + (_glowController.value * 0.3)),
                                  blurRadius: 8 + (_glowController.value * 4),
                                  spreadRadius: 1 + (_glowController.value * 2),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: _difficultyColors[_aiDifficulty].withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Text(
                        _difficultyNames[_aiDifficulty],
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // 更换AI难度按钮
                _buildPanelButton(
                  icon: Icons.tune,
                  label: '更换难度',
                  onTap: _showDifficultySelector,
                ),
              ],
              // 双人模式更换角色按钮
              if (!isBlack && !_isAiMode) ...[
                const SizedBox(height: 12),
                _buildPanelButton(
                  icon: Icons.swap_horiz,
                  label: '更换角色',
                  onTap: _showOpponentSelector,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPanelButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: const Color(0xFFD4AF37).withValues(alpha: 0.3),
        highlightColor: const Color(0xFFD4AF37).withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF8B6914)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B6914),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String avatar, double size) {
    // AI机器人图标
    if (avatar == 'robot') {
      return Icon(Icons.smart_toy, size: size * 0.6, color: const Color(0xFF5D4037));
    }

    // 查找emoji
    final charData = kCharacters.firstWhere(
      (c) => c['avatar'] == avatar,
      orElse: () => kCharacters.first,
    );
    return Text(charData['emoji']!, style: TextStyle(fontSize: size * 0.6));
  }

  Widget _buildBoard(bool isSmall) {
    return AspectRatio(
      key: _boardKey,
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFC4A574),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 8))],
          border: Border.all(color: const Color(0xFF3D2914), width: 4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: MouseRegion(
            onHover: (event) {
              if (_gameOver) return;
              final renderObj = _boardKey.currentContext?.findRenderObject();
              if (renderObj == null) return;
              final box = renderObj as RenderBox;
              final localPos = box.globalToLocal(event.position);
              final boardSizePx = box.size.shortestSide;
              final padding = boardSizePx * 0.06;
              final cellSize = (boardSizePx - padding * 2) / (boardSize - 1);

              final col = ((localPos.dx - padding) / cellSize).round();
              final row = ((localPos.dy - padding) / cellSize).round();

              if (col >= 0 && col < boardSize && row >= 0 && row < boardSize) {
                setState(() {
                  _hoverPos = Offset(col.toDouble(), row.toDouble());
                  _isHoverValid = _board[row][col] == 0;
                });
              }
            },
            onExit: (_) => setState(() => _hoverPos = null),
            child: GestureDetector(
              onTapUp: (details) {
                final renderObj = _boardKey.currentContext?.findRenderObject();
                if (renderObj == null) return;
                final box = renderObj as RenderBox;
                final localPos = box.globalToLocal(details.globalPosition);
                final boardSizePx = box.size.shortestSide;
                final padding = boardSizePx * 0.06;
                final cellSize = (boardSizePx - padding * 2) / (boardSize - 1);

                final col = ((localPos.dx - padding) / cellSize).round();
                final row = ((localPos.dy - padding) / cellSize).round();

                if (col >= 0 && col < boardSize && row >= 0 && row < boardSize) {
                  _onTap(row, col);
                }
              },
              child: AnimatedBuilder(
                animation: Listenable.merge([_pieceAnimController, _dropAnimController, _breathController]),
                builder: (context, child) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: _GobangPainter(
                      board: _board,
                      boardSize: boardSize,
                      lastMove: _lastMovePos,
                      winningLine: _winningLine,
                      hoverPos: _hoverPos,
                      isHoverValid: _isHoverValid,
                      isPlayerTurn: _isPlayerTurn,
                      gameOver: _gameOver,
                      dropProgress: _dropAnimController.value,
                      breathValue: _breathController.value,
                      particles: _particles,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          // 回合指示器
          _buildTurnIndicator(),
          const Spacer(),
          // 悔棋按钮
          _buildActionButton(
            icon: Icons.undo,
            label: '悔棋',
            onTap: _showUndoConfirm,
          ),
          const SizedBox(width: 12),
          // 模式选择（分段控制器）
          _buildSegmentedControl(),
        ],
      ),
    );
  }

  Widget _buildTurnIndicator() {
    return AnimatedBuilder(
      animation: _breathController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_breathController.value * 0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isPlayerTurn
                    ? [const Color(0xFF2D2D2D), const Color(0xFF1A1A1A)]
                    : [Colors.white, const Color(0xFFF5F5F5)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFD4AF37), width: 2),
              boxShadow: [
                BoxShadow(
                  color: (_isPlayerTurn ? const Color(0xFF2D2D2D) : Colors.grey).withValues(alpha: 0.3),
                  blurRadius: 8 + (_breathController.value * 4),
                  spreadRadius: _breathController.value * 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isPlayerTurn ? Colors.white : const Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isPlayerTurn ? '黑方回合' : '白方回合',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _isPlayerTurn ? Colors.white : const Color(0xFF2D2D2D),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: const Color(0xFFD4AF37).withValues(alpha: 0.3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF3D2914)),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3D2914))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegmentButton('🤖 单人 电脑', _isAiMode, () {
            if (!_isAiMode) _showDifficultySelector();
          }),
          _buildSegmentButton('👤 双人对战', !_isAiMode, () {
            if (_isAiMode) _showOpponentSelector();
          }),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String text, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF5D4037),
          ),
        ),
      ),
    );
  }
}

// ==================== 粒子类 ====================

class _Particle {
  Offset position;
  double angle;
  double speed;
  double size;

  _Particle({
    required this.position,
    required this.angle,
    required this.speed,
    required this.size,
  });
}

// ==================== 棋盘绘制 ====================

class _GobangPainter extends CustomPainter {
  final List<List<int>> board;
  final int boardSize;
  final Offset? lastMove;
  final List<Offset> winningLine;
  final Offset? hoverPos;
  final bool isHoverValid;
  final bool isPlayerTurn;
  final bool gameOver;
  final double dropProgress;
  final double breathValue;
  final List<_Particle> particles;

  _GobangPainter({
    required this.board,
    required this.boardSize,
    this.lastMove,
    this.winningLine = const [],
    this.hoverPos,
    this.isHoverValid = false,
    this.isPlayerTurn = true,
    this.gameOver = false,
    this.dropProgress = 1.0,
    this.breathValue = 0.0,
    this.particles = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final boardPx = size.shortestSide;
    final padding = boardPx * 0.06;
    final cellSize = (boardPx - padding * 2) / (boardSize - 1);

    // 木纹背景
    final bgPaint = Paint()
      ..color = const Color(0xFFC4A574)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 木纹纹理
    _drawWoodTexture(canvas, size);

    // 网格线
    final linePaint = Paint()
      ..color = const Color(0xFF3D2914)
      ..strokeWidth = 1.2;

    for (int i = 0; i < boardSize; i++) {
      final pos = padding + i * cellSize;
      canvas.drawLine(Offset(padding, pos), Offset(boardPx - padding, pos), linePaint);
      canvas.drawLine(Offset(pos, padding), Offset(pos, boardPx - padding), linePaint);
    }

    // 星位标记
    final starPaint = Paint()
      ..color = const Color(0xFF3D2914)
      ..style = PaintingStyle.fill;
    final starPositions = [3, 7, 11];
    for (final r in starPositions) {
      for (final c in starPositions) {
        canvas.drawCircle(
          Offset(padding + c * cellSize, padding + r * cellSize),
          4,
          starPaint,
        );
      }
    }

    // 悬停预览
    if (hoverPos != null && !gameOver) {
      final cx = padding + hoverPos!.dx * cellSize;
      final cy = padding + hoverPos!.dy * cellSize;
      final previewPaint = Paint()
        ..color = isHoverValid
            ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
            : const Color(0xFFE74C3C).withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), cellSize * 0.38, previewPaint);
      final borderPaint = Paint()
        ..color = isHoverValid ? const Color(0xFF4CAF50) : const Color(0xFFE74C3C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(cx, cy), cellSize * 0.38, borderPaint);
    }

    // 绘制棋子
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (board[r][c] == 0) continue;
        final cx = padding + c * cellSize;
        final cy = padding + r * cellSize;
        final isBlack = board[r][c] == 1;

        if (lastMove != null && lastMove!.dx == c && lastMove!.dy == r) {
          final bounceScale = _calculateBounce(dropProgress);
          _drawPieceWithScale(canvas, cx, cy, cellSize, isBlack, bounceScale);
        } else {
          _drawPiece(canvas, cx, cy, cellSize, isBlack);
        }
      }
    }

    // 最后落子标记
    if (lastMove != null) {
      final cx = padding + lastMove!.dx * cellSize;
      final cy = padding + lastMove!.dy * cellSize;
      final pulseScale = 1.0 + (breathValue * 0.1);
      final ringPaint = Paint()
        ..color = const Color(0xFFE74C3C).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(Offset(cx, cy), cellSize * 0.42 * pulseScale, ringPaint);
    }

    // 胜利连线
    if (winningLine.isNotEmpty) {
      final highlightPaint = Paint()
        ..color = const Color(0xFFD4AF37)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < winningLine.length - 1; i++) {
        final p1 = winningLine[i];
        final p2 = winningLine[i + 1];
        canvas.drawLine(
          Offset(padding + p1.dx * cellSize, padding + p1.dy * cellSize),
          Offset(padding + p2.dx * cellSize, padding + p2.dy * cellSize),
          highlightPaint,
        );
      }

      for (final pos in winningLine) {
        final cx = padding + pos.dx * cellSize;
        final cy = padding + pos.dy * cellSize;
        final glowPaint = Paint()
          ..color = const Color(0xFFD4AF37).withValues(alpha: 0.3 + (breathValue * 0.2))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(cx, cy), cellSize * 0.55, glowPaint);
      }

      _drawParticles(canvas, padding, cellSize);
    }
  }

  void _drawWoodTexture(Canvas canvas, Size size) {
    final texturePaint = Paint()
      ..color = const Color(0xFFB8956A).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (int i = 0; i < 15; i++) {
      final y = size.height * (0.05 + i * 0.06);
      final path = Path();
      path.moveTo(0, y);
      for (double x = 0; x < size.width; x += 20) {
        final wave = math.sin(x * 0.02 + i) * 2;
        path.lineTo(x, y + wave);
      }
      canvas.drawPath(path, texturePaint);
    }
  }

  double _calculateBounce(double progress) {
    if (progress < 0.3) {
      return 1.3 - (progress / 0.3) * 0.3;
    } else if (progress < 0.5) {
      final t = (progress - 0.3) / 0.2;
      return 1.0 + math.sin(t * math.pi) * 0.15;
    } else if (progress < 0.7) {
      final t = (progress - 0.5) / 0.2;
      return 1.0 + math.sin(t * math.pi) * 0.08;
    } else {
      return 1.0;
    }
  }

  void _drawParticles(Canvas canvas, double padding, double cellSize) {
    final time = DateTime.now().millisecondsSinceEpoch / 1000;
    for (final particle in particles) {
      final px = padding + particle.position.dx * cellSize;
      final py = padding + particle.position.dy * cellSize;
      final dx = math.cos(particle.angle + time) * particle.speed * 8;
      final dy = math.sin(particle.angle + time) * particle.speed * 8 - (time % 3) * 5;
      final fadeOut = (1 - ((time % 3) / 3)).clamp(0.0, 1.0);

      final particlePaint = Paint()
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.6 * fadeOut)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(px + dx, py + dy), particle.size * fadeOut, particlePaint);
    }
  }

  void _drawPiece(Canvas canvas, double cx, double cy, double cellSize, bool isBlack) {
    _drawPieceWithScale(canvas, cx, cy, cellSize, isBlack, 1.0);
  }

  void _drawPieceWithScale(
      Canvas canvas, double cx, double cy, double cellSize, bool isBlack, double scale) {
    final pieceRadius = cellSize * 0.42 * scale;

    canvas.drawCircle(
      Offset(cx + 2, cy + 2),
      pieceRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 0.8,
      colors: isBlack
          ? [const Color(0xFF4A4A4A), const Color(0xFF1A1A1A)]
          : [Colors.white, const Color(0xFFD0D0D0)],
    );

    canvas.drawCircle(
      Offset(cx, cy),
      pieceRadius,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: pieceRadius),
        ),
    );

    final highlightPaint = Paint()
      ..color = isBlack ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(cx - pieceRadius * 0.3, cy - pieceRadius * 0.3),
      pieceRadius * 0.25,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(_GobangPainter old) {
    return old.board != board ||
        old.lastMove != lastMove ||
        old.winningLine != winningLine ||
        old.hoverPos != hoverPos ||
        old.dropProgress != dropProgress ||
        old.breathValue != breathValue ||
        winningLine.isNotEmpty;
  }
}

// ==================== 数据类 ====================

class _Move {
  final int row;
  final int col;
  final int player;
  _Move(this.row, this.col, this.player);
}
