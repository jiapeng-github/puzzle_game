import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/player_model.dart';
import '../../models/game_record_model.dart';
import '../../theme/app_theme.dart';

/// 排行榜页面 - 本周榜/总榜/各游戏榜
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _tabs = [
    ('本周榜', 'weekly'),
    ('总榜', 'global'),
    ('五子棋', GameType.gobang),
    ('2048', GameType.game2048),
    ('消消乐', GameType.match3),
    ('飞行棋', GameType.flyingChess),
    ('数独', GameType.sudoku),
    ('翻牌', GameType.memory),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('排行榜 🏆', style: TextStyle(fontSize: 24)),
        backgroundColor: const Color(0xFFFFD166),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: _tabs.map((t) => Tab(text: t.$1)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) {
          final type = tab.$2;
          if (type == 'weekly') {
            return _WeeklyLeaderboardTab(provider: context.read<GameProvider>());
          } else if (type == 'global') {
            return _GlobalLeaderboardTab(provider: context.read<GameProvider>());
          } else {
            return _GameLeaderboardTab(
              gameType: type,
              provider: context.read<GameProvider>(),
            );
          }
        }).toList(),
      ),
    );
  }
}

/// 本周排行榜 - 按积分排序
class _WeeklyLeaderboardTab extends StatelessWidget {
  final GameProvider provider;
  const _WeeklyLeaderboardTab({required this.provider});

