import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/player_model.dart';
import '../../models/game_record_model.dart';
import '../../services/audio_service.dart';

/// 全屏排行榜页面 - 6游戏分类标签，6角色完整排名
class FullLeaderboardScreen extends StatefulWidget {
  const FullLeaderboardScreen({super.key});

  @override
  State<FullLeaderboardScreen> createState() => _FullLeaderboardScreenState();
}

class _FullLeaderboardScreenState extends State<FullLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 6个游戏分类标签
  final List<_LeaderboardTab> _tabs = [
    _LeaderboardTab('总榜', '⭐', 'total'),
    _LeaderboardTab('本周榜', '🏆', 'weekly'),
    _LeaderboardTab('五子棋', '⚫', GameType.gobang),
    _LeaderboardTab('2048', '🔢', GameType.game2048),
    _LeaderboardTab('消消乐', '💎', GameType.match3),
    _LeaderboardTab('飞行棋', '✈️', GameType.flyingChess),
    _LeaderboardTab('数独', '📝', GameType.sudoku),
    _LeaderboardTab('翻牌', '🃏', GameType.memory),
  ];

  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    // 排行榜页面继续播放首页音乐
    _audioService.playHomeBgm();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
              // 顶部栏：返回 + 标题 + 关闭
              _buildAppBar(),

              const SizedBox(height: 12),

              // 标签栏 - 横向滚动
              _buildTabBar(),

              const SizedBox(height: 12),

              // 排行榜内容
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _tabs.map((tab) => _buildTabContent(tab)).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 返回按钮
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back, color: Color(0xFF2D3436), size: 24),
            ),
          ),

          const Spacer(),

          // 标题
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🏆', style: TextStyle(fontSize: 24)),
                SizedBox(width: 8),
                Text(
                  '排行榜',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3436),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // 关闭按钮
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.close, color: Color(0xFF2D3436), size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        itemBuilder: (context, index) {
          final tab = _tabs[index];
          final isSelected = _tabController.index == index;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _tabController.animateTo(index);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFFD700)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? const Color(0xFFFFD700).withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tab.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabContent(_LeaderboardTab tab) {
    switch (tab.type) {
      case 'total':
        return _buildLeaderboardList(
          future: context.read<GameProvider>().getTotalLeaderboard(),
          getScore: (p) => p.totalScore,
        );
      case 'weekly':
        return _buildLeaderboardList(
          future: context.read<GameProvider>().getWeeklyLeaderboard(),
          getScore: (p) => p.weeklyScore,
        );
      case GameType.gobang:
        return _buildLeaderboardList(
          future: context.read<GameProvider>().getGobangLeaderboard(),
          getScore: (p) => p.gobangScore,
          suffix: '分',
        );
      case GameType.game2048:
        return _buildLeaderboardList(
          future: context.read<GameProvider>().get2048Leaderboard(),
          getScore: (p) => p.game2048Score,
          suffix: '分',
        );
      case GameType.match3:
        return _buildLeaderboardList(
          future: context.read<GameProvider>().getMatch3Leaderboard(),
          getScore: (p) => p.match3Score,
          suffix: '分',
        );
      case GameType.flyingChess:
        return _buildLeaderboardList(
          future: context.read<GameProvider>().getFlyingChessLeaderboard(),
          getScore: (p) => p.flyingScore,
          suffix: '分',
        );
      case GameType.sudoku:
        return _buildLeaderboardList(
          future: context.read<GameProvider>().getSudokuLeaderboard(),
          getScore: (p) => p.sudokuScore,
          suffix: '分',
        );
      case GameType.memory:
        return _buildLeaderboardList(
          future: context.read<GameProvider>().getMemoryLeaderboard(),
          getScore: (p) => p.memoryScore,
          suffix: '分',
        );
      default:
        return _buildLeaderboardList(
          future: context.read<GameProvider>().getTotalLeaderboard(),
          getScore: (p) => p.totalScore,
        );
    }
  }

  Widget _buildLeaderboardList({
    required Future<List<Player>> future,
    required int Function(Player) getScore,
    String suffix = '',
  }) {
    return FutureBuilder<List<Player>>(
      future: future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFD700)),
          );
        }

        final players = snap.data!;
        final currentAvatar = context.read<GameProvider>().currentAvatar;

        // 确保显示所有6个角色
        final allPlayers = _ensureAllPlayers(players);

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: allPlayers.length,
          itemBuilder: (context, index) {
            final player = allPlayers[index];
            final score = getScore(player);
            final isCurrent = player.avatar == currentAvatar;
            final rank = index;

            return _buildRankItem(
              rank: rank,
              player: player,
              score: score,
              isCurrent: isCurrent,
              suffix: suffix,
            );
          },
        );
      },
    );
  }

  /// 确保列表包含所有6个角色
  List<Player> _ensureAllPlayers(List<Player> players) {
    final result = <Player>[];
    for (final char in kCharacters) {
      final existing = players.firstWhere(
        (p) => p.avatar == char['avatar'],
        orElse: () => Player(
          avatar: char['avatar']!,
          name: char['name']!,
        ),
      );
      result.add(existing);
    }
    // 按分数排序
    return result;
  }

  Widget _buildRankItem({
    required int rank,
    required Player player,
    required int score,
    required bool isCurrent,
    String suffix = '',
  }) {
    final isTop3 = rank < 3;
    final medalEmojis = ['🥇', '🥈', '🥉'];
    final rankColors = [
      const Color(0xFFFFD700), // 金色
      const Color(0xFFC0C0C0), // 银色
      const Color(0xFFCD7F32), // 铜色
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // 前3名彩色背景，4-6名白色背景
        color: isTop3
            ? rankColors[rank].withValues(alpha: 0.15)
            : isCurrent
                ? const Color(0xFFFFF9E6) // 当前角色淡黄高亮
                : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTop3
              ? rankColors[rank].withValues(alpha: 0.5)
              : isCurrent
                  ? const Color(0xFFFFD700)
                  : Colors.white.withValues(alpha: 0.5),
          width: isTop3 || isCurrent ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // 排名 - 前3名显示奖牌，4-6名显示数字
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isTop3 ? rankColors[rank] : Colors.grey[200],
              shape: BoxShape.circle,
              boxShadow: isTop3
                  ? [
                      BoxShadow(
                        color: rankColors[rank].withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isTop3
                  ? Text(
                      medalEmojis[rank],
                      style: const TextStyle(fontSize: 24),
                    )
                  : Text(
                      '${rank + 1}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 14),

          // 48px头像
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (isTop3 ? rankColors[rank] : const Color(0xFF87CEEB))
                      .withValues(alpha: 0.3),
                  (isTop3 ? rankColors[rank] : const Color(0xFF87CEEB))
                      .withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: isCurrent
                    ? const Color(0xFFFFD700)
                    : (isTop3 ? rankColors[rank] : Colors.grey[300])!,
                width: isCurrent ? 3 : 2,
              ),
            ),
            child: Center(
              child: Text(
                player.emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // 角色名 + 标签
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      player.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '当前',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 积分数字（只显示数字，无百分比）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isTop3
                    ? [rankColors[rank], rankColors[rank].withValues(alpha: 0.8)]
                    : [const Color(0xFF87CEEB), const Color(0xFF64B5F6)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isTop3 ? rankColors[rank] : const Color(0xFF87CEEB))
                      .withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '$score$suffix',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 数据类 ──────────────────────────────────────────────────
class _LeaderboardTab {
  final String label;
  final String icon;
  final String type;

  const _LeaderboardTab(this.label, this.icon, this.type);
}
