import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/game_record_model.dart';
import '../../models/player_model.dart';
import '../../services/audio_service.dart';

/// 消消乐游戏 - 横屏布局版
class Match3Screen extends StatefulWidget {
  const Match3Screen({super.key});

  @override
  State<Match3Screen> createState() => _Match3ScreenState();
}

/// 水果类型
enum FruitType {
  strawberry, // 草莓
  orange,     // 橙子
  lemon,      // 柠檬
  apple,      // 苹果
  blueberry,  // 蓝莓
  grape,      // 葡萄
}

/// 水果配置
class FruitConfig {
  static const List<String> emojis = ['🍓', '🍊', '🍋', '🍏', '🫐', '🍇'];
  static const List<Color> colors = [
    Color(0xFFFF6B6B), // 红
    Color(0xFFFFA500), // 橙
    Color(0xFFFFD93D), // 黄
    Color(0xFF6BCB77), // 绿
    Color(0xFF4D96FF), // 蓝
    Color(0xFF9B59B6), // 紫
  ];
}

/// 游戏配置
class GameConfig {
  static const int gridSize = 8;
  static const int targetScore = 2000;
  static const int maxMoves = 50;
  static const double boardSize = 650.0;
  static const int maxHints = 5;
}

/// 格子数据
class _CellData {
  final FruitType fruitType;
  final bool isBomb;

  const _CellData({required this.fruitType, this.isBomb = false});
}

/// 匹配检测结果
class _MatchResult {
  final Set<(int, int)> toEliminate;
  final List<({int row, int col, FruitType fruitType})> bombGenerators;

  const _MatchResult({required this.toEliminate, required this.bombGenerators});

  bool get isEmpty => toEliminate.isEmpty;
  bool get isNotEmpty => toEliminate.isNotEmpty;
}

