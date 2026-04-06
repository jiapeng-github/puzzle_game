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
}

class _Match3ScreenState extends State<Match3Screen>
    with TickerProviderStateMixin {
  // 游戏网格
  late List<List<FruitType?>> _grid;

  // 游戏状态
  int _score = 0;
  int _movesLeft = GameConfig.maxMoves;
  int _combo = 0;
  int _maxCombo = 0;
  bool _gameOver = false;
  bool _isWon = false;
  bool _isProcessing = false;

  // 选中状态
  int? _selectedRow;
  int? _selectedCol;

  // 动画
  late AnimationController _comboController;
  late AnimationController _shakeController;

  // 连击提示
  String? _comboText;
  double _comboOpacity = 0;

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
        _grid[r][c] = _generateFruit(r, c);
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
    _selectedRow = null;
    _selectedCol = null;
    _comboText = null;
    _comboOpacity = 0;
    _startTime = DateTime.now();
  }

  FruitType _generateFruit(int row, int col) {
    int typeIndex;
    do {
      typeIndex = Random().nextInt(6);
    } while (_wouldCreateMatch(row, col, typeIndex));

    return FruitType.values[typeIndex];
  }

  bool _wouldCreateMatch(int row, int col, int typeIndex) {
    // 检查横向
    int horizontalCount = 1;
    for (int c = col - 1; c >= 0 && _grid[row][c]?.index == typeIndex; c--) {
      horizontalCount++;
    }
    for (int c = col + 1; c < GameConfig.gridSize && _grid[row][c]?.index == typeIndex; c++) {
      horizontalCount++;
    }
    if (horizontalCount >= 3) return true;

    // 检查纵向
    int verticalCount = 1;
    for (int r = row - 1; r >= 0 && _grid[r][col]?.index == typeIndex; r--) {
      verticalCount++;
    }
    for (int r = row + 1; r < GameConfig.gridSize && _grid[r][col]?.index == typeIndex; r++) {
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
            _grid[r][c] = _generateFruit(r, c);
            hasMatch = true;
          }
        }
      }
    }
  }

  bool _hasMatchAt(int r, int c) {
    if (_grid[r][c] == null) return false;
    final type = _grid[r][c]!;

    // 横向检查
    int horizontalCount = 1;
    for (int i = c - 1; i >= 0 && _grid[r][i] == type; i--) horizontalCount++;
    for (int i = c + 1; i < GameConfig.gridSize && _grid[r][i] == type; i++) horizontalCount++;
    if (horizontalCount >= 3) return true;

    // 纵向检查
    int verticalCount = 1;
    for (int i = r - 1; i >= 0 && _grid[i][c] == type; i--) verticalCount++;
    for (int i = r + 1; i < GameConfig.gridSize && _grid[i][c] == type; i++) verticalCount++;
    if (verticalCount >= 3) return true;

    return false;
  }

  void _onFruitTap(int row, int col) {
    if (_gameOver || _isProcessing) return;

    HapticFeedback.lightImpact();

    if (_selectedRow == null) {
      setState(() {
        _selectedRow = row;
        _selectedCol = col;
      });
      return;
    }

    // 点击同一个水果，取消选中
    if (_selectedRow == row && _selectedCol == col) {
      setState(() {
        _selectedRow = null;
        _selectedCol = null;
      });
      return;
    }

    // 检查是否相邻
    final dr = (row - _selectedRow!).abs();
    final dc = (col - _selectedCol!).abs();

    if ((dr == 1 && dc == 0) || (dr == 0 && dc == 1)) {
      _trySwap(_selectedRow!, _selectedCol!, row, col);
    } else {
      // 不相邻，选中新水果
      setState(() {
        _selectedRow = row;
        _selectedCol = col;
      });
    }
  }

  Future<void> _trySwap(int r1, int c1, int r2, int c2) async {
    setState(() {
      _isProcessing = true;
      _selectedRow = null;
      _selectedCol = null;
    });

    // 执行交换
    final temp = _grid[r1][c1];
    _grid[r1][c1] = _grid[r2][c2];
    _grid[r2][c2] = temp;

    // 检查是否有消除
    final matches = _findMatches();

    if (matches.isEmpty) {
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

  Set<(int, int)> _findMatches() {
    final matches = <(int, int)>{};

    // 横向检查
    for (int r = 0; r < GameConfig.gridSize; r++) {
      for (int c = 0; c <= GameConfig.gridSize - 3; c++) {
        final fruit = _grid[r][c];
        if (fruit == null) continue;

        int count = 1;
        while (c + count < GameConfig.gridSize && _grid[r][c + count] == fruit) {
          count++;
        }

        if (count >= 3) {
          for (int i = 0; i < count; i++) {
            matches.add((r, c + i));
          }
        }
      }
    }

    // 纵向检查
    for (int c = 0; c < GameConfig.gridSize; c++) {
      for (int r = 0; r <= GameConfig.gridSize - 3; r++) {
        final fruit = _grid[r][c];
        if (fruit == null) continue;

        int count = 1;
        while (r + count < GameConfig.gridSize && _grid[r + count][c] == fruit) {
          count++;
        }

        if (count >= 3) {
          for (int i = 0; i < count; i++) {
            matches.add((r + i, c));
          }
        }
      }
    }

    return matches;
  }

  Future<void> _processMatches() async {
    while (true) {
      final matches = _findMatches();
      if (matches.isEmpty) break;

      _combo++;
      if (_combo > _maxCombo) _maxCombo = _combo;

      // 显示连击
      _showCombo();

      // 播放消除音效
      AudioService().playSfx('audio/sfx/eliminate.mp3');

      // 计算分数
      int baseScore = matches.length * 10;
      double multiplier = _getComboMultiplier();
      int roundScore = (baseScore * multiplier).round();
      _score += roundScore;

      // 标记消除
      setState(() {
        for (final (r, c) in matches) {
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
        final column = <FruitType?>[];
        for (int r = 0; r < GameConfig.gridSize; r++) {
          if (_grid[r][c] != null) {
            column.add(_grid[r][c]);
          }
        }

        // 填充新水果
        while (column.length < GameConfig.gridSize) {
          column.insert(0, FruitType.values[Random().nextInt(6)]);
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

  void _showHint() {
    // 查找可消除的组合
    for (int r = 0; r < GameConfig.gridSize; r++) {
      for (int c = 0; c < GameConfig.gridSize; c++) {
        // 尝试与右边交换
        if (c < GameConfig.gridSize - 1) {
          _swapTemp(r, c, r, c + 1);
          if (_findMatches().isNotEmpty) {
            _swapTemp(r, c, r, c + 1);
            setState(() {
              _selectedRow = r;
              _selectedCol = c;
            });
            return;
          }
          _swapTemp(r, c, r, c + 1);
        }
        // 尝试与下边交换
        if (r < GameConfig.gridSize - 1) {
          _swapTemp(r, c, r + 1, c);
          if (_findMatches().isNotEmpty) {
            _swapTemp(r, c, r + 1, c);
            setState(() {
              _selectedRow = r;
              _selectedCol = c;
            });
            return;
          }
          _swapTemp(r, c, r + 1, c);
        }
      }
    }
  }

  void _swapTemp(int r1, int c1, int r2, int c2) {
    final temp = _grid[r1][c1];
    _grid[r1][c1] = _grid[r2][c2];
    _grid[r2][c2] = temp;
  }

  Widget _buildGameGrid(double cellSize) {
    return Container(
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
              final fruit = _grid[r][c];
              final isSelected = _selectedRow == r && _selectedCol == c;

              return _FruitCell(
                fruit: fruit,
                isSelected: isSelected,
                onTap: () => _onFruitTap(r, c),
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
          _buildHintItem('点击选中水果'),
          _buildHintItem('点击相邻交换'),
          _buildHintItem('3个相同消除'),
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _showHint,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF42A5F5),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF42A5F5).withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb, color: Colors.white, size: 20),
              SizedBox(width: 6),
              Text(
                '提示',
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
  final FruitType? fruit;
  final bool isSelected;
  final VoidCallback onTap;

  const _FruitCell({
    required this.fruit,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (fruit == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    final color = FruitConfig.colors[fruit!.index];
    final emoji = FruitConfig.emojis[fruit!.index];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withValues(alpha: 0.75),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF9B59B6) : Colors.white.withValues(alpha: 0.3),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color(0xFF9B59B6).withValues(alpha: 0.8),
                blurRadius: 12,
                spreadRadius: 3,
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 3,
              offset: const Offset(1, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 24),
          ),
        ),
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
