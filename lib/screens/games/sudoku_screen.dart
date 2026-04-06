import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/game_record_model.dart';
import '../../services/audio_service.dart';

// ═══════════════════════════════════════════════════════════════
/// 🎨 现代清新配色方案 - 对齐记忆翻牌风格
// ═══════════════════════════════════════════════════════════════

/// 3个3x3宫格的交替背景色（现代极简风格）
const List<List<Color>> kBoxColors = [
  // 第一行 (r: 0~2)
  [Color(0xFFF5F7FA), Color(0xFFEBF5FB), Color(0xFFF5F7FA)], // 浅灰白, 极淡蓝, 浅灰白
  // 第二行 (r: 3~5)
  [Color(0xFFEBF5FB), Color(0xFFF0FDF4), Color(0xFFEBF5FB)], // 极淡蓝, 极淡绿, 极淡蓝
  // 第三行 (r: 6~8)
  [Color(0xFFF5F7FA), Color(0xFFEBF5FB), Color(0xFFF5F7FA)], // 浅灰白, 极淡蓝, 浅灰白
];

/// 数字键盘统一配色 - 简洁主题风格
const Color kDigitKeyBg = Colors.white;              // 按键默认背景
const Color kDigitKeyFg = Color(0xFF1976D2);         // 按键默认文字（深蓝）
const Color kDigitKeySelectedBg = Color(0xFF4FC3F7);  // 按键选中背景（天蓝）
const Color kDigitKeySelectedFg = Colors.white;        // 按键选中文字

// ─── 页面级颜色 ───
const Color kBgGradientStart = Color(0xFFE3F2FD);   // 淡天蓝（页面渐变起点）
const Color kBgGradientEnd = Color(0xFFE8F5E9);     // 淡绿（页面渐变终点）- 对齐记忆翻牌
const Color kTopBarBg = Colors.white;                // 顶栏背景
const Color kPanelBg = Colors.white;                 // 控制面板背景（纯白+阴影）

// ─── 顶部栏颜色 ───
const Color kBtnBg = Color(0xFF4FC3F7);              // 按钮/设置底色（天蓝）
const Color kTitleColor = Color(0xFF2D3436);         // 标题文字（深灰）
const Color kScoreBadgeBg = Color(0xFFFFD700);       // 积分徽章底（金黄）
const Color kScoreBadgeBorder = Color(0xFFFFB300);   // 积分徽章边框（琥珀）

// ─── 数独盘面交互状态色 ───
const Color kSelectedOverlay = Color(0xB3FFFFFF);    // 选中格白色叠加 (alpha 140)
const Color kSelectedBorder = Color(0xFF4FC3F7);     // 选中格边框（天蓝）
const Color kSameNumHighlight = Color(0x334FC3F7);   // 相同数字蓝色叠加 (alpha 51)
const Color kSameRowColOverlay = Color(0x30FFFFFF);  // 同行同列白色叠加 (alpha 48)
const Color kErrorCellBg = Color(0xFFFFCDD2);        // 错误格背景（浅红）
const Color kErrorText = Color(0xFFD32F2F);          // 错误文字（鲜红）
const Color kFixedTextColor = Color(0xFF37474F);     // 固定数字文字（深灰蓝）
const Color kUserTextColor = Color(0xFF1976D2);      // 用户填写文字（主题蓝）

// ─── 信息区颜色 ───
const Color kTimeColor = Color(0xFF4FC3F7);          // 用时图标+数值（天蓝）
const Color kErrorNormalColor = Color(0xFF4CAF50);   // 错误正常态（翠绿）
const Color kErrorWarnColor = Color(0xFFFF7043);     // 错误警告态（橙红）
const Color kProgressFill = Color(0xFF4CAF50);       // 进度条填充（鲜绿）
const Color kProgressTrack = Color(0xFFEEEEEE);      // 进度条轨道

// ─── 功能按钮颜色 ───
const Color kHintBtnBg = Color(0xFF4FC3F7);          // 提示按钮底（天蓝）
const Color kHintBtnFg = Colors.white;                // 提示按钮图标/文字（白色）
const Color kHintCountBg = Color(0xFFFFB300);         // 提示次数标签（琥珀）
const Color kEraseBtnBg = Color(0xFFFFB6C1);         // 擦除按钮底（珊瑚粉）
const Color kEraseBtnFg = Color(0xFFE91E63);         // 擤除按钮图标/文字（玫红）