  String _avatarEmoji(String avatar) {
    const map = {
      'boy': '👦', 'girl': '👧', 'dad': '👨',
      'mom': '👩', 'grandpa': '👴', 'grandma': '👵',
      'hero': '🦸', 'ninja': '🥷', 'astronaut': '🧑‍🚀',
    };
    return map[avatar] ?? '👦';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Player>>(
      future: provider.getWeeklyLeaderboard(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final players = snap.data ?? [];
        // 过滤掉没有本周积分的玩家
        final activePlayers = players.where((p) => p.weeklyScore > 0).toList();

        if (activePlayers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('📅', style: TextStyle(fontSize: 64)),
                SizedBox(height: 16),
                Text('本周暂无记录，快去游戏吧！',
                    style: TextStyle(fontSize: 22, color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activePlayers.length,
          itemBuilder: (context, index) {
            final player = activePlayers[index];
            final rank = index + 1;

            return _LeaderboardCard(
              rank: rank,
              name: player.name,
              avatar: _avatarEmoji(player.avatar),
              primaryValue: player.weeklyScore,
              primaryLabel: '积分',
              secondaryValue: player.wins,
              secondaryLabel: '胜场',
              subtitle: '本周 ${player.gamesPlayed} 场',
            );
          },
        );
      },
    );
  }
}

/// 总排行榜 - 按积分排序
class _GlobalLeaderboardTab extends StatelessWidget {
  final GameProvider provider;
  const _GlobalLeaderboardTab({required this.provider});

  String _avatarEmoji(String avatar) {
    const map = {
      'boy': '👦', 'girl': '👧', 'dad': '👨',
      'mom': '👩', 'grandpa': '👴', 'grandma': '👵',
      'hero': '🦸', 'ninja': '🥷', 'astronaut': '🧑‍🚀',
    };
    return map[avatar] ?? '👦';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Player>>(
      future: provider.getTotalLeaderboard(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final players = snap.data ?? [];
        if (players.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🎮', style: TextStyle(fontSize: 64)),
                SizedBox(height: 16),
                Text('暂无记录，快去游戏吧！',
                    style: TextStyle(fontSize: 22, color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: players.length,
          itemBuilder: (context, index) {
            final player = players[index];
            final rank = index + 1;

            return _LeaderboardCard(
              rank: rank,
              name: player.name,
              avatar: _avatarEmoji(player.avatar),
              primaryValue: player.totalScore,
              primaryLabel: '积分',
              secondaryValue: player.wins,
              secondaryLabel: '胜场',
              subtitle: '共 ${player.gamesPlayed} 场',
            );
          },
        );
      },
    );
  }
}

/// 单个游戏排行榜 - 显示积分和游戏最佳记录
class _GameLeaderboardTab extends StatelessWidget {
  final String gameType;
  final GameProvider provider;
  const _GameLeaderboardTab({required this.gameType, required this.provider});

  String _avatarEmoji(String avatar) {
    const map = {
      'boy': '👦', 'girl': '👧', 'dad': '👨',
      'mom': '👩', 'grandpa': '👴', 'grandma': '👵',
      'hero': '🦸', 'ninja': '🥷', 'astronaut': '🧑‍🚀',
    };
    return map[avatar] ?? '👦';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: provider.getGameLeaderboard(gameType),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data ?? [];
        // 过滤掉没有游戏记录的玩家
        final activeData = data.where((item) {
          final score = item['score'] as int? ?? 0;
          final totalScore = item['totalScore'] as int? ?? 0;
          return score > 0 || totalScore > 0;
        }).toList();

        if (activeData.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🎮', style: TextStyle(fontSize: 64)),
                SizedBox(height: 16),
                Text('暂无记录，快去游戏吧！',
                    style: TextStyle(fontSize: 22, color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeData.length,
          itemBuilder: (context, index) {
            final item = activeData[index];
            final rank = index + 1;
            final name = item['name'] as String;
            final avatar = item['avatar'] as String;
            final score = item['score'] as int? ?? 0;
            final totalScore = item['totalScore'] as int? ?? 0;
            final isTime = item['isTime'] == true;

            // 格式化最佳记录显示
            String bestLabel;
            String bestValue;
            if (isTime && score > 0) {
              final m = score ~/ 60;
              final s = score % 60;
              bestLabel = '最佳';
              bestValue = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
            } else if (score > 0) {
              bestLabel = '最佳';
              bestValue = '$score';
            } else {
              bestLabel = '';
              bestValue = '-';
            }

            return _LeaderboardCard(
              rank: rank,
              name: name,
              avatar: _avatarEmoji(avatar),
              primaryValue: totalScore,
              primaryLabel: '积分',
              displayValue: totalScore > 0 ? '$totalScore' : '-',
              secondaryValue: score,
              secondaryLabel: bestLabel,
              secondaryDisplayValue: bestValue,
              subtitle: score > 0 ? '$bestLabel: $bestValue' : '暂无记录',
            );
          },
        );
      },
    );
  }
}

/// 排行榜卡片组件
class _LeaderboardCard extends StatelessWidget {
  final int rank;
  final String name;
  final String avatar;
  final int primaryValue;
  final String primaryLabel;
  final String? displayValue; // 自定义显示值（如时间格式）
  final int? secondaryValue;
  final String? secondaryLabel;
  final String? secondaryDisplayValue; // 次数值自定义显示
  final String? subtitle;

  const _LeaderboardCard({
    required this.rank,
    required this.name,
    required this.avatar,
    required this.primaryValue,
    required this.primaryLabel,
    this.displayValue,
    this.secondaryValue,
    this.secondaryLabel,
    this.secondaryDisplayValue,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final rankEmoji =
        rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '$rank';
    final cardColor = rank == 1
        ? const Color(0xFFFFF9C4)
        : rank == 2
            ? const Color(0xFFF5F5F5)
            : rank == 3
                ? const Color(0xFFFFE0B2)
                : Colors.white;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: rank <= 3 ? 6 : 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // 排名
            SizedBox(
              width: 48,
              child: Text(
                rankEmoji,
                style: TextStyle(
                  fontSize: rank <= 3 ? 32 : 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 16),
            // 头像
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              child: Text(avatar, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 16),
            // 名称 & 场次
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),
            // 积分/最佳记录
            Row(
              children: [
                // 主数值（积分）
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      displayValue ?? '$primaryValue',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: rank == 1
                            ? const Color(0xFFFFB300)
                            : AppTheme.primaryColor,
                      ),
                    ),
                    Text(primaryLabel,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                // 次数值（最佳记录）
                if (secondaryLabel != null && secondaryLabel!.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        secondaryDisplayValue ?? '$secondaryValue',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF81C784),
                        ),
                      ),
                      Text(secondaryLabel!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
