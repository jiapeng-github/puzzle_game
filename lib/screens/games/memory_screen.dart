import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/game_record_model.dart';
import '../../models/player_model.dart';
import '../../services/audio_service.dart';

/// 记忆翻牌游戏 - 横屏布局优化版
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen>
    with TickerProviderStateMixin {
  // 4种图标主题
  static const List<List<String>> _themes = [
    ['🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯', '🦁', '🐮', '🐷', '🐸', '🐵', '🐔'],
    ['🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🫐', '🍈', '🍒', '🍑', '🥭', '🍍', '🥝', '🍅'],
    ['🚗', '🚕', '🚙', '🚌', '🚎', '🏎️', '🚓', '🚑', '🚒', '🚐', '🛻', '🚚', '🚛', '🚜', '🏍️', '🛵'],
    ['⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉', '🥏', '🎱', '🪀', '🏓', '🏸', '🏒', '🏑', '🥍'],
  ];

  // 游戏状态变量
  List<String> _cards = [];
  List<bool> _flipped = [];
  List<bool> _matched = [];
  int? _firstIndex;
  bool _checking = false;
  int _moves = 0;
  int _pairsFound = 0;
  bool _gameOver = false;
  bool _gameInitialized = false;
  int _elapsedSeconds = 0;
  Timer? _gameTimer;
  int _bestTime = 0; // 最佳时间（秒）

  // 主题
  final int _themeIndex = 0;
  static const int _totalPairs = 8;

  @override
  void initState() {
    super.initState();
    // 延迟初始化游戏
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadBestTime();
        _initGame();
        AudioService().playBgm(BgmType.memory);
      }
    });
  }

  void _initGame() {
    _stopTimers();

    // 根据主题选择图标
    final theme = _themes[_themeIndex];
    final selectedEmojis = (theme.toList()..shuffle()).take(_totalPairs).toList();
    _cards = [...selectedEmojis, ...selectedEmojis]..shuffle(Random());

    _flipped = List.filled(_cards.length, false);
    _matched = List.filled(_cards.length, false);
    _firstIndex = null;
    _checking = false;
    _moves = 0;
    _pairsFound = 0;
    _gameOver = false;
    _gameInitialized = true;
    _elapsedSeconds = 0;

    _startTimer();
  }

  void _loadBestTime() {
    if (!mounted) return;
    final player = context.read<GameProvider>().currentPlayer;
    if (player != null) {
      setState(() {
        _bestTime = player.bestMemory;
      });
    }
  }

  void _startTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _gameOver) {
        timer.cancel();
        return;
      }
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _stopTimers() {
    _gameTimer?.cancel();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  void _onTap(int index) {
    if (_checking || _flipped[index] || _matched[index] || _gameOver) return;

    HapticFeedback.lightImpact();

    setState(() {
      _flipped[index] = true;
    });

    if (_firstIndex == null) {
      // 第一次翻牌 - 播放翻牌音效
      AudioService().playSfx('audio/sfx/turn.mp3');
      _firstIndex = index;
    } else {
      final first = _firstIndex!;
      _firstIndex = null;
      _moves++;
      _checking = true;

      if (_cards[first] == _cards[index]) {
        // 配对成功 - 播放成功音效
        AudioService().playSfx('audio/sfx/right.mp3');
        setState(() {
          _matched[first] = true;
          _matched[index] = true;
          _pairsFound++;
          _checking = false;
        });

        if (_pairsFound >= _totalPairs) {
          _onLevelComplete();
        }
      } else {
        // 配对失败 - 播放翻牌音效
        AudioService().playSfx('audio/sfx/turn.mp3');
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          setState(() {
            _flipped[first] = false;
            _flipped[index] = false;
            _checking = false;
          });
        });
      }
    }
  }

  void _onLevelComplete() async {
    _gameOver = true;

    // 保存结果（通关奖励+10积分，用时作为分数记录）
    await context.read<GameProvider>().saveGameResult(
          gameType: GameType.memory,
          score: 10, // 固定+10积分
          duration: _elapsedSeconds,
          isWin: true,
        );

    // 更新最佳时间
    if (_bestTime == 0 || _elapsedSeconds < _bestTime) {
      setState(() {
        _bestTime = _elapsedSeconds;
      });
    }

    if (mounted) {
      _showLevelCompleteDialog();
    }
  }

  void _showLevelCompleteDialog() {
    // 播放结算音效
    AudioService().playWinningSfx();

    final isNewRecord = _bestTime == _elapsedSeconds;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFFFF9E6),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            const Text(
              '通关成功!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildResultRow('⏱️ 用时', _formatTime(_elapsedSeconds)),
                  _buildResultRow('👣 步数', '$_moves 步'),
                  if (_bestTime > 0)
                    _buildResultRow('🏆 最佳', _formatTime(_bestTime)),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🎁 奖励: ', style: TextStyle(fontSize: 18)),
                      const Text(
                        '+10 积分',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFF6B6B)),
                      ),
                      if (isNewRecord) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('新纪录', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await context.read<GameProvider>().loadPlayers();
                      _loadBestTime();
                      AudioService().playBgm(BgmType.memory);
                      if (mounted) {
                        setState(_initGame);
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('再玩一次'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4FC3F7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                      AudioService().playHomeBgm();
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('返回'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: const Color(0xFF666666),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF666666))),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<GameProvider>().currentPlayer;
    final screenSize = MediaQuery.of(context).size;
    final gridMaxSize = min(screenSize.width * 0.55, screenSize.height - 100);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE3F2FD), Color(0xFFE8F5E9)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(player),
              Expanded(
                child: _gameInitialized
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 左侧游戏网格
                            SizedBox(
                              width: gridMaxSize,
                              child: _buildGameGrid(gridMaxSize),
                            ),
                            const SizedBox(width: 16),
                            // 右侧信息面板
                            Expanded(
                              child: _buildInfoPanel(gridMaxSize),
                            ),
                          ],
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4FC3F7),
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
            color: const Color(0xFF4FC3F7).withValues(alpha: 0.2),
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
                '🃏 记忆翻牌',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
            ),
          ),

          // 角色信息
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

  Widget _buildGameGrid(double gridSize) {
    final cardSize = (gridSize - 60) / 4;

    return Container(
      width: gridSize,
      height: gridSize,
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (row) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (col) {
              final index = row * 4 + col;
              return _buildCard(index, cardSize);
            }),
          );
        }),
      ),
    );
  }

  Widget _buildCard(int index, double size) {
    final isFlipped = _flipped[index];
    final isMatched = _matched[index];
    final showFront = isFlipped || isMatched;

    return GestureDetector(
      onTap: () => _onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: showFront
              ? null
              : const LinearGradient(
                  colors: [Color(0xFFFFB6C1), Color(0xFF87CEEB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: showFront ? Colors.white : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isMatched
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.15),
              blurRadius: isMatched ? 12 : 6,
              spreadRadius: isMatched ? 2 : 0,
              offset: const Offset(0, 3),
            ),
          ],
          border: isMatched
              ? Border.all(color: const Color(0xFF4CAF50), width: 2)
              : null,
        ),
        child: Center(
          child: showFront
              ? Text(
                  _cards[index],
                  style: TextStyle(fontSize: size * 0.5),
                )
              : const Text(
                  '?',
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel(double gridMaxSize) {
    return SizedBox(
      height: gridMaxSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 区域1：双列卡片 - 当前时间/当前步数
          Row(
            children: [
              Expanded(
                child: _LargeInfoCard(
                  icon: '⏱️',
                  title: '当前时间',
                  value: _formatTime(_elapsedSeconds),
                  color: const Color(0xFF4FC3F7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LargeInfoCard(
                  icon: '👣',
                  title: '当前步数',
                  value: '$_moves',
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 区域2：最快时间卡片
          _buildBestTimeCard(),
          const SizedBox(height: 12),

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

          // 区域4：底部重新开始按钮
          _buildRestartButton(),
        ],
      ),
    );
  }

  Widget _buildBestTimeCard() {
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('🏆', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '最快时间',
                  style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                ),
                const SizedBox(height: 2),
                Text(
                  _bestTime > 0 ? _formatTime(_bestTime) : '--:--',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesCard() {
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
              Text('📋', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                '游戏规则',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3D2914)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildRuleItem('点击卡片翻开'),
          _buildRuleItem('找到相同配对'),
          _buildRuleItem('完成全部获胜'),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Color(0xFF4CAF50)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
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
          _buildBonusItem('通关奖励', '+10', color: const Color(0xFFFFD700)),
          const SizedBox(height: 48), // 占位保持高度一致
        ],
      ),
    );
  }

  Widget _buildBonusItem(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color ?? const Color(0xFF4CAF50))),
        ],
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

/// 大号信息卡片组件
class _LargeInfoCard extends StatelessWidget {
  final String icon;
  final String title;
  final String value;
  final Color color;

  const _LargeInfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
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
            color: Colors.black.withValues(alpha: 0.05),
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
