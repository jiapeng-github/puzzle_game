import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/player_model.dart';
import '../../models/game_record_model.dart';
import '../../services/audio_service.dart';

/// 2048 游戏 - 横屏布局优化版
class Game2048Screen extends StatefulWidget {
  const Game2048Screen({super.key});

  @override
  State<Game2048Screen> createState() => _Game2048ScreenState();
}

class _Game2048ScreenState extends State<Game2048Screen>
    with TickerProviderStateMixin {
  static const int size = 4;
  static const double gridSize = 620.0;

  late List<List<int>> _grid;
  int _score = 0;
  int _bestScore = 0;
  int _highestTile = 0;
  bool _gameOver = false;
  bool _won = false;
  bool _showNewRecord = false;
  late DateTime _startTime;

  // 动画控制器
  late AnimationController _glowController;
  final Map<String, AnimationController> _tileAnimations = {};

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _newGame();
    AudioService().playBgm(BgmType.game2048);

    // 延迟加载最高分
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBestScore();
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _focusNode.dispose();
    _clearTileAnimations();
    super.dispose();
  }

  void _clearTileAnimations() {
    for (var controller in _tileAnimations.values) {
      controller.dispose();
    }
    _tileAnimations.clear();
  }

  void _loadBestScore() {
    if (!mounted) return;
    final provider = context.read<GameProvider>();
    final player = provider.currentPlayer;
    if (player != null) {
      setState(() {
        _bestScore = player.best2048;
      });
    }
  }

  void _newGame() {
    _clearTileAnimations();
    _grid = List.generate(size, (_) => List.filled(size, 0));
    _score = 0;
    _highestTile = 0;
    _gameOver = false;
    _won = false;
    _showNewRecord = false;
    _startTime = DateTime.now();
    _addRandom();
    _addRandom();
  }

  void _addRandom() {
    final empty = [
      for (int r = 0; r < size; r++)
        for (int c = 0; c < size; c++)
          if (_grid[r][c] == 0) (r, c)
    ];
    if (empty.isEmpty) return;
    final pos = empty[math.Random().nextInt(empty.length)];
    _grid[pos.$1][pos.$2] = math.Random().nextInt(10) < 9 ? 2 : 4;

    if (mounted) {
      final key = '${pos.$1},${pos.$2}';
      _tileAnimations[key]?.dispose();
      _tileAnimations[key] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      );
      _tileAnimations[key]?.forward(from: 0);
    }
  }

  List<int> _mergeLeft(List<int> row) {
    final filtered = row.where((v) => v != 0).toList();
    final merged = <int>[];
    int i = 0;
    while (i < filtered.length) {
      if (i + 1 < filtered.length && filtered[i] == filtered[i + 1]) {
        final val = filtered[i] * 2;
        merged.add(val);
        _score += val;
        if (val > _highestTile) _highestTile = val;
        if (val == 2048 && !_won) _won = true;
        i += 2;
      } else {
        merged.add(filtered[i]);
        i++;
      }
    }
    while (merged.length < size) merged.add(0);
    return merged;
  }

  bool _move(String dir) {
    final prev = _grid.map((r) => List<int>.from(r)).toList();
    for (int r = 0; r < size; r++) {
      switch (dir) {
        case 'left':
          _grid[r] = _mergeLeft(_grid[r]);
          break;
        case 'right':
          _grid[r] = _mergeLeft(_grid[r].reversed.toList()).reversed.toList();
          break;
        case 'up':
          final col = [for (int c2 = 0; c2 < size; c2++) _grid[c2][r]];
          final merged = _mergeLeft(col);
          for (int c2 = 0; c2 < size; c2++) _grid[c2][r] = merged[c2];
          break;
        case 'down':
          final col = [for (int c2 = 0; c2 < size; c2++) _grid[c2][r]];
          final merged = _mergeLeft(col.reversed.toList()).reversed.toList();
          for (int c2 = 0; c2 < size; c2++) _grid[c2][r] = merged[c2];
          break;
      }
    }
    bool changed = false;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_grid[r][c] != prev[r][c]) changed = true;
      }
    }
    return changed;
  }

  bool _canMove() {
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_grid[r][c] == 0) return true;
        if (c + 1 < size && _grid[r][c] == _grid[r][c + 1]) return true;
        if (r + 1 < size && _grid[r][c] == _grid[r + 1][c]) return true;
      }
    }
    return false;
  }

  // 修复滑动方向：正向滑动
  void _handleSwipe(String dir) {
    if (_gameOver) return;

    HapticFeedback.lightImpact();

    setState(() {
      if (_move(dir)) {
        // 播放移动音效
        AudioService().playMoveSfx();
        _addRandom();
        if (_score > _bestScore && !_showNewRecord) {
          _showNewRecord = true;
        }
        if (!_canMove()) {
          _gameOver = true;
          _showGameOverDialog();
        }
        if (_won && !_gameOver) {
          _showWinDialog();
        }
      }
    });
  }

  /// 计算奖励积分
  int _calculateBonusScore() {
    int bonus = 0;

    // 最高数字奖励
    if (_highestTile >= 2048) {
      bonus += 200;
    } else if (_highestTile >= 1024) {
      bonus += 100;
    } else {
      bonus += 20; // 参与奖
    }

    return bonus;
  }

  Future<void> _saveResult() async {
    final duration = DateTime.now().difference(_startTime).inSeconds;
    final bonusScore = _calculateBonusScore();

    await context.read<GameProvider>().saveGameResult(
          gameType: GameType.game2048,
          score: bonusScore,
          duration: duration,
          isWin: _won,
        );
  }

  // ==================== 颜色配置 ====================
  Color _tileBgColor(int val) {
    // 粉橙渐变配色
    const colors = {
      2: Color(0xFFFFE4E1),    // 浅粉
      4: Color(0xFFFFCCBC),    // 珊瑚粉
      8: Color(0xFFFFAB91),    // 橙粉
      16: Color(0xFFFF8A65),   // 深橙粉
      32: Color(0xFFFF7043),   // 橙色
      64: Color(0xFFFF5722),   // 深橙
      128: Color(0xFFF06292),  // 粉红
      256: Color(0xFFEC407A),  // 玫红
      512: Color(0xFFE91E63),  // 红粉
      1024: Color(0xFFD81B60), // 深玫红
      2048: Color(0xFFFFD700), // 金色
    };
    return colors[val] ?? const Color(0xFF8E24AA);
  }

  Color _tileTextColor(int val) {
    return val <= 4 ? const Color(0xFF5D4037) : Colors.white;
  }

  bool _shouldGlow(int val) => val >= 128;

  double _getTileFontSize(int val, double cellSize) {
    if (val >= 1000) return cellSize * 0.3;
    if (val >= 100) return cellSize * 0.38;
    return cellSize * 0.45;
  }

  // ==================== 对话框 ====================
  void _showGameOverDialog() async {
    await _saveResult();

    if (!mounted) return;

    // 播放结算音效
    AudioService().playWinningSfx();

    final bonusScore = _calculateBonusScore();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GameOverDialog(
        score: _score,
        highestTile: _highestTile,
        bestScore: _bestScore,
        bonusScore: bonusScore,
        won: _won,
        onRestart: () async {
          Navigator.of(ctx).pop();
          await context.read<GameProvider>().loadPlayers();
          AudioService().playBgm(BgmType.game2048);
          setState(_newGame);
        },
        onHome: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
          AudioService().playHomeBgm();
        },
      ),
    );
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFFFF9E6),
        title: const Text(
          '🏆 恭喜达成2048！',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFFD700)),
        ),
        content: const Text(
          '继续挑战更高分数吧！',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              AudioService().playHomeBgm();
            },
            child: const Text('返回大厅'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('继续挑战'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFFF9E6),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh, color: Color(0xFFFF6B6B)),
            SizedBox(width: 8),
            Text('重新开始？', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '当前游戏进度将丢失',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(_newGame);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('重新开始'),
          ),
        ],
      ),
    );
  }

  // ==================== 构建UI ====================
  // 键盘焦点
  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<GameProvider>().currentPlayer;
    final cellSize = (gridSize - 60) / size;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _handleSwipe('left');
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _handleSwipe('right');
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _handleSwipe('up');
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _handleSwipe('down');
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF5F0E6), Color(0xFFEDE6D9)],
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 左侧游戏网格 - 固定宽度
                        SizedBox(
                          width: gridSize,
                          child: _buildGameGrid(cellSize),
                        ),

                        const SizedBox(width: 16),

                        // 右侧信息面板 - 剩余空间，顶部对齐
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
      ),
    );
  }

  Widget _buildTopBar(Player? player) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          Material(
            color: const Color(0xFF87CEEB).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
                AudioService().playHomeBgm();
              },
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_back, color: Color(0xFF2D3436), size: 22),
              ),
            ),
          ),

          // 居中标题
          Expanded(
            child: Center(
              child: const Text(
                '🔢 2048',
                style: TextStyle(
                  fontSize: 20,
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3D2914)),
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
                const Text('⭐', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  '${player?.totalScore ?? 0}',
                  style: const TextStyle(
                    fontSize: 16,
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

  Widget _buildGameGrid(double cellSize) {
    return GestureDetector(
      // 正向滑动：左滑=向左，右滑=向右，上滑=向上，下滑=向下
      onVerticalDragEnd: (d) {
        if (d.primaryVelocity! < 0) {
          _handleSwipe('up');  // 上滑向上
        } else {
          _handleSwipe('down'); // 下滑向下
        }
      },
      onHorizontalDragEnd: (d) {
        if (d.primaryVelocity! < 0) {
          _handleSwipe('left');  // 左滑向左
        } else {
          _handleSwipe('right'); // 右滑向右
        }
      },
      child: Container(
        width: gridSize,
        height: gridSize,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            size,
            (r) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(size, (c) {
                final val = _grid[r][c];
                final key = '$r,$c';
                final animController = _tileAnimations[key];

                Widget tile = Container(
                  width: cellSize,
                  height: cellSize,
                  decoration: BoxDecoration(
                    color: val == 0
                        ? const Color(0xFFE8E0D5)
                        : _tileBgColor(val),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: val > 0
                        ? [
                            BoxShadow(
                              color: _shouldGlow(val)
                                  ? _tileBgColor(val).withValues(alpha: 0.6)
                                  : _tileBgColor(val).withValues(alpha: 0.3),
                              blurRadius: _shouldGlow(val) ? 16 : 8,
                              spreadRadius: _shouldGlow(val) ? 2 : 0,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: val == 0
                      ? null
                      : Center(
                          child: Text(
                            '$val',
                            style: TextStyle(
                              fontSize: _getTileFontSize(val, cellSize),
                              fontWeight: FontWeight.bold,
                              color: _tileTextColor(val),
                            ),
                          ),
                        ),
                );

                if (animController != null && val > 0) {
                  final baseTile = tile;
                  tile = AnimatedBuilder(
                    animation: animController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: animController.value,
                        child: child,
                      );
                    },
                    child: baseTile,
                  );
                }

                return tile;
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return SizedBox(
      height: gridSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 区域1：双列卡片 - 当前得分/目标分数
          Row(
            children: [
              Expanded(
                child: _LargeInfoCard(
                  icon: '🎯',
                  title: '最高数字',
                  value: '$_highestTile',
                  color: const Color(0xFF4FC3F7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LargeInfoCard(
                  icon: '🏆',
                  title: '目标分数',
                  value: '2048',
                  color: const Color(0xFFFF6B6B),
                  subtitle: _highestTile >= 2048 ? '✅' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 区域2：游戏进度卡片（单列）
          _buildProgressCard(),
          const SizedBox(height: 14),

          // 区域3：双列卡片 - 游戏规则/积分奖励（严格等高）
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _buildRulesCard(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildBonusCard(),
                ),
              ],
            ),
          ),

          const Spacer(),

          // 区域5：底部重新开始按钮（全宽）- 与左侧网格底部对齐
          _buildRestartButton(),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final progress = math.min(_highestTile / 2048, 1.0);
    final percentage = (progress * 100).toInt();

    Color progressColor;
    if (percentage < 25) {
      progressColor = const Color(0xFF4CAF50);
    } else if (percentage < 50) {
      progressColor = const Color(0xFFFFC107);
    } else if (percentage < 75) {
      progressColor = const Color(0xFFFF9800);
    } else {
      progressColor = const Color(0xFFF44336);
    }

    return Container(
      padding: const EdgeInsets.all(22),
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
              const Text('📈', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              const Text(
                '游戏进度',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3D2914)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(progressColor),
              minHeight: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$percentage%',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: progressColor),
              ),
              if (_highestTile >= 2048)
                const Text(
                  '🏆 已达成',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFFD700)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRulesCard() {
    return Container(
      padding: const EdgeInsets.all(22),
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
              Text('📋', style: TextStyle(fontSize: 22)),
              SizedBox(width: 10),
              Text(
                '游戏规则',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3D2914)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRuleItem('相同数字碰撞合并'),
          _buildRuleItem('达成2048即胜利'),
          _buildRuleItem('无法移动则结束'),
        ],
      ),
    );
  }

  Widget _buildBonusCard() {
    return Container(
      padding: const EdgeInsets.all(22),
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
              Text('🎁', style: TextStyle(fontSize: 22)),
              SizedBox(width: 10),
              Text(
                '积分奖励',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3D2914)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRuleItem('达成2048: +200', color: const Color(0xFFFFD700)),
          _buildRuleItem('达成1024: +100', color: const Color(0xFF4FC3F7)),
          _buildRuleItem('参与奖: +20', color: const Color(0xFF4CAF50)),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: color ?? const Color(0xFF4CAF50)),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 14, color: color ?? const Color(0xFF666666))),
        ],
      ),
    );
  }

  Widget _buildRestartButton() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _showResetConfirm,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFB6C1), Color(0xFF87CEEB)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB0A0C0).withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                '重新开始',
                style: TextStyle(
                  fontSize: 16,
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
  final String? subtitle;

  const _LargeInfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
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
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, color: Color(0xFF666666)),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
            ),
        ],
      ),
    );
  }
}

