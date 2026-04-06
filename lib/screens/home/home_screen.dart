import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../services/audio_service.dart';
import '../../models/player_model.dart';
import '../../models/game_record_model.dart';
import '../games/gobang_screen.dart';
import '../games/game2048_screen.dart';
import '../games/match3_screen.dart';
import '../games/memory_screen.dart';
import '../games/sudoku_screen.dart';
import '../games/flying_chess_screen.dart';
import '../leaderboard/full_leaderboard_screen.dart';

/// 儿童游戏大厅首页 - 糖果乐园风格
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();

  static String avatarEmoji(String avatar) {
    final char = kCharacters.firstWhere(
      (c) => c['avatar'] == avatar,
      orElse: () => kCharacters.first,
    );
    return char['emoji']!;
  }
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // 使用全局单例
  final AudioService _audioService = AudioService();
  // 游戏列表（糖果色配色）
  final List<_GameEntry> _games = [
    _GameEntry(GameType.gobang, '五子棋', '⚫', const Color(0xFFFF6B9D), 3),
    _GameEntry(GameType.game2048, '2048', '🔢', const Color(0xFF4ECDC4), 2),
    _GameEntry(GameType.match3, '消消乐', '💎', const Color(0xFFFF8A65), 3),
    _GameEntry(GameType.flyingChess, '飞行棋', '✈️', const Color(0xFF81D4FA), 2),
    _GameEntry(GameType.sudoku, '数独', '📝', const Color(0xFFA5D6A7), 3),
    _GameEntry(GameType.memory, '记忆翻牌', '🃏', const Color(0xFFFFB74D), 2),
  ];

  // 动画控制器
  late AnimationController _floatController;
  late List<AnimationController> _cardControllers;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // 卡片入场动画控制器
    _cardControllers = List.generate(
      6,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );

    // 延迟启动入场动画
    Future.delayed(const Duration(milliseconds: 200), () {
      for (int i = 0; i < _cardControllers.length; i++) {
        Future.delayed(Duration(milliseconds: i * 100), () {
          if (mounted) _cardControllers[i].forward();
        });
      }
    });

    // 加载角色数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameProvider>().loadPlayers();
      // 播放背景音乐
      _audioService.playHomeBgm();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 应用进入后台时暂停音乐，回到前台时恢复
    if (state == AppLifecycleState.paused) {
      _audioService.pauseBgm();
    } else if (state == AppLifecycleState.resumed) {
      _audioService.resumeBgm();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _floatController.dispose();
    for (var c in _cardControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _navigateToGame(BuildContext context, String gameType) async {
    HapticFeedback.mediumImpact();

    // 切换到游戏音乐
    BgmType bgmType;
    Widget screen;
    switch (gameType) {
      case GameType.gobang:
        bgmType = BgmType.gobang;
        screen = const GobangScreen();
        break;
      case GameType.game2048:
        bgmType = BgmType.game2048;
        screen = const Game2048Screen();
        break;
      case GameType.match3:
        bgmType = BgmType.match3;
        screen = const Match3Screen();
        break;
      case GameType.flyingChess:
        bgmType = BgmType.flyingChess;
        screen = const FlyingChessScreen();
        break;
      case GameType.sudoku:
        bgmType = BgmType.sudoku;
        screen = const SudokuScreen();
        break;
      case GameType.memory:
        bgmType = BgmType.memory;
        screen = const MemoryScreen();
        break;
      default:
        return;
    }
    _audioService.playBgm(bgmType);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _navigateToLeaderboard(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FullLeaderboardScreen(),
      ),
    );
  }

  void _showCharacterDialog(BuildContext context) {
    final provider = context.read<GameProvider>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('👋 ', style: TextStyle(fontSize: 24)),
            Text('选择角色', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 300,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: provider.allPlayers.map((player) {
              final isCurrent = player.avatar == provider.currentAvatar;
              return GestureDetector(
                onTap: () {
                  provider.switchCharacter(player.avatar);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 80,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrent ? const Color(0xFFFFF9E6) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrent ? const Color(0xFFFFD700) : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isCurrent
                        ? [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.3), blurRadius: 8)]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(player.emoji, style: const TextStyle(fontSize: 36)),
                      const SizedBox(height: 4),
                      Text(
                        player.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? const Color(0xFF2D3436) : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final player = provider.currentPlayer;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF87CEEB), Color(0xFFFFE4E1)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 背景装饰
              const _BackgroundDecorations(),

              // 主内容
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    // 顶部用户栏
                    _TopUserBar(
                      player: player,
                      onCharacterTap: () => _showCharacterDialog(context),
                      onLeaderboardTap: () => _navigateToLeaderboard(context),
                    ),

                    const SizedBox(height: 16),

                    // 游戏卡片网格 - 2行3列固定布局
                    Expanded(
                      flex: 5,
                      child: _buildGameGrid(),
                    ),

                    const SizedBox(height: 12),

                    // 底部周排行榜 - 60px高度
                    const _WeeklyLeaderboardStrip(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameGrid() {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildGameCard(0)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildGameCard(1)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildGameCard(2)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildGameCard(3)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildGameCard(4)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildGameCard(5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameCard(int index) {
    return AnimatedBuilder(
      animation: _cardControllers[index],
      builder: (context, child) {
        final value = _cardControllers[index].value;
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value,
            child: _CandyGameCard(
              game: _games[index],
              onTap: () => _navigateToGame(context, _games[index].type),
              floatController: _floatController,
            ),
          ),
        );
      },
    );
  }
}

// ─── 顶部用户栏 ──────────────────────────────────────────────
class _TopUserBar extends StatelessWidget {
  final Player? player;
  final VoidCallback onCharacterTap;
  final VoidCallback onLeaderboardTap;

  const _TopUserBar({
    required this.player,
    required this.onCharacterTap,
    required this.onLeaderboardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 左侧：64px头像+名称+"点击切换"提示
          GestureDetector(
            onTap: onCharacterTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      player?.emoji ?? '👤',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      player?.name ?? '选择角色',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    const Text(
                      '点击切换',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // 中间：标题
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎮', style: TextStyle(fontSize: 28)),
              SizedBox(width: 6),
              Text(
                '游戏乐园',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
            ],
          ),

          const Spacer(),

          // 右侧：总积分徽章 + 排行榜按钮
          Row(
            children: [
              // 总积分金色徽章
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 4),
                    Text(
                      '${player?.totalScore ?? 0}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 排行榜蓝色按钮
              GestureDetector(
                onTap: onLeaderboardTap,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF64B5F6), Color(0xFF2196F3)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.bar_chart, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 糖果色游戏卡片 ───────────────────────────────────────────
class _CandyGameCard extends StatefulWidget {
  final _GameEntry game;
  final VoidCallback onTap;
  final AnimationController floatController;

  const _CandyGameCard({
    required this.game,
    required this.onTap,
    required this.floatController,
  });

  @override
  State<_CandyGameCard> createState() => _CandyGameCardState();
}

class _CandyGameCardState extends State<_CandyGameCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.game;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        onTapDown: (_) {
          if (mounted) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (mounted) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (mounted) setState(() => _isPressed = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.only(bottom: _isHovered ? 8 : 0),
          child: AnimatedScale(
            scale: _isPressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: g.color.withValues(alpha: 0.6),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: g.color.withValues(alpha: _isHovered ? 0.4 : 0.2),
                    blurRadius: _isHovered ? 16 : 8,
                    spreadRadius: _isHovered ? 2 : 0,
                    offset: Offset(0, _isHovered ? 10 : 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 图标
                    AnimatedBuilder(
                      animation: widget.floatController,
                      builder: (context, child) {
                        final offset = widget.floatController.value * 4 - 2;
                        return Transform.translate(
                          offset: Offset(0, offset),
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  g.color.withValues(alpha: 0.2),
                                  g.color.withValues(alpha: 0.05),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                g.emoji,
                                style: const TextStyle(fontSize: 40),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // 游戏名
                    Text(
                      g.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: g.color,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // 星级
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => Icon(
                          i < g.stars ? Icons.star : Icons.star_border,
                          color: const Color(0xFFFFD700),
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 开始按钮
                    Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [g.color, g.color.withValues(alpha: 0.8)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: g.color.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🎮', style: TextStyle(fontSize: 14)),
                          SizedBox(width: 2),
                          Text(
                            '开始',
                            style: TextStyle(
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 底部周排行榜条 - 60px高度，横向前三名 ─────────────────────────────
class _WeeklyLeaderboardStrip extends StatelessWidget {
  const _WeeklyLeaderboardStrip();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Player>>(
      future: context.read<GameProvider>().getWeeklyLeaderboard(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Text('🏆', style: TextStyle(fontSize: 24)),
                SizedBox(width: 8),
                Text(
                  '本周榜',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3436),
                  ),
                ),
                Spacer(),
                Text(
                  '🎮 暂无记录，快去游戏吧！',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // 取前三名（不过滤，显示所有玩家的周积分排行）
        final top3 = snap.data!.take(3).toList();

        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              const Text(
                '本周榜',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: top3.asMap().entries.map((entry) {
                    final index = entry.key;
                    final player = entry.value;
                    final medals = ['🥇', '🥈', '🥉'];
                    final medalColors = [
                      const Color(0xFFFFD700),
                      const Color(0xFFC0C0C0),
                      const Color(0xFFCD7F32),
                    ];

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(medals[index], style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 6),
                        // 40px头像
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                medalColors[index].withValues(alpha: 0.3),
                                medalColors[index].withValues(alpha: 0.1),
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: medalColors[index].withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(player.emoji, style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 角色名+积分
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${player.weeklyScore}分',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: medalColors[index],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── 背景装饰层 ──────────────────────────────────────────────
class _BackgroundDecorations extends StatelessWidget {
  const _BackgroundDecorations();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        // 白云
        _AnimatedCloud(top: 30, left: 30, size: 100, duration: 20),
        _AnimatedCloud(top: 80, right: 40, size: 70, duration: 25),
        _AnimatedCloud(top: 150, left: 150, size: 60, duration: 18),
        // 气球
        _AnimatedBalloon(top: 120, left: 60, color: Color(0xFFFF6B6B), duration: 5),
        _AnimatedBalloon(top: 180, right: 80, color: Color(0xFF4ECDC4), duration: 6),
        _AnimatedBalloon(top: 60, left: 200, color: Color(0xFFFFE66D), duration: 7),
        // 星星
        _TwinklingStar(top: 40, left: 120),
        _TwinklingStar(top: 100, right: 150),
        _TwinklingStar(top: 200, left: 80),
      ],
    );
  }
}

class _AnimatedCloud extends StatefulWidget {
  final double top;
  final double? left;
  final double? right;
  final double size;
  final int duration;

  const _AnimatedCloud({
    required this.top,
    this.left,
    this.right,
    required this.size,
    required this.duration,
  });

  @override
  State<_AnimatedCloud> createState() => _AnimatedCloudState();
}

class _AnimatedCloudState extends State<_AnimatedCloud>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.duration),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = math.sin(_controller.value * 2 * math.pi) * 15;
        return Positioned(
          top: widget.top,
          left: widget.left != null ? widget.left! + offset : null,
          right: widget.right,
          child: Container(
            width: widget.size,
            height: widget.size * 0.55,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(widget.size * 0.25),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: widget.size * 0.15,
                  top: -widget.size * 0.15,
                  child: Container(
                    width: widget.size * 0.4,
                    height: widget.size * 0.4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: widget.size * 0.15,
                  top: -widget.size * 0.1,
                  child: Container(
                    width: widget.size * 0.35,
                    height: widget.size * 0.35,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedBalloon extends StatefulWidget {
  final double top;
  final double? left;
  final double? right;
  final Color color;
  final int duration;

  const _AnimatedBalloon({
    required this.top,
    this.left,
    this.right,
    required this.color,
    required this.duration,
  });

  @override
  State<_AnimatedBalloon> createState() => _AnimatedBalloonState();
}

class _AnimatedBalloonState extends State<_AnimatedBalloon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.duration),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: widget.top - 15 * _controller.value,
          left: widget.left,
          right: widget.right,
          child: Column(
            children: [
              Container(
                width: 30,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 20,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TwinklingStar extends StatefulWidget {
  final double top;
  final double? left;
  final double? right;

  const _TwinklingStar({required this.top, this.left, this.right});

  @override
  State<_TwinklingStar> createState() => _TwinklingStarState();
}

class _TwinklingStarState extends State<_TwinklingStar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: widget.top,
          left: widget.left,
          right: widget.right,
          child: Opacity(
            opacity: 0.3 + (_controller.value * 0.4),
            child: const Icon(
              Icons.star,
              color: Color(0xFFFFD700),
              size: 20,
            ),
          ),
        );
      },
    );
  }
}

// ─── 数据类 ──────────────────────────────────────────────────
class _GameEntry {
  final String type;
  final String name;
  final String emoji;
  final Color color;
  final int stars;

  const _GameEntry(
    this.type,
    this.name,
    this.emoji,
    this.color,
    this.stars,
  );
}