class _Match3ScreenState extends State<Match3Screen>
    with TickerProviderStateMixin {
  // 游戏网格
  late List<List<_CellData?>> _grid;

  // 游戏状态
  int _score = 0;
  int _movesLeft = GameConfig.maxMoves;
  int _combo = 0;
  int _maxCombo = 0;
  bool _gameOver = false;
  bool _isWon = false;
  bool _isProcessing = false;

  // 提示状态
  int _hintsLeft = GameConfig.maxHints;
  int? _hintRow;
  int? _hintCol;
  int? _hintTargetRow;
  int? _hintTargetCol;

  // 滑动状态
  int? _swipeStartRow;
  int? _swipeStartCol;
  Offset? _swipeStartPos;
  bool _swipeTriggered = false;

  // 动画
  late AnimationController _comboController;
  late AnimationController _shakeController;
  late AnimationController _explosionController;

  // 连击提示
  String? _comboText;
  double _comboOpacity = 0;

  // 爆炸特效
  Set<(int, int)> _activeExplosions = {};

  // 开始时间
  late DateTime _startTime;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _comboController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _explosionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _startTime = DateTime.now();
    _initGame();
    AudioService().playBgm(BgmType.match3);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _comboController.dispose();
    _shakeController.dispose();
    _explosionController.dispose();
    super.dispose();
  }

  void _initGame() {
    _grid = List.generate(
      GameConfig.gridSize,
      (_) => List.generate(GameConfig.gridSize, (_) => null),
    );

    // 生成初始水果
    for (int r = 0; r < GameConfig.gridSize; r++) {
      for (int c = 0; c < GameConfig.gridSize; c++) {
        _grid[r][c] = _CellData(fruitType: _generateFruitType(r, c));
      }
    }

    // 确保初始没有三消
    _clearInitialMatches();

    _score = 0;
    _movesLeft = GameConfig.maxMoves;
    _combo = 0;
    _maxCombo = 0;
    _gameOver = false;
    _isWon = false;
    _isProcessing = false;
    _hintsLeft = GameConfig.maxHints;
    _hintRow = null;
    _hintCol = null;
    _hintTargetRow = null;
    _hintTargetCol = null;
    _comboText = null;
    _comboOpacity = 0;
    _activeExplosions = {};
    _startTime = DateTime.now();
  }

  FruitType _generateFruitType(int row, int col) {
    int typeIndex;
    do {
      typeIndex = Random().nextInt(6);
    } while (_wouldCreateMatch(row, col, typeIndex));

    return FruitType.values[typeIndex];
  }

  bool _wouldCreateMatch(int row, int col, int typeIndex) {
    // 检查横向
    int horizontalCount = 1;
    for (int c = col - 1; c >= 0 && _grid[row][c]?.fruitType.index == typeIndex; c--) {
      horizontalCount++;
    }
    for (int c = col + 1; c < GameConfig.gridSize && _grid[row][c]?.fruitType.index == typeIndex; c++) {
      horizontalCount++;
    }
    if (horizontalCount >= 3) return true;

    // 检查纵向
    int verticalCount = 1;
    for (int r = row - 1; r >= 0 && _grid[r][col]?.fruitType.index == typeIndex; r--) {
      verticalCount++;
    }
    for (int r = row + 1; r < GameConfig.gridSize && _grid[r][col]?.fruitType.index == typeIndex; r++) {
      verticalCount++;
    }
    if (verticalCount >= 3) return true;

    return false;
  }

  void _clearInitialMatches() {
    bool hasMatch = true;
    while (hasMatch) {
      hasMatch = false;
      for (int r = 0; r < GameConfig.gridSize; r++) {
        for (int c = 0; c < GameConfig.gridSize; c++) {
          if (_hasMatchAt(r, c)) {
            _grid[r][c] = _CellData(fruitType: _generateFruitType(r, c));
            hasMatch = true;
          }
        }
      }
    }
  }

  bool _hasMatchAt(int r, int c) {
    if (_grid[r][c] == null) return false;
    final type = _grid[r][c]!.fruitType;

    // 横向检查
    int horizontalCount = 1;
    for (int i = c - 1; i >= 0 && _grid[r][i]?.fruitType == type; i--) {
      horizontalCount++;
    }
    for (int i = c + 1; i < GameConfig.gridSize && _grid[r][i]?.fruitType == type; i++) {
      horizontalCount++;
    }
    if (horizontalCount >= 3) return true;

    // 纵向检查
    int verticalCount = 1;
    for (int i = r - 1; i >= 0 && _grid[i][c]?.fruitType == type; i--) {
      verticalCount++;
    }
    for (int i = r + 1; i < GameConfig.gridSize && _grid[i][c]?.fruitType == type; i++) {
      verticalCount++;
    }
    if (verticalCount >= 3) return true;

    return false;
  }

  // ==================== 滑动交互 ====================

  void _handlePanStart(DragStartDetails details, double cellSize) {
    if (_gameOver || _isProcessing) return;

    final localPos = details.localPosition;
    final step = cellSize + 10;
    final col = ((localPos.dx - 12) / step).floor();
    final row = ((localPos.dy - 12) / step).floor();

    if (row >= 0 && row < GameConfig.gridSize && col >= 0 && col < GameConfig.gridSize) {
      _swipeStartRow = row;
      _swipeStartCol = col;
      _swipeStartPos = localPos;
      _swipeTriggered = false;
      HapticFeedback.lightImpact();
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, double cellSize) {
    if (_swipeTriggered || _swipeStartRow == null || _swipeStartPos == null) return;
    if (_gameOver || _isProcessing) return;

    final dx = details.localPosition.dx - _swipeStartPos!.dx;
    final dy = details.localPosition.dy - _swipeStartPos!.dy;
    final threshold = cellSize * 0.3;

    if (dx.abs() > threshold || dy.abs() > threshold) {
      _swipeTriggered = true;
      int dr = 0, dc = 0;
      if (dx.abs() > dy.abs()) {
        dc = dx > 0 ? 1 : -1;
      } else {
        dr = dy > 0 ? 1 : -1;
      }

      final startRow = _swipeStartRow!;
      final startCol = _swipeStartCol!;
      final targetRow = startRow + dr;
      final targetCol = startCol + dc;

      _swipeStartRow = null;
      _swipeStartCol = null;
      _swipeStartPos = null;

      if (targetRow >= 0 && targetRow < GameConfig.gridSize &&
          targetCol >= 0 && targetCol < GameConfig.gridSize &&
          _grid[startRow][startCol] != null &&
          _grid[targetRow][targetCol] != null) {
        _trySwap(startRow, startCol, targetRow, targetCol);
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _swipeStartRow = null;
    _swipeStartCol = null;
    _swipeStartPos = null;
    _swipeTriggered = false;
  }

  Future<void> _trySwap(int r1, int c1, int r2, int c2) async {
    setState(() {
      _isProcessing = true;
      _hintRow = null;
      _hintCol = null;
      _hintTargetRow = null;
      _hintTargetCol = null;
    });

    // 执行交换
    final temp = _grid[r1][c1];
    _grid[r1][c1] = _grid[r2][c2];
    _grid[r2][c2] = temp;

    // 检查是否有消除
    final result = _findMatches();

    if (result.toEliminate.isEmpty) {
      // 无效交换，换回来
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() {
        final temp = _grid[r1][c1];
        _grid[r1][c1] = _grid[r2][c2];
        _grid[r2][c2] = temp;
        _isProcessing = false;
      });
      _shakeController.forward(from: 0);
      return;
    }

    // 有效交换
    _movesLeft--;
    _combo = 0;

    // 处理消除连锁
    await _processMatches();

    // 检查游戏结束
    _checkGameOver();
  }

  // ==================== 匹配检测 ====================

  _MatchResult _findMatches() {
    final toEliminate = <(int, int)>{};
    final bombGenMap = <(int, int), ({int row, int col, FruitType fruitType})>{};

    // 横向检查
    for (int r = 0; r < GameConfig.gridSize; r++) {
      int c = 0;
      while (c < GameConfig.gridSize) {
        final cell = _grid[r][c];
        if (cell == null) { c++; continue; }

        int count = 1;
        while (c + count < GameConfig.gridSize &&
               _grid[r][c + count]?.fruitType == cell.fruitType) {
          count++;
        }

        if (count >= 3) {
          for (int i = 0; i < count; i++) {
            toEliminate.add((r, c + i));
          }
          if (count >= 4) {
            final bombCol = c + count - 1;
            bombGenMap[(r, bombCol)] = (
              row: r, col: bombCol, fruitType: cell.fruitType,
            );
          }
        }

        c += count > 1 ? count : 1;
      }
    }

    // 纵向检查
    for (int c = 0; c < GameConfig.gridSize; c++) {
      int r = 0;
      while (r < GameConfig.gridSize) {
        final cell = _grid[r][c];
        if (cell == null) { r++; continue; }

        int count = 1;
        while (r + count < GameConfig.gridSize &&
               _grid[r + count][c]?.fruitType == cell.fruitType) {
          count++;
        }

        if (count >= 3) {
          for (int i = 0; i < count; i++) {
            toEliminate.add((r + i, c));
          }
          if (count >= 4) {
            final bombRow = r + count - 1;
            final key = (bombRow, c);
            // 横向优先，纵向不覆盖
            if (!bombGenMap.containsKey(key)) {
              bombGenMap[key] = (
                row: bombRow, col: c, fruitType: cell.fruitType,
              );
            }
          }
        }

        r += count > 1 ? count : 1;
      }
    }

    // 从消除集合中移除炸弹生成位置（它们会变成炸弹而不是被消除）
    final bombGenerators = bombGenMap.values.toList();
    for (final bg in bombGenerators) {
      toEliminate.remove((bg.row, bg.col));
    }

    return _MatchResult(toEliminate: toEliminate, bombGenerators: bombGenerators);
  }

  // ==================== 消除处理（含炸弹爆炸） ====================

  Future<void> _processMatches() async {
    while (true) {
      final result = _findMatches();
      if (result.toEliminate.isEmpty) break;

      _combo++;
      if (_combo > _maxCombo) _maxCombo = _combo;

      // 显示连击
      _showCombo();

      // 播放消除音效
      AudioService().playSfx('audio/sfx/eliminate.mp3');

      // 收集所有需要消除的格子（含炸弹爆炸）
      final allToEliminate = Set<(int, int)>.from(result.toEliminate);
      final bombCenters = <(int, int)>[];

      // 检查 toEliminate 中是否有炸弹 → 触发爆炸
      final bombsToExplode = <(int, int)>[];
      for (final (r, c) in result.toEliminate) {
        if (_grid[r][c]?.isBomb == true) {
          bombsToExplode.add((r, c));
          bombCenters.add((r, c));
        }
      }

      // 炸弹连锁爆炸
      final explodedBombs = <(int, int)>{};
      while (bombsToExplode.isNotEmpty) {
        final bomb = bombsToExplode.removeAt(0);
        if (explodedBombs.contains(bomb)) continue;
        explodedBombs.add(bomb);

        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            final nr = bomb.$1 + dr;
            final nc = bomb.$2 + dc;
            if (nr < 0 || nr >= GameConfig.gridSize || nc < 0 || nc >= GameConfig.gridSize) {
              continue;
            }
            // 不消除炸弹生成位置
            final isBombGenPos = result.bombGenerators.any(
              (bg) => bg.row == nr && bg.col == nc,
            );
            if (isBombGenPos) {
              continue;
            }

            allToEliminate.add((nr, nc));

            // 如果3×3区域内有新炸弹，加入连锁
            if (_grid[nr][nc]?.isBomb == true && !explodedBombs.contains((nr, nc))) {
              bombsToExplode.add((nr, nc));
              bombCenters.add((nr, nc));
            }
          }
        }
      }

      // 播放炸弹爆炸动画（逐个播放，制造连锁效果）
      if (bombCenters.isNotEmpty) {
        for (final center in bombCenters) {
          setState(() {
            _activeExplosions = {center};
          });
          await _explosionController.forward(from: 0);
          await Future.delayed(const Duration(milliseconds: 80));
        }
        setState(() {
          _activeExplosions = {};
        });
      }

      // 计算分数
      int baseScore = allToEliminate.length * 10;
      if (bombCenters.isNotEmpty) {
        baseScore += bombCenters.length * 20; // 炸弹额外加分
      }
      double multiplier = _getComboMultiplier();
      int roundScore = (baseScore * multiplier).round();
      _score += roundScore;

      // 放置炸弹
      for (final bg in result.bombGenerators) {
        _grid[bg.row][bg.col] = _CellData(fruitType: bg.fruitType, isBomb: true);
      }

      // 消除格子
      setState(() {
        for (final (r, c) in allToEliminate) {
          _grid[r][c] = null;
        }
      });

      await Future.delayed(const Duration(milliseconds: 300));

      // 下落和填充
      await _dropAndRefill();
    }

    setState(() => _isProcessing = false);
  }

  double _getComboMultiplier() {
    if (_combo >= 10) return 3.0;
    if (_combo >= 5) return 2.0;
    if (_combo >= 3) return 1.5;
    if (_combo >= 2) return 1.2;
    return 1.0;
  }

  void _showCombo() {
    if (_combo >= 2) {
      setState(() {
        if (_combo >= 10) {
          _comboText = '$_combo 连击!🔥🔥';
        } else if (_combo >= 5) {
          _comboText = '$_combo 连击!🔥';
        } else {
          _comboText = '$_combo 连击!';
        }
        _comboOpacity = 1.0;
      });

      _comboController.forward(from: 0).then((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() => _comboOpacity = 0);
          }
        });
      });
    }
  }

  Future<void> _dropAndRefill() async {
    setState(() {
      // 下落
      for (int c = 0; c < GameConfig.gridSize; c++) {
        final column = <_CellData?>[];
        for (int r = 0; r < GameConfig.gridSize; r++) {
          if (_grid[r][c] != null) {
            column.add(_grid[r][c]);
          }
        }

        // 填充新水果
        while (column.length < GameConfig.gridSize) {
          column.insert(0, _CellData(fruitType: FruitType.values[Random().nextInt(6)]));
        }

        for (int r = 0; r < GameConfig.gridSize; r++) {
          _grid[r][c] = column[r];
        }
      }
    });

    await Future.delayed(const Duration(milliseconds: 200));
  }

  void _checkGameOver() {
    if (_score >= GameConfig.targetScore) {
      setState(() {
        _gameOver = true;
        _isWon = true;
      });
      _saveResult();
    } else if (_movesLeft <= 0) {
      setState(() => _gameOver = true);
      _saveResult();
    }
  }

  Future<void> _saveResult() async {
    final duration = DateTime.now().difference(_startTime).inSeconds;

    // 积分奖励：通关+20，失败+0，连击额外+5~15
    int bonusPoints = _isWon ? 20 : 0;
    // 连击奖励：最高连击数 × 1.5（上限15分）
    int comboBonus = (_maxCombo * 1.5).round().clamp(0, 15);
    if (comboBonus >= 5) bonusPoints += comboBonus;

    await context.read<GameProvider>().saveGameResult(
      gameType: GameType.match3,
      score: _score,
      duration: duration,
      isWin: _isWon,
    );

    // 显示结算弹窗
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _showGameOverDialog(bonusPoints);
      }
    });
  }

  void _showGameOverDialog(int bonusPoints) {
    // 播放结算音效
    AudioService().playWinningSfx();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _GameOverDialog(
        isWin: _isWon,
        score: _score,
        targetScore: GameConfig.targetScore,
        movesLeft: _movesLeft,
        maxCombo: _maxCombo,
        bonusPoints: bonusPoints,
        onRestart: () async {
          Navigator.pop(context);
          await context.read<GameProvider>().loadPlayers();
          AudioService().playBgm(BgmType.match3);
          setState(_initGame);
        },
        onHome: () {
          Navigator.pop(context);
          Navigator.pop(context);
          AudioService().playHomeBgm();
        },
      ),
    );
  }

  // ==================== 提示系统 ====================

  void _showHint() {
    if (_hintsLeft <= 0 || _gameOver || _isProcessing) return;

    for (int r = 0; r < GameConfig.gridSize; r++) {
      for (int c = 0; c < GameConfig.gridSize; c++) {
        // 尝试与右边交换
        if (c < GameConfig.gridSize - 1) {
          _swapTemp(r, c, r, c + 1);
          if (_findMatches().toEliminate.isNotEmpty) {
            _swapTemp(r, c, r, c + 1);
            _hintsLeft--;
            setState(() {
              _hintRow = r;
              _hintCol = c;
              _hintTargetRow = r;
              _hintTargetCol = c + 1;
            });
            _autoClearHint();
            return;
          }
          _swapTemp(r, c, r, c + 1);
        }
        // 尝试与下边交换
        if (r < GameConfig.gridSize - 1) {
          _swapTemp(r, c, r + 1, c);
          if (_findMatches().toEliminate.isNotEmpty) {
            _swapTemp(r, c, r + 1, c);
            _hintsLeft--;
            setState(() {
              _hintRow = r;
              _hintCol = c;
              _hintTargetRow = r + 1;
              _hintTargetCol = c;
            });
            _autoClearHint();
            return;
          }
          _swapTemp(r, c, r + 1, c);
        }
      }
    }
  }

  void _autoClearHint() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _hintRow = null;
          _hintCol = null;
          _hintTargetRow = null;
          _hintTargetCol = null;
        });
      }
    });
  }

  void _swapTemp(int r1, int c1, int r2, int c2) {
    final temp = _grid[r1][c1];
    _grid[r1][c1] = _grid[r2][c2];
    _grid[r2][c2] = temp;
  }

  // ==================== 构建UI ====================
  @override
  Widget build(BuildContext context) {
    final player = context.watch<GameProvider>().currentPlayer;
    final cellSize = (GameConfig.boardSize - 24 - 10 * 7) / GameConfig.gridSize;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F0E6), Color(0xFFEDE7D6)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部导航栏
              _buildTopBar(player),

              // 主内容区 - 左右分栏，顶部对齐
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 左侧游戏网格 - 固定宽度
                      SizedBox(
                        width: GameConfig.boardSize,
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _shakeController,
                            builder: (context, child) {
                              final shake = sin(_shakeController.value * pi * 8) * 5;
                              return Transform.translate(
                                offset: Offset(shake, 0),
                                child: child,
                              );
                            },
                            child: _buildGameGrid(cellSize),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // 右侧信息面板 - 剩余空间
                      Expanded(
                        child: _buildInfoPanel(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(Player? player) {
    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // 返回按钮
          _buildTopButton(
            icon: Icons.arrow_back,
            color: const Color(0xFF87CEEB),
            onTap: () {
              Navigator.pop(context);
              AudioService().playHomeBgm();
            },
          ),

          // 居中标题
          Expanded(
            child: Center(
              child: const Text(
                '🍬 消消乐',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
            ),
          ),

          // 角色头像
          if (player != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(child: Text(player.emoji, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 6),
            Text(
              player.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3D2914)),
            ),
            const SizedBox(width: 12),
          ],

          // 积分徽章
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '${player?.totalScore ?? 0}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Widget _buildGameGrid(double cellSize) {
    final step = cellSize + 10;

    return GestureDetector(
      onPanStart: (details) => _handlePanStart(details, cellSize),
      onPanUpdate: (details) => _handlePanUpdate(details, cellSize),
      onPanEnd: (details) => _handlePanEnd(details),
      child: Container(
        width: GameConfig.boardSize,
        height: GameConfig.boardSize,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 网格
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: GameConfig.gridSize,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: GameConfig.gridSize * GameConfig.gridSize,
              itemBuilder: (context, index) {
                final r = index ~/ GameConfig.gridSize;
                final c = index % GameConfig.gridSize;
                final cellData = _grid[r][c];
                final isHint = _hintRow == r && _hintCol == c;
                final isHintTarget = _hintTargetRow == r && _hintTargetCol == c;

                return _FruitCell(
                  cellData: cellData,
                  isHint: isHint,
                  isHintTarget: isHintTarget,
                );
              },
            ),

            // 爆炸特效层
            if (_activeExplosions.isNotEmpty)
              AnimatedBuilder(
                animation: _explosionController,
                builder: (context, _) {
                  final progress = _explosionController.value;
                  return Stack(
                    children: _activeExplosions.map((pos) {
                      final double cx = pos.$2 * step + cellSize / 2;
                      final double cy = pos.$1 * step + cellSize / 2;
                      return Positioned(
                        left: cx - 100,
                        top: cy - 100,
                        child: Transform.scale(
                          scale: 0.3 + progress * 1.7,
                          child: Opacity(
                            opacity: 1.0 - progress,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.9),
                                    const Color(0xFFFF6600).withValues(alpha: 0.7),
                                    const Color(0xFFFFAA00).withValues(alpha: 0.4),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.3, 0.6, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

            // 连击特效
            if (_comboText != null && _comboOpacity > 0)
              Center(
                child: AnimatedOpacity(
                  opacity: _comboOpacity,
                  duration: const Duration(milliseconds: 300),
                  child: ScaleTransition(
                    scale: _comboController.drive(
                      Tween(begin: 0.5, end: 1.2).chain(
                        CurveTween(curve: Curves.elasticOut),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        _comboText!,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 区域1：双列卡片 - 目标得分/当前得分
        Row(
          children: [
            Expanded(
              child: _LargeInfoCard(
                icon: '🎯',
                title: '目标得分',
                value: '${GameConfig.targetScore}',
                color: const Color(0xFF6BCB77),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LargeInfoCard(
                icon: '⭐',
                title: '当前得分',
                value: '$_score',
                color: const Color(0xFFFF6B6B),
                isHighlighted: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 区域2：剩余步数卡片（单列）
        _buildMovesCard(),
        const SizedBox(height: 10),

        // 区域3：游戏进度卡片（单列）
        _buildProgressCard(),
        const SizedBox(height: 10),

        // 区域4：双列卡片 - 游戏提示/积分奖励（严格等高）
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _buildHintCard(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildBonusCard(),
              ),
            ],
          ),
        ),

        const Spacer(),

        // 区域5：底部双列按钮
        Row(
          children: [
            Expanded(
              child: _buildHintButton(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildRestartButton(),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildMovesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: _movesLeft <= 5
            ? Border.all(color: const Color(0xFFF44336), width: 2)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (_movesLeft <= 5 ? const Color(0xFFF44336) : const Color(0xFF4D96FF)).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text('👣', style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '剩余步数',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_movesLeft',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: _movesLeft <= 5 ? const Color(0xFFF44336) : const Color(0xFF4D96FF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final progress = (_score / GameConfig.targetScore).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                '游戏进度',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3D2914)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                progress >= 1.0
                    ? const Color(0xFF6BCB77)
                    : const Color(0xFFFF9800),
              ),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: progress >= 1.0 ? const Color(0xFF6BCB77) : const Color(0xFF666666),
                ),
              ),
              if (progress >= 1.0)
                const Text(
                  '✅ 已达标',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6BCB77)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHintCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('💡', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                '游戏提示',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3D2914)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildHintItem('滑动交换水果'),
          _buildHintItem('3个相同消除'),
          _buildHintItem('4连生成炸弹💣'),
          _buildHintItem('连击得高分'),
        ],
      ),
    );
  }

  Widget _buildBonusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🎁', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                '积分奖励',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3D2914)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildHintItem('通关: +20分', color: const Color(0xFF6BCB77)),
          _buildHintItem('失败: +0分', color: Colors.grey),
          _buildHintItem('连击: +5~15分', color: const Color(0xFFFFD700)),
          const SizedBox(height: 18), // 占位保持高度一致
        ],
      ),
    );
  }

  Widget _buildHintItem(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: color ?? const Color(0xFF4FC3F7)),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: color ?? const Color(0xFF666666))),
        ],
      ),
    );
  }

  Widget _buildHintButton() {
    final isDisabled = _hintsLeft <= 0 || _gameOver || _isProcessing;
    final bgColor = isDisabled ? Colors.grey : const Color(0xFF42A5F5);
    final shadowColor = isDisabled ? Colors.grey.withValues(alpha: 0.2) : const Color(0xFF42A5F5).withValues(alpha: 0.4);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isDisabled ? null : _showHint,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb, color: Colors.white.withValues(alpha: isDisabled ? 0.5 : 1.0), size: 20),
              const SizedBox(width: 6),
              Text(
                '提示 $_hintsLeft/${GameConfig.maxHints}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: isDisabled ? 0.5 : 1.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestartButton() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(_initGame),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFF7043),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF7043).withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh, color: Colors.white, size: 20),
              SizedBox(width: 6),
              Text(
                '重新开始',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// ==================== 大号信息卡片组件 ====================
class _LargeInfoCard extends StatelessWidget {
  final String icon;
  final String title;
  final String value;
  final Color color;
  final bool isHighlighted;

  const _LargeInfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 水果格子组件 ====================
class _FruitCell extends StatelessWidget {
  final _CellData? cellData;
  final bool isHint;
  final bool isHintTarget;

  const _FruitCell({
    required this.cellData,
    this.isHint = false,
    this.isHintTarget = false,
  });

  @override
  Widget build(BuildContext context) {
    if (cellData == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    final color = FruitConfig.colors[cellData!.fruitType.index];
    final emoji = FruitConfig.emojis[cellData!.fruitType.index];
    final isBomb = cellData!.isBomb;

    // 边框颜色
    Color borderColor;
    double borderWidth;
    List<BoxShadow> extraShadows = [];

    if (isHint) {
      borderColor = const Color(0xFF42A5F5);
      borderWidth = 3;
      extraShadows.add(BoxShadow(
        color: const Color(0xFF42A5F5).withValues(alpha: 0.8),
        blurRadius: 12,
        spreadRadius: 3,
      ));
    } else if (isHintTarget) {
      borderColor = const Color(0xFF42A5F5).withValues(alpha: 0.6);
      borderWidth = 2.5;
      extraShadows.add(BoxShadow(
        color: const Color(0xFF42A5F5).withValues(alpha: 0.4),
        blurRadius: 8,
        spreadRadius: 2,
      ));
    } else if (isBomb) {
      borderColor = const Color(0xFFFF8C00);
      borderWidth = 2.5;
      extraShadows.add(BoxShadow(
        color: const Color(0xFFFF8C00).withValues(alpha: 0.6),
        blurRadius: 8,
        spreadRadius: 2,
      ));
    } else {
      borderColor = Colors.white.withValues(alpha: 0.3);
      borderWidth = 1;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isBomb
              ? [color, color.withValues(alpha: 0.6), const Color(0xFFFF8C00).withValues(alpha: 0.3)]
              : [color, color.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: [
          ...extraShadows,
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 3,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 水果 emoji
          Text(
            emoji,
            style: TextStyle(fontSize: isBomb ? 18 : 24),
          ),
          // 炸弹标记
          if (isBomb)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6600),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('💣', style: TextStyle(fontSize: 10)),
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== 游戏结束弹窗 ====================
class _GameOverDialog extends StatelessWidget {
  final bool isWin;
  final int score;
  final int targetScore;
  final int movesLeft;
  final int maxCombo;
  final int bonusPoints;
  final VoidCallback onRestart;
  final VoidCallback onHome;

  const _GameOverDialog({
    required this.isWin,
    required this.score,
    required this.targetScore,
    required this.movesLeft,
    required this.maxCombo,
    required this.bonusPoints,
    required this.onRestart,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isWin
                ? [const Color(0xFFFFF9E6), const Color(0xFFFFF3E0)]
                : [const Color(0xFFF5F5F5), const Color(0xFFEEEEEE)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Text(
              isWin ? '🎉 通关成功！' : '😢 步数用尽！',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isWin ? const Color(0xFF6BCB77) : const Color(0xFF9E9E9E),
              ),
            ),

            const SizedBox(height: 24),

            // 结果图标
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isWin
                      ? [const Color(0xFFFFD700), const Color(0xFFFFB300)]
                      : [const Color(0xFF9E9E9E), const Color(0xFF757575)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  isWin ? '🏆' : '💪',
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 详细数据
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _ResultRow(label: '最终得分', value: '$score'),
                  _ResultRow(label: '目标分数', value: '$targetScore'),
                  if (isWin)
                    _ResultRow(label: '剩余步数', value: '$movesLeft 步')
                  else
                    _ResultRow(label: '还差', value: '${targetScore - score} 分'),
                  _ResultRow(label: '最高连击', value: '$maxCombo 连击'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 积分奖励
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💰', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text(
                    '+$bonusPoints 积分',
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

            // 按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onRestart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6BCB77),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isWin ? '🎮 下一关' : '🔄 再试一次'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onHome,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF666666),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Color(0xFFDDDDDD)),
                    ),
                    child: const Text('🏠 返回大厅'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
          ),
        ],
      ),
    );
  }
}