// ─── 弹窗颜色 ───
const Color kDialogWinBg = Color(0xFFFFF9E6);        // 胜利弹窗背景（暖米黄）
const Color kDialogLoseBg = Color(0xFFFFF9E6);       // 失败弹窗背景（暖米黄）
const Color kWinTitleColor = Color(0xFFFFB300);      // 胜利标题（金橙）
const Color kLoseTitleColor = Color(0xFFF06292);     // 失败标题（玫红）
const Color kScoreCardBg = Color(0xFFFFF176);        // 积分卡片背景（亮黄）
const Color kScoreCardBorder = Color(0xFFFFCA28);    // 积分卡片边框
const Color kRestartBtnBg = Color(0xFF4FC3F7);       // 再来一局按钮（天蓝）
const Color kHomeBtnBg = Color(0xFFEEEEEE);          // 返回按钮（浅灰）
const Color kHomeBtnFg = Color(0xFF666666);          // 返回按钮文字（中灰）

/// 数独游戏 - 横屏左右分栏布局（盘面70% + 功能区30%）
class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key});

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen>
    with TickerProviderStateMixin {
  // 游戏数据
  late List<List<int>> _solution;
  late List<List<int>> _puzzle;
  late List<List<bool>> _fixed;
  late List<List<bool>> _error;
  int? _selRow, _selCol;
  int _score = 0;
  int _errorCount = 0;
  int _comboCount = 0;
  int _maxCombo = 0;
  bool _gameOver = false;
  bool _isWin = false;
  late DateTime _startTime;
  int _elapsedSeconds = 0;
  late AnimationController _timerController;
  final Random _random = Random();
  int _hintsUsed = 0;
  int _bestTime = 0; // 最快时间记录（秒）

  // 动画控制器
  late AnimationController _hintPulseController;
  late AnimationController _errorFlashController;
  late AnimationController _progressAnimController;
  double _lastProgress = 0;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() {
        if (!_gameOver && mounted) {
          setState(() {
            _elapsedSeconds = DateTime.now().difference(_startTime).inSeconds;
          });
        }
      });
    _timerController.repeat();

    // 提示脉冲动画
    _hintPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 错误闪烁动画
    _errorFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // 进度条平滑动画
    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _newGame();
    _loadBestTime();
  }

  void _loadBestTime() {
    if (!mounted) return;
    final player = context.read<GameProvider>().currentPlayer;
    if (player != null) {
      setState(() {
        _bestTime = player.bestSudoku;
      });
    }
  }

  @override
  void dispose() {
    _timerController.dispose();
    _hintPulseController.dispose();
    _errorFlashController.dispose();
    _progressAnimController.dispose();
    super.dispose();
  }

  void _newGame() {
    _solution = _generateSolution();
    _puzzle = List.generate(9, (r) => List<int>.from(_solution[r]));
    _fixed = List.generate(9, (_) => List.filled(9, false));
    _error = List.generate(9, (_) => List.filled(9, false));
    _generatePuzzle();
    _selRow = null;
    _selCol = null;
    _score = 0;
    _errorCount = 0;
    _comboCount = 0;
    _maxCombo = 0;
    _gameOver = false;
    _isWin = false;
    _startTime = DateTime.now();
    _elapsedSeconds = 0;
    _hintsUsed = 0;
    _lastProgress = 0;
  }

  void _generatePuzzle() {
    // 中等难度：挖空45个
    const holes = 45;
    final positions = [
      for (int r = 0; r < 9; r++)
        for (int c = 0; c < 9; c++) (r, c)
    ]..shuffle(_random);
    for (int i = 0; i < holes; i++) {
      _puzzle[positions[i].$1][positions[i].$2] = 0;
    }
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        _fixed[r][c] = _puzzle[r][c] != 0;
      }
    }
  }

  List<List<int>> _generateSolution() {
    final grid = List.generate(9, (_) => List.filled(9, 0));
    _solveSudoku(grid);
    return grid;
  }

  bool _solveSudoku(List<List<int>> grid) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (grid[r][c] != 0) continue;
        final nums = List.generate(9, (i) => i + 1)..shuffle(_random);
        for (final n in nums) {
          if (_isValid(grid, r, c, n)) {
            grid[r][c] = n;
            if (_solveSudoku(grid)) return true;
            grid[r][c] = 0;
          }
        }
        return false;
      }
    }
    return true;
  }

  bool _isValid(List<List<int>> grid, int row, int col, int num) {
    for (int i = 0; i < 9; i++) {
      if (grid[row][i] == num || grid[i][col] == num) return false;
    }
    final boxR = (row ~/ 3) * 3;
    final boxC = (col ~/ 3) * 3;
    for (int r = boxR; r < boxR + 3; r++) {
      for (int c = boxC; c < boxC + 3; c++) {
        if (grid[r][c] == num) return false;
      }
    }
    return true;
  }

  void _onCellTap(int row, int col) {
    if (_gameOver) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selRow = row;
      _selCol = col;
    });
  }

  void _onNumber(int num) {
    if (_selRow == null || _selCol == null || _gameOver) return;
    final r = _selRow!;
    final c = _selCol!;
    if (_fixed[r][c]) return;

    HapticFeedback.lightImpact();

    // 播放填写音效
    AudioService().playFixedSfx();

    setState(() {
      _puzzle[r][c] = num;
      _error[r][c] = false;

      if (num == _solution[r][c]) {
        // 正确
        _score += 10;
        _comboCount++;
        if (_comboCount > _maxCombo) _maxCombo = _comboCount;
        if (_comboCount == 10) _score += 20;
        if (_comboCount == 20) _score += 50;
        if (_comboCount == 30) _score += 100;
      } else {
        // 错误
        _error[r][c] = true;
        _errorCount++;
        _comboCount = 0;
        _score = max(0, _score - 5);
      }
      _checkComplete();
    });
  }

  void _onErase() {
    if (_selRow == null || _selCol == null || _gameOver) return;
    final r = _selRow!;
    final c = _selCol!;
    if (_fixed[r][c]) return;

    HapticFeedback.lightImpact();
    setState(() {
      _puzzle[r][c] = 0;
      _error[r][c] = false;
    });
  }

  void _onHint() {
    if (_gameOver || _hintsUsed >= 3) return;
    if (_selRow == null || _selCol == null) return;
    final r = _selRow!;
    final c = _selCol!;
    if (_fixed[r][c] || _puzzle[r][c] != 0) return;

    HapticFeedback.mediumImpact();

    // 播放提示动画
    _hintPulseController.forward(from: 0);

    setState(() {
      _hintsUsed++;
      _puzzle[r][c] = _solution[r][c];
      _error[r][c] = false;
      _score += 5;
      _checkComplete();
    });
  }

  void _checkComplete() {
    // 检查是否失败
    if (_errorCount >= 5) {
      setState(() {
        _gameOver = true;
        _isWin = false;
      });
      _saveResult();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showGameOverDialog();
      });
      return;
    }

    // 检查是否胜利
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_puzzle[r][c] != _solution[r][c]) return;
      }
    }
    _gameOver = true;
    _isWin = true;
    _calculateScore();
    _saveResult();
    _showGameOverDialog();
  }

  void _calculateScore() {
    _score += 50; // 完成奖励
    if (_elapsedSeconds <= 600) {
      _score += 50; // 时间奖励
    }
    if (_errorCount == 0) {
      _score += 50;
    } else if (_errorCount <= 2) {
      _score += 30;
    }
    if (_maxCombo >= 10) {
      _score += 10;
    }
    if (_maxCombo >= 20) {
      _score += 30;
    }
  }

  Future<void> _saveResult() async {
    await context.read<GameProvider>().saveGameResult(
          gameType: GameType.sudoku,
          score: _score,
          duration: _elapsedSeconds,
          isWin: _isWin,
        );
  }

  void _showGameOverDialog() {
    // 播放结算音效
    AudioService().playWinningSfx();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GameOverDialog(
        isWin: _isWin,
        score: _score,
        time: _elapsedSeconds,
        errorCount: _errorCount,
        maxCombo: _maxCombo,
        filledCount: _getFilledCount(),
        onRestart: () async {
          Navigator.pop(ctx);
          await context.read<GameProvider>().loadPlayers();
          _loadBestTime();
          AudioService().playBgm(BgmType.sudoku);
          setState(_newGame);
        },
        onHome: () {
          Navigator.pop(ctx);
          Navigator.pop(context);
          AudioService().playHomeBgm();
        },
      ),
    );
  }

  int _getFilledCount() {
    int count = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_puzzle[r][c] != 0) count++;
      }
    }
    return count;
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // 盘面占68%，功能区占32%
    final gridMaxSize = min(screenSize.width * 0.62, screenSize.height - 60);

    return Scaffold(
      backgroundColor: kBgGradientStart,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBgGradientStart, kBgGradientEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      // 左侧数独表格 (68%)
                      SizedBox(
                        width: screenSize.width * 0.68,
                        child: Center(child: _buildGrid(gridMaxSize)),
                      ),
                      const SizedBox(width: 8),
                      // 右侧控制面板 (32%) - 包含数字键盘
                      Expanded(
                        child: _buildControlPanel(),
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

  Widget _buildTopBar() {
    final player = context.watch<GameProvider>().currentPlayer;

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
                '🧩 数独',
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

  Widget _buildGrid(double gridSize) {
    const gridPadding = 10.0;

    return Container(
      width: gridSize,
      height: gridSize,
      padding: const EdgeInsets.all(gridPadding),
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
          BoxShadow(
            color: const Color(0xFF90CAF9).withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: List.generate(9, (r) {
            return Expanded(
              child: Row(
                children: List.generate(9, (c) {
                  return Expanded(child: _buildCell(r, c));
                }),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCell(int r, int c) {
    final val = _puzzle[r][c];
    final isSelected = r == _selRow && c == _selCol;
    final isSameNum = _selRow != null &&
        val != 0 &&
        val == _puzzle[_selRow!][_selCol!];
    final isFixed = _fixed[r][c];
    final isError = _error[r][c];
    final isSameRowCol = _selRow == r || _selCol == c;
    final isSameBox = _selRow != null &&
        (r ~/ 3) == (_selRow! ~/ 3) &&
        (c ~/ 3) == (_selCol! ~/ 3);

    // 🎨 获取该宫格的底色
    final boxColor = kBoxColors[r ~/ 3][c ~/ 3];

    // 背景色 - 在宫格底色基础上叠加交互状态
    Color bgColor = boxColor;
    if (isError) {
      bgColor = kErrorCellBg;
    } else if (isSelected) {
      bgColor = Color.alphaBlend(kSelectedOverlay, boxColor);
    } else if (isSameNum) {
      bgColor = Color.alphaBlend(kSameNumHighlight, boxColor);
    } else if (isSameRowCol || isSameBox) {
      bgColor = Color.alphaBlend(kSameRowColOverlay, boxColor);
    }

    return GestureDetector(
      onTap: () => _onCellTap(r, c),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: kSelectedBorder, width: 2.5)
              : null,
          boxShadow: val != 0 && !isError
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: val != 0
            ? Center(
                child: AnimatedScale(
                  scale: isSelected ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Text(
                    '$val',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: isFixed ? FontWeight.w700 : FontWeight.w600,
                      color: isError
                          ? kErrorText
                          : kFixedTextColor,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kPanelBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 游戏信息区
          _buildGameInfoSection(),
          const SizedBox(height: 8),

          // 功能按钮区
          _buildFunctionButtons(),
          const SizedBox(height: 12),

          // 数字键盘
          Expanded(child: _buildDigitKeyboard()),
        ],
      ),
    );
  }

  Widget _buildGameInfoSection() {
    final progress = _getFilledCount() / 81;

    // 更新进度动画
    if (progress != _lastProgress) {
      _progressAnimController.forward(from: 0);
      _lastProgress = progress;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 用时和错误
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.access_time,
                  label: '用时',
                  value: _formatTime(_elapsedSeconds),
                  color: kTimeColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.close,
                  label: '错误',
                  value: '$_errorCount',
                  color: _errorCount >= 3 ? kErrorWarnColor : kErrorNormalColor,
                  isError: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 最快时间
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events, size: 18, color: Color(0xFFFFB300)),
                const SizedBox(width: 8),
                Text(
                  '最快时间',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
                ),
                const Spacer(),
                Text(
                  _bestTime > 0 ? _formatTime(_bestTime) : '--:--',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFB300),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 完成度进度条
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bar_chart, size: 18, color: const Color(0xFF5C6BC0)),
                      const SizedBox(width: 6),
                      Text(
                        '完成度',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  // 百分比数字
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [kScoreBadgeBg.withValues(alpha: 0.6), kTimeColor.withValues(alpha: 0.2)]),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3949AB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: kProgressTrack,
                      valueColor: const AlwaysStoppedAnimation(kProgressFill),
                      minHeight: 10,
                    ),
                  ),
                  // 进度条上的白色圆形标记
                  if (progress > 0)
                    Positioned(
                      left: (progress * 1000 - 7).clamp(0.0, 1000.0),
                      top: 1.5,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: kProgressFill, width: 1.5),
                          boxShadow: [
                            BoxShadow(color: kProgressFill.withValues(alpha: 0.3), blurRadius: 2)
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isError = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionButtons() {
    return Row(
      children: [
        // 提示按钮 - 天蓝色调
        Expanded(
          child: _buildFuncButton(
            icon: Icons.lightbulb_outline,
            label: '提示',
            count: 3 - _hintsUsed,
            gradientColors: const [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
            onTap: _onHint,
          ),
        ),
        const SizedBox(width: 6),
        // 擦除按钮 - 珊瑚粉色调
        Expanded(
          child: _buildFuncButton(
            icon: Icons.delete_outline,
            label: '擦除',
            gradientColors: const [Color(0xFFFFB6C1), Color(0xFFFF8A9B)],
            onTap: _onErase,
            isErase: true,
          ),
        ),
      ],
    );
  }

  Widget _buildFuncButton({
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    int? count,
    bool isErase = false,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradientColors),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 数字键盘 - 3×3网格布局（统一白底+主题蓝选中态）
  Widget _buildDigitKeyboard() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 7,
        crossAxisSpacing: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(9, (index) {
          final number = index + 1;
          final isSelected = _selRow != null &&
              _selCol != null &&
              _puzzle[_selRow!][_selCol!] == number;

          final bgColor = isSelected ? kDigitKeySelectedBg : kDigitKeyBg;
          final fgColor = isSelected ? kDigitKeySelectedFg : kDigitKeyFg;

          return Material(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            elevation: isSelected ? 3 : 1,
            shadowColor: kDigitKeySelectedBg.withValues(alpha: isSelected ? 0.25 : 0.08),
            child: InkWell(
              onTap: () => _onNumber(number),
              borderRadius: BorderRadius.circular(14),
              splashColor: kDigitKeySelectedBg.withValues(alpha: 0.2),
              highlightColor: kDigitKeySelectedBg.withValues(alpha: 0.1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? kDigitKeySelectedBg : Colors.grey.shade200,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      color: fgColor,
                    ),
                    child: Text('$number'),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 游戏结束弹窗
class _GameOverDialog extends StatelessWidget {
  final bool isWin;
  final int score;
  final int time;
  final int errorCount;
  final int maxCombo;
  final int filledCount;
  final VoidCallback onRestart;
  final VoidCallback onHome;

  const _GameOverDialog({
    required this.isWin,
    required this.score,
    required this.time,
    required this.errorCount,
    required this.maxCombo,
    required this.filledCount,
    required this.onRestart,
    required this.onHome,
  });

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // 统一使用暖米黄背景（对齐记忆翻牌弹窗）
    final titleGradient = isWin
        ? const LinearGradient(colors: [Color(0xFFFFB300), Color(0xFFFF8F00)]) // 金橙渐变（胜利）
        : const LinearGradient(colors: [Color(0xFFF06292), Color(0xFFEC407A)]); // 玫红渐变（失败）

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFFFF9E6),
      child: Container(
        width: 320,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题区域：带渐变文字 + 装饰图标
            ShaderMask(
              shaderCallback: (bounds) => titleGradient.createShader(bounds),
              child: Text(
                isWin ? '🏆 太棒了！' : '💪 再接再厉！',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 统计信息区 - 白色卡片风格（对齐记忆翻牌）
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.access_time_rounded, '用时', _formatTime(time), kTimeColor),
                  _buildInfoRow(Icons.highlight_off_rounded, '错误', '$errorCount 次', errorCount > 3 ? kErrorWarnColor : kErrorNormalColor),
                  if (isWin) _buildInfoRow(Icons.local_fire_department_rounded, '最长连击', '$maxCombo 次', const Color(0xFFFF7043)),
                  _buildInfoRow(Icons.check_circle_rounded, '完成进度', '$filledCount/81', kProgressFill),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 积分区：金黄高亮
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFF176), Color(0xFFFFCA28)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFC107).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    '+$score 积分',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE65100),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('⭐', style: TextStyle(fontSize: 22)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 操作按钮行 - 对齐记忆翻牌风格
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onRestart,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('再来一局', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kRestartBtnBg,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onHome,
                    icon: const Icon(Icons.home_rounded, size: 18),
                    label: const Text('返回首页', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kHomeBtnBg,
                      foregroundColor: kHomeBtnFg,
                      padding: const EdgeInsets.symmetric(vertical: 13),
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

  Widget _buildInfoRow(IconData icon, String label, String value, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
        ],
      ),
    );
  }
}
