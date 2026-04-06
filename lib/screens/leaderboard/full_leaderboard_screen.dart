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
        color: const Color(0xFFF5F7FA),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              const SizedBox(height: 12),
              _buildTabBar(),
              const SizedBox(height: 12),
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
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back, color: Color(0xFF2D3436), size: 22),
            ),
          ),
          // 标题 - 居中
          const Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🏆', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 6),
                  Text(
                    '排行榜',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 占位，保持标题居中
          const SizedBox(width: 42),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 44,
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
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4A90D9) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tab.icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
          getScore: (p) => p.gobangWins,
          suffix: '胜',
        );
      case GameType.game2048:
        return _buildLeaderboardList(
          future: context.read<GameProvider>().get2048Leaderboard(),
          getScore: (p) => p.best2048,
          suffix: '分',
        );
      case GameType.match3:
        return _buildLeaderboardList(
          future: context.read<GameProvider>().getMatch3Leaderboard(),
          getScore: (p) => p.bestMatch3,
          suffix: '分',
        );
      case GameType.flyingChess:
        return _buildLeaderboardList(
          future: context.read<GameProvider>().getFlyingChessLeaderboard(),
          getScore: (p) => p.bestFlying,
          suffix: '分',
        );
      case GameType.sudoku:
        return _buildLeaderboardList(
          future: context.read<GameProvider>().getSudokuLeaderboard(),
          getScore: (p) => p.bestSudoku,
          suffix: '秒',
          isTime: true,
        );
      case GameType.memory:
        return _buildLeaderboardList(
          future: context.read<GameProvider>().getMemoryLeaderboard(),
          getScore: (p) => p.bestMemory,
          suffix: '秒',
          isTime: true,
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
    bool isTime = false,
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
              isTime: isTime,
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
    bool isTime = false,
  }) {
    final isTop3 = rank < 3;
    final medalEmojis = ['🥇', '🥈', '🥉'];
    final rankColors = [
      const Color(0xFFFFB800),
      const Color(0xFF9CA3AF),
      const Color(0xFFCD7F32),
    ];

    // 格式化分数显示
    String displayScore;
    if (isTime && score > 0) {
      final m = score ~/ 60;
      final s = score % 60;
      displayScore = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    } else if (isTime && score == 0) {
      displayScore = '--:--';
    } else {
      displayScore = '$score';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFFFFF8E1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isCurrent
            ? Border.all(color: const Color(0xFF4A90D9), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isTop3 ? rankColors[rank].withValues(alpha: 0.15) : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isTop3
                  ? Text(medalEmojis[rank], style: const TextStyle(fontSize: 20))
                  : Text(
                      '${rank + 1}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(player.emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3436),
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90D9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '当前',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isTop3 ? rankColors[rank] : const Color(0xFF4A90D9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isTime && score > 0 ? displayScore : '$displayScore$suffix',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
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