// ==================== 游戏结束对话框 ====================
class _GameOverDialog extends StatelessWidget {
  final int score;
  final int highestTile;
  final int bestScore;
  final int bonusScore;
  final bool won;
  final VoidCallback onRestart;
  final VoidCallback onHome;

  const _GameOverDialog({
    required this.score,
    required this.highestTile,
    required this.bestScore,
    required this.bonusScore,
    required this.won,
    required this.onRestart,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFFFF9E6),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            won ? '🏆' : '😢',
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 8),
          Text(
            won ? '恭喜获胜！' : '游戏结束！',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: won ? const Color(0xFFFFD700) : const Color(0xFFFF6B6B),
            ),
          ),
          const SizedBox(height: 24),

          // 奖励明细
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildScoreRow('最高数字', '$highestTile'),
                const SizedBox(height: 12),
                const Divider(thickness: 2),
                const SizedBox(height: 8),
                const Text(
                  '🎁 奖励明细',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF6B6B)),
                ),
                const SizedBox(height: 8),
                _buildBonusItem(
                  highestTile >= 2048 ? '达成2048' : (highestTile >= 1024 ? '达成1024' : '参与奖'),
                  highestTile >= 2048 ? '+200' : (highestTile >= 1024 ? '+100' : '+20'),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('总计积分', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      '+$bonusScore',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6B6B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 按钮
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onHome,
                  icon: const Icon(Icons.home),
                  label: const Text('返回大厅'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB6C1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(Icons.refresh),
                  label: const Text('再来一局'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4FC3F7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildBonusItem(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF666666))),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? const Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }
}
