import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/game_record_model.dart';
import '../../models/player_model.dart';
import '../../providers/game_provider.dart';
import '../../services/audio_service.dart';

class FlyingChessScreen extends StatefulWidget {
  const FlyingChessScreen({super.key});

  @override
  State<FlyingChessScreen> createState() => _FlyingChessScreenState();
}

class _FlyingChessScreenState extends State<FlyingChessScreen>
    with TickerProviderStateMixin {
  static const int planesPerPlayer = 4;
  static const int trackSize = 52; // 减少跑道格子数量，放大格子
  static const int homeStart = 52;
  static const int goalPos = 58;
  static const double sidePanelMaxWidth = 420;

  // 每边跑道格子数（不含转角）
  static const int cellsPerSide = 12;

  // 跑道布局（从右下角开始顺时针）：
  // 底边：0~12（从右向左），左边：13~25（从下向上）
  // 顶边：26~38（从左向右），右边：39~51（从上向下）
  //
  // 停机坪位置：红队(0)左上角，黄队(1)右上角，蓝队(2)左下角，绿队(3)右下角
  //
  // 出发点：每个玩家从对应颜色跑道的入口格子起飞，沿外圈顺时针飞行
  // 红队(粉色跑道入口) -> 格子32（顶边中间）
  // 黄队(黄色跑道入口) -> 格子45（右边中间）
  // 蓝队(蓝色跑道入口) -> 格子19（左边中间）
  // 绿队(绿色跑道入口) -> 格子6（底边中间）
  // 绕一圈回到自己起点时自动进入终点航线
  static const List<int> startPositions = [32, 45, 19, 6];

  // 终点航线入口：绕一圈后进入终点航线
  // 红队：从顶边中间进入 (格子32附近)
  // 黄队：从右边中间进入 (格子45附近)
  // 蓝队：从左边中间进入 (格子19附近)
  // 绿队：从底边中间进入 (格子6附近)
  static const List<int> homeEntries = [32, 45, 19, 6];

  static const Set<int> safeCells = {32, 45, 19, 6};
  static const Set<int> boostCells = {3, 9, 16, 22, 29, 35, 42, 48};
  static const Set<int> shieldCells = {5, 11, 18, 24, 31, 37, 44, 50};
  static const Map<int, int> portalCells = {7: 20, 20: 33, 33: 46, 46: 7};
  static const Set<int> meteorCells = {2, 14, 27, 41};
  static const Set<int> repairCells = {4, 17, 30, 43};

  static const List<Color> playerColors = [
    Color(0xFFE84B44),
    Color(0xFFF4B942),
    Color(0xFF2C8EF4),
    Color(0xFF39A96B),
  ];
  static const List<String> colorNames = ['红队', '黄队', '蓝队', '绿队'];
  static const List<String> baseNames = [
    '赤焰机库',
    '云端机库',
    '深海跑道',
    '森林航站',
  ];
  static const List<IconData> teamIcons = [
    Icons.local_fire_department_rounded,
    Icons.wb_sunny_rounded,
    Icons.water_drop_rounded,
    Icons.forest_rounded,
  ];

  final List<Player?> _slotPlayers = [null, null, null, null];
  final List<bool> _slotIsAI = [false, true, true, true];

  late List<List<int>> _positions;
  late List<List<bool>> _hasShield;
  late List<List<bool>> _hasBoost;
  late List<List<bool>> _isRepairing;

  bool _gameStarted = false;
  bool _gameOver = false;
  bool _rolling = false;
  int _currentPlayer = 0;
  int _winner = -1;
  int _diceValue = 0;
  int _totalRolls = 0;
  int? _selectedPlane;
  List<int> _movablePlanes = <int>[];
  DateTime? _startTime;
  String _message = '';

  // 保底计数：每个玩家连续未掷出6的次数（仅在无飞机在跑道时计数）
  final List<int> _pityCount = [0, 0, 0, 0];

  late final AnimationController _diceAnim;
  late final AnimationController _pulseAnim;
  late final AnimationController _glowAnim;

  @override
  void initState() {
    super.initState();
    _diceAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _glowAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _diceAnim.dispose();
    _pulseAnim.dispose();
    _glowAnim.dispose();
    super.dispose();
  }

  void _initGame() {
    // 确保槽位0有玩家
    final provider = context.read<GameProvider>();
    if (_slotPlayers[0] == null && provider.currentPlayer != null) {
      _slotPlayers[0] = provider.currentPlayer;
    }
    _positions = List.generate(4, (_) => List.filled(planesPerPlayer, -1));
    _hasShield = List.generate(4, (_) => List.filled(planesPerPlayer, false));
    _hasBoost = List.generate(4, (_) => List.filled(planesPerPlayer, false));
    _isRepairing = List.generate(4, (_) => List.filled(planesPerPlayer, false));
    // 重置保底计数
    for (var i = 0; i < 4; i++) {
      _pityCount[i] = 0;
    }
    setState(() {
      _gameStarted = true;
      _gameOver = false;
      _rolling = false;
      _currentPlayer = 0;
      _winner = -1;
      _diceValue = 0;
      _totalRolls = 0;
      _selectedPlane = null;
      _movablePlanes = <int>[];
      _startTime = DateTime.now();
      _message = '${_playerName(0)} 先手，点击骰子开始。';
    });
    if (_slotIsAI[0]) _scheduleAI();
    AudioService().playBgm(BgmType.flyingChess);
  }

  void _resetGame() {
    // 重新播放游戏背景音乐
    AudioService().playBgm(BgmType.flyingChess);

    setState(() {
      _gameStarted = false;
      _gameOver = false;
      _rolling = false;
      _currentPlayer = 0;
      _winner = -1;
      _diceValue = 0;
      _totalRolls = 0;
      _selectedPlane = null;
      _movablePlanes = <int>[];
      _startTime = null;
      _message = '';
    });
  }

  bool _isPlayerTurn([int? player]) => !_slotIsAI[player ?? _currentPlayer];

  String _playerName(int player) {
    if (_slotIsAI[player]) return '${colorNames[player]} AI';
    return _slotPlayers[player]?.name ?? colorNames[player];
  }

  String _planeLabel(int plane) => '飞机${plane + 1}';

  int _finished(int player) =>
      _positions[player].where((p) => p == goalPos).length;

  int _hangarCount(int player) => _positions[player].where((p) => p < 0).length;

  int _routeCount(int player) =>
      _positions[player].where((p) => p >= 0 && p < goalPos).length;

  Future<void> _rollDice() async {
    if (_rolling || _gameOver || !_isPlayerTurn() || _diceValue > 0) return;
    HapticFeedback.mediumImpact();
    // 播放骰子音效
    AudioService().playDiceSfx();
    setState(() {
      _rolling = true;
      _message = '骰子滚动中，准备规划下一段航线。';
    });
    _diceAnim.reset();
    await _diceAnim.forward();
    if (!mounted || _gameOver) return;
    final value = _generateDiceValue();
    HapticFeedback.selectionClick();
    setState(() {
      _rolling = false;
      _diceValue = value;
      _totalRolls++;
      _message = '${_playerName(_currentPlayer)} 掷出了 $value 点。';
    });
    _afterRoll(value, triggeredByAI: false);
  }

  /// 生成骰子点数，含保底机制
  int _generateDiceValue() {
    final player = _currentPlayer;
    // 检查是否需要保底：无飞机在跑道且保底计数达到5次
    final noPlanesOnTrack = _routeCount(player) == 0;
    if (noPlanesOnTrack && _pityCount[player] >= 5) {
      // 触发保底，重置计数
      _pityCount[player] = 0;
      return 6;
    }
    // 正常掷骰子
    final value = Random().nextInt(6) + 1;
    // 更新保底计数
    if (noPlanesOnTrack) {
      if (value == 6) {
        _pityCount[player] = 0;
      } else {
        _pityCount[player]++;
      }
    }
    return value;
  }

  Future<void> _aiTurn() async {
    if (!mounted ||
        _gameOver ||
        !_slotIsAI[_currentPlayer] ||
        _rolling ||
        _diceValue > 0) {
      return;
    }
    // 播放骰子音效
    AudioService().playDiceSfx();
    setState(() {
      _rolling = true;
      _message = '${_playerName(_currentPlayer)} 正在规划航线…';
    });
    _diceAnim.reset();
    await _diceAnim.forward();
    if (!mounted || _gameOver || !_slotIsAI[_currentPlayer]) return;
    final value = _generateDiceValue();
    setState(() {
      _rolling = false;
      _diceValue = value;
      _totalRolls++;
      _message = '${_playerName(_currentPlayer)} 掷出了 $value 点。';
    });
    _afterRoll(value, triggeredByAI: true);
  }

  void _afterRoll(int value, {required bool triggeredByAI}) {
    if (_gameOver) return;
    final movable = _getMovablePlanes(_currentPlayer, value);
    setState(() => _movablePlanes = movable);
    if (movable.isEmpty) {
      setState(() {
        _message = '${_playerName(_currentPlayer)} 无法移动，本回合结束。';
        _diceValue = 0;
      });
      _scheduleSwitch();
      return;
    }
    if (triggeredByAI) {
      final plane = _chooseBestPlane(movable, value);
      _schedule(
        const Duration(milliseconds: 420),
        () => _movePlane(plane, value),
      );
      return;
    }
    if (movable.length == 1) {
      _schedule(
        const Duration(milliseconds: 180),
        () => _movePlane(movable.first, value),
      );
      return;
    }
    setState(() => _message = '已掷出 $value 点，请点击发光飞机选择行动。');
  }

  List<int> _getMovablePlanes(int player, int dice) {
    final movable = <int>[];
    for (var i = 0; i < planesPerPlayer; i++) {
      final pos = _positions[player][i];
      if (pos >= goalPos) continue;
      if (pos == -1) {
        if (dice == 6) movable.add(i);
      } else if (_calculateNewPos(
            player,
            pos,
            _effectiveSteps(player, i, dice),
          ) !=
          -2) {
        movable.add(i);
      }
    }
    return movable;
  }

  int _effectiveSteps(int player, int plane, int dice) {
    final pos = _positions[player][plane];
    if (pos >= homeStart) return dice; // 终点航线内不触发推进器
    return _hasBoost[player][plane] ? dice + 3 : dice;
  }

  int _chooseBestPlane(List<int> movable, int dice) {
    var bestPlane = movable.first;
    var bestScore = double.negativeInfinity;
    for (final plane in movable) {
      final score =
          _scoreMove(_currentPlayer, plane, dice) + Random().nextDouble() * 4;
      if (score > bestScore) {
        bestScore = score;
        bestPlane = plane;
      }
    }
    return bestPlane;
  }

  double _scoreMove(int player, int plane, int dice) {
    final oldPos = _positions[player][plane];
    if (oldPos == -1) return dice == 6 ? 88 : -999;
    var score = 0.0;
    final steps = _effectiveSteps(player, plane, dice);
    if (_hasBoost[player][plane]) {
      score += 12;
    }
    final newPos = _calculateNewPos(player, oldPos, steps);
    if (newPos == -2) return -999;
    score += steps * 2;
    if (newPos == goalPos) return score + 260;
    if (newPos >= homeStart) return score + 150 + (newPos - homeStart) * 8;
    if (meteorCells.contains(newPos)) score -= 180;
    if (portalCells.containsKey(newPos)) score += 56;
    if (boostCells.contains(newPos)) score += 36;
    if (shieldCells.contains(newPos)) score += 30;
    if (repairCells.contains(newPos)) score += 24;
    if (safeCells.contains(newPos)) score += 18;
    score += _captureValue(player, portalCells[newPos] ?? newPos);
    return score;
  }

  double _captureValue(int player, int pos) {
    if (safeCells.contains(pos)) return 0;
    var score = 0.0;
    for (var p = 0; p < 4; p++) {
      if (p == player) continue;
      for (var i = 0; i < planesPerPlayer; i++) {
        if (_positions[p][i] == pos && _positions[p][i] < homeStart) {
          score += _hasShield[p][i] ? 18 : 64;
        }
      }
    }
    return score;
  }

  void _selectPlane(int plane) {
    if (!_isPlayerTurn() ||
        _diceValue == 0 ||
        !_movablePlanes.contains(plane)) {
      return;
    }
    HapticFeedback.selectionClick();
    _movePlane(plane, _diceValue);
  }

  void _movePlane(int plane, int dice) {
    if (_gameOver) return;

    // 播放飞机移动音效
    AudioService().playPlaneSfx();

    final player = _currentPlayer;
    final oldPos = _positions[player][plane];
    var message = '';
    var moveSteps = dice;
    var usedBoost = false;

    if (oldPos == -1) {
      _positions[player][plane] = startPositions[player];
      _hasShield[player][plane] = false;
      _hasBoost[player][plane] = false;
      _isRepairing[player][plane] = false;
      message =
          '${_playerName(player)} 的 ${_planeLabel(plane)} 从 ${baseNames[player]} 起飞。';
    } else {
      if (_hasBoost[player][plane]) {
        moveSteps += 3;
        usedBoost = true;
        _hasBoost[player][plane] = false;
      }
      _isRepairing[player][plane] = false;
      final newPos = _calculateNewPos(player, oldPos, moveSteps);
      if (newPos == -2) {
        setState(() {
          _diceValue = 0;
          _movablePlanes = <int>[];
          _message = '${_planeLabel(plane)} 无法刚好进入终点，本回合作废。';
        });
        _scheduleSwitch();
        return;
      }
      _positions[player][plane] = newPos;
      if (newPos == goalPos) {
        message = '${_playerName(player)} 的 ${_planeLabel(plane)} 成功抵达终点。';
      } else if (newPos >= homeStart) {
        message = '${_playerName(player)} 的 ${_planeLabel(plane)} 进入终点航线。';
      } else {
        final action = _resolveLanding(player, plane, newPos);
        final prefix = usedBoost ? '触发推进器，额外前进 3 格。' : '';
        message =
            '${_playerName(player)} 的 ${_planeLabel(plane)} $prefix$action';
      }
    }

    setState(() {
      _selectedPlane = plane;
      _movablePlanes = <int>[];
      _message = message;
    });

    _checkWin();
    if (_gameOver) return;

    if (dice == 6) {
      setState(() {
        _diceValue = 0;
        _selectedPlane = null;
        _message = '$message 掷到 6 点，可以继续行动。';
      });
      if (_slotIsAI[player]) _scheduleAI();
      return;
    }

    _scheduleSwitch();
  }

  int _calculateNewPos(int player, int oldPos, int steps) {
    if (oldPos >= homeStart) {
      final target = oldPos + steps;
      return target <= goalPos ? target : -2;
    }
    final entry = homeEntries[player];
    // 当位于入口格（刚从该格出发）时，必须绕满整圈才能再次进入终点航线
    final distance = (oldPos == entry)
        ? trackSize
        : (oldPos < entry)
            ? entry - oldPos
            : (trackSize - oldPos) + entry;
    if (steps > distance) {
      final target = homeStart + steps - distance - 1;
      return target <= goalPos ? target : -2;
    }
    return (oldPos + steps) % trackSize;
  }

  String _resolveLanding(int player, int plane, int pos) {
    final notes = <String>['落在 $pos 号航点'];
    if (boostCells.contains(pos)) {
      _hasBoost[player][plane] = true;
      notes.add('进入加速带，下次移动额外+3');
    } else if (shieldCells.contains(pos)) {
      _hasShield[player][plane] = true;
      notes.add('获得护盾，可抵挡一次撞击');
    } else if (portalCells.containsKey(pos)) {
      final target = portalCells[pos]!;
      _positions[player][plane] = target;
      notes
        ..clear()
        ..add('进入跃迁门，瞬移到 $target 号航点');
      final hit = _resolveCollision(player, target);
      if (hit.isNotEmpty) notes.add(hit);
      return notes.join('，');
    } else if (meteorCells.contains(pos)) {
      _positions[player][plane] = -1;
      _hasShield[player][plane] = false;
      _hasBoost[player][plane] = false;
      _isRepairing[player][plane] = false;
      return '遭遇陨石风暴，被迫返航到机库。';
    } else if (repairCells.contains(pos)) {
      _isRepairing[player][plane] = true;
      final reward = Random().nextInt(3);
      if (reward == 0) {
        _hasShield[player][plane] = true;
        notes.add('进入维修站，补给了一层护盾');
      } else if (reward == 1) {
        _hasBoost[player][plane] = true;
        notes.add('进入维修站，补满推进器');
      } else {
        _hasShield[player][plane] = true;
        _hasBoost[player][plane] = true;
        notes.add('进入维修站，获得护盾和推进器');
      }
    } else {
      notes.add('航线平稳');
    }
    final hit = _resolveCollision(player, _positions[player][plane]);
    if (hit.isNotEmpty) notes.add(hit);
    return notes.join('，');
  }

  String _resolveCollision(int player, int pos) {
    if (safeCells.contains(pos)) return '';
    final notes = <String>[];
    for (var p = 0; p < 4; p++) {
      if (p == player) continue;
      for (var i = 0; i < planesPerPlayer; i++) {
        if (_positions[p][i] != pos || _positions[p][i] >= homeStart) continue;
        if (_hasShield[p][i]) {
          _hasShield[p][i] = false;
          notes.add('${_playerName(p)} 的护盾被击碎');
        } else {
          _positions[p][i] = -1;
          _hasShield[p][i] = false;
          _hasBoost[p][i] = false;
          _isRepairing[p][i] = false;
          notes.add('击落了 ${_playerName(p)} 的 ${_planeLabel(i)}');
        }
      }
    }
    if (notes.isNotEmpty) HapticFeedback.mediumImpact();
    return notes.join('，');
  }

  void _checkWin() {
    if (_gameOver) return;
    for (var player = 0; player < 4; player++) {
      if (_finished(player) < planesPerPlayer) continue;
      setState(() {
        _gameOver = true;
        _winner = player;
        _rolling = false;
        _diceValue = 0;
        _selectedPlane = null;
        _movablePlanes = <int>[];
        _message = '${_playerName(player)} 抵达终点，赢下本局。';
      });
      unawaited(_saveResult());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showEndDialog();
      });
      return;
    }
  }

  void _switchPlayer() {
    if (!mounted || _gameOver) return;
    final nextPlayer = (_currentPlayer + 1) % 4;
    setState(() {
      _currentPlayer = nextPlayer;
      _rolling = false;
      _diceValue = 0;
      _selectedPlane = null;
      _movablePlanes = <int>[];
      _message = _slotIsAI[nextPlayer]
          ? '${_playerName(nextPlayer)} 准备接管航线…'
          : '${_playerName(nextPlayer)} 的回合，点击骰子开始。';
    });
    if (_slotIsAI[nextPlayer]) _scheduleAI();
  }

  void _scheduleSwitch() {
    _schedule(const Duration(milliseconds: 700), _switchPlayer);
  }

  void _scheduleAI() {
    _schedule(const Duration(milliseconds: 760), () => _aiTurn());
  }

  void _schedule(Duration delay, VoidCallback action) {
    Future<void>.delayed(delay, () {
      if (!mounted || _gameOver) return;
      action();
    });
  }

  Future<void> _saveResult() async {
    if (_winner < 0 || _slotIsAI[_winner]) return;
    final player = _slotPlayers[_winner];
    if (player == null) return;
    final duration = _startTime == null
        ? 0
        : DateTime.now().difference(_startTime!).inSeconds;
    await context.read<GameProvider>().saveGameResultForPlayer(
      playerAvatar: player.avatar,
      gameType: GameType.flyingChess,
      score: 50,
      duration: duration,
      isWin: true,
    );
  }

  void _showEndDialog() {
    // 播放结算音效
    AudioService().playWinningSfx();

    final color = playerColors[_winner];
    final isHumanWinner = !_slotIsAI[_winner];
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF9FBFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.72)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.airplanemode_active_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isHumanWinner ? '顺利抵达终点' : '本局已结束',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              _playerName(_winner),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              baseNames[_winner],
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  _dialogStat('总投掷次数', '$_totalRolls'),
                  const SizedBox(height: 10),
                  _dialogStat(
                    '完成飞机',
                    '${_finished(_winner)}/$planesPerPlayer',
                  ),
                  if (isHumanWinner) ...[
                    const SizedBox(height: 10),
                    _dialogStat(
                      '奖励积分',
                      '+50',
                      color: const Color(0xFFF59E0B),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _resetGame();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('再来一局'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).maybePop();
                    AudioService().playHomeBgm();
                  },
                  style: FilledButton.styleFrom(backgroundColor: color),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('返回'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dialogStat(String label, String value, {Color? color}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color ?? const Color(0xFF132238),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF4FF), Color(0xFFF7FBFF)],
          ),
        ),
        child: SafeArea(
          child: _gameStarted ? _buildGameUI() : _buildPlayerSelect(),
        ),
      ),
    );
  }

  Widget _buildGameUI() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 960;
        final sideWidth = min(
          sidePanelMaxWidth,
          max(360.0, constraints.maxWidth * 0.42),
        ).toDouble();
        return Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: isWide
                    ? Row(
                        children: [
                          Expanded(
                            flex: 55,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _buildBoardSection(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 45,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: sideWidth,
                                ),
                                child: _buildSidePanel(),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(flex: 62, child: _buildBoardSection()),
                          const SizedBox(height: 10),
                          Expanded(flex: 38, child: _buildSidePanel()),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _topAction(
            Icons.arrow_back_rounded,
            '返回',
            () {
              AudioService().playHomeBgm();
              Navigator.of(context).maybePop();
            },
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1C7BF2).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.airplanemode_active_rounded,
                  color: Color(0xFF1C7BF2),
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  '飞行棋',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C7BF2),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _topAction(Icons.refresh_rounded, '重新开局', _resetGame),
          const SizedBox(width: 4),
          _topAction(Icons.help_outline_rounded, '规则', _showRulesDialog),
        ],
      ),
    );
  }

  Widget _topAction(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: const Color(0xFF1C7BF2)),
          ),
        ),
      ),
    );
  }

  void _showRulesDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.rule_folder_rounded, color: Color(0xFF1C7BF2)),
            SizedBox(width: 10),
            Text('飞行棋规则'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '基础规则',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              SizedBox(height: 10),
              _RuleItem('掷到 6 点才能从机库起飞。'),
              _RuleItem('掷到 6 点可继续行动一次。'),
              _RuleItem('外圈 52 格，进入终点航线后需刚好抵达终点。'),
              _RuleItem('在非安全格撞上对手，会把对方打回机库。'),
              SizedBox(height: 18),
              Text(
                '特殊航点',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              SizedBox(height: 10),
              _RuleItem('加速带：下次移动额外 +3 格。'),
              _RuleItem('护盾格：抵挡一次碰撞。'),
              _RuleItem('跃迁门：瞬移到另一处传送门。'),
              _RuleItem('陨石格：立即返航。'),
              _RuleItem('维修站：获得随机补给。'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerSelect() {
    final allPlayers = context.watch<GameProvider>().allPlayers;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 26,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.airplanemode_active_rounded,
                      color: Color(0xFF1C7BF2),
                      size: 26,
                    ),
                    SizedBox(width: 10),
                    Text(
                      '飞行棋玩家',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF11243C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '可自由切换玩家对战',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: List.generate(
                    4,
                    (index) => SizedBox(
                      width: 230,
                      child: _buildPlayerCard(index, allPlayers),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _LobbyPill(
                      icon: Icons.flight_takeoff_rounded,
                      label: '52 格主航线',
                    ),
                    _LobbyPill(
                      icon: Icons.auto_awesome_rounded,
                      label: '特殊航点效果'
                    ),
                    _LobbyPill(
                      icon: Icons.devices_rounded,
                      label: '平板自适应',
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _initGame,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1C7BF2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 18,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('开始飞行'),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        AudioService().playHomeBgm();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1C7BF2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        side: const BorderSide(color: Color(0xFF1C7BF2), width: 1.5),
                      ),
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('返回'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard(int index, List<Player> allPlayers) {
    final player = _slotPlayers[index];
    final color = playerColors[index];
    final isAI = _slotIsAI[index];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showSlotDialog(index, allPlayers),
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.16),
                color.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1.6),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Center(
                        child: Text(
                          isAI ? 'AI' : (player?.emoji ?? '🙂'),
                          style: TextStyle(
                            fontSize: isAI ? 18 : 26,
                            fontWeight: isAI
                                ? FontWeight.w900
                                : FontWeight.w500,
                            color: isAI ? color : null,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(teamIcons[index], color: color),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  colorNames[index],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isAI ? '自动驾驶' : (player?.name ?? '点击选择角色'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF11243C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAI ? baseNames[index] : '总积分 ${player?.totalScore ?? 0}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _showSlotDialog(index, allPlayers),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('切换'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSlotDialog(int slotIndex, List<Player> allPlayers) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('选择 ${colorNames[slotIndex]}'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: playerColors[slotIndex].withValues(
                      alpha: 0.16,
                    ),
                    child: Text(
                      'AI',
                      style: TextStyle(
                        color: playerColors[slotIndex],
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  title: const Text('自动驾驶'),
                  subtitle: Text(baseNames[slotIndex]),
                  trailing: _slotIsAI[slotIndex]
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                        )
                      : null,
                  onTap: () {
                    setState(() {
                      _slotIsAI[slotIndex] = true;
                      _slotPlayers[slotIndex] = null;
                    });
                    Navigator.of(ctx).pop();
                  },
                ),
                const Divider(height: 24),
                if (allPlayers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '还没有可选角色，当前只能使用 AI。',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ...allPlayers.map((player) {
                  final isSelected =
                      !_slotIsAI[slotIndex] &&
                      _slotPlayers[slotIndex]?.avatar == player.avatar;
                  final isUsed = _slotPlayers.asMap().entries.any(
                    (entry) =>
                        entry.key != slotIndex &&
                        !_slotIsAI[entry.key] &&
                        entry.value?.avatar == player.avatar,
                  );
                  return ListTile(
                    enabled: !isUsed,
                    leading: CircleAvatar(
                      backgroundColor: playerColors[slotIndex].withValues(
                        alpha: 0.16,
                      ),
                      child: Text(player.emoji),
                    ),
                    title: Text(player.name),
                    subtitle: Text(
                      '总积分 ${player.totalScore} 路 胜场 ${player.wins}',
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                          )
                        : isUsed
                        ? const Icon(Icons.block_rounded, color: Colors.grey)
                        : null,
                    onTap: isUsed
                        ? null
                        : () {
                            setState(() {
                              _slotIsAI[slotIndex] = false;
                              _slotPlayers[slotIndex] = player;
                            });
                            Navigator.of(ctx).pop();
                          },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoardSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 4, 6, 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF7FBFF)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boardSize = min(
                  constraints.maxWidth,
                  constraints.maxHeight,
                ).toDouble();
                final geometry = _BoardGeometry(boardSize);
                // 棋盘居中显示
                return Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: boardSize,
                    height: boardSize,
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: Size.square(boardSize),
                          painter: _BoardPainter(
                            geometry: geometry,
                            activePlayer: _currentPlayer,
                          ),
                        ),
                        ..._buildPlaneWidgets(geometry),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPlaneWidgets(_BoardGeometry geometry) {
    final entries = <_PlaneEntry>[];
    final groups = <String, List<_PlaneEntry>>{};
    for (var player = 0; player < 4; player++) {
      for (var plane = 0; plane < planesPerPlayer; plane++) {
        final pos = _positions[player][plane];
        late final Offset center;
        late final String key;
        if (pos == -1) {
          center = geometry.hangarCenter(player, plane);
          key = 'hangar-$player-$plane';
        } else if (pos >= goalPos) {
          center = geometry.goalCenter;
          key = 'goal';
        } else if (pos >= homeStart) {
          center = geometry.homeCenter(player, pos - homeStart);
          key = 'home-$player-$pos';
        } else {
          center = geometry.trackCenter(pos);
          key = 'track-$pos';
        }
        final entry = _PlaneEntry(
          player: player,
          plane: plane,
          center: center,
          key: key,
        );
        entries.add(entry);
        groups.putIfAbsent(key, () => <_PlaneEntry>[]).add(entry);
      }
    }

    return entries.map((entry) {
      final group = groups[entry.key]!;
      final index = group.indexOf(entry);
      final offset = _stackOffset(
        index,
        group.length,
        geometry.tokenSize * 0.34,
      );
      final color = playerColors[entry.player];
      final movable =
          entry.player == _currentPlayer &&
          _movablePlanes.contains(entry.plane);
      final selected =
          entry.player == _currentPlayer && _selectedPlane == entry.plane;
      final size = geometry.tokenSize;
      final hitSize = size * 1.18;
      return Positioned(
        left: entry.center.dx + offset.dx - hitSize / 2,
        top: entry.center.dy + offset.dy - hitSize / 2,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _selectPlane(entry.plane),
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              final scale = movable ? 1 + _pulseAnim.value * 0.08 : 1.0;
              return Transform.scale(scale: scale, child: child);
            },
            child: SizedBox(
              width: hitSize,
              height: hitSize,
              child: Center(
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.72)],
                    ),
                    border: Border.all(
                      color: selected
                          ? Colors.white
                          : color.withValues(alpha: 0.16),
                      width: selected ? 3 : 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(
                          alpha: movable
                              ? 0.42 + _pulseAnim.value * 0.12
                              : 0.18,
                        ),
                        blurRadius: movable ? 22 : 10,
                        spreadRadius: movable ? 2 : 0,
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: const Icon(
                          Icons.flight_takeoff_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      if (_hasShield[entry.player][entry.plane])
                        const Positioned(
                          right: -3,
                          top: -5,
                          child: _TokenBadge(
                            icon: Icons.shield_rounded,
                            color: Color(0xFF2C8EF4),
                          ),
                        ),
                      if (_hasBoost[entry.player][entry.plane])
                        const Positioned(
                          left: -3,
                          top: -5,
                          child: _TokenBadge(
                            icon: Icons.bolt_rounded,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      if (_isRepairing[entry.player][entry.plane])
                        const Positioned(
                          left: -4,
                          bottom: -6,
                          child: _TokenBadge(
                            icon: Icons.build_circle_rounded,
                            color: Color(0xFF8B5E3C),
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
    }).toList();
  }

  Offset _stackOffset(int index, int count, double distance) {
    if (count <= 1) {
      return Offset.zero;
    }
    if (count == 2) {
      return index == 0 ? Offset(-distance / 2, 0) : Offset(distance / 2, 0);
    }
    if (count == 3) {
      const offsets = [
        Offset(-0.55, 0.32),
        Offset(0.55, 0.32),
        Offset(0, -0.58),
      ];
      return offsets[index] * distance;
    }
    const offsets = [
      Offset(-0.55, -0.55),
      Offset(0.55, -0.55),
      Offset(-0.55, 0.55),
      Offset(0.55, 0.55),
    ];
    return offsets[index < 4 ? index : 3] * distance;
  }

  Widget _buildSidePanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 500 || constraints.maxWidth < 280;
        final gap = compact ? 4.0 : 6.0;
        final outerPadding = compact ? 6.0 : 8.0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(outerPadding),
            child: Column(
              children: [
                // 回合信息 - 固定高度
                SizedBox(
                  height: compact ? 72 : 82,
                  child: _buildTurnCard(compact: compact),
                ),
                SizedBox(height: gap),
                // 队伍状态 - 可扩展
                Expanded(
                  flex: 3,
                  child: _buildSquadCard(compact: compact),
                ),
                SizedBox(height: gap),
                // 骰子区域 - 固定高度
                SizedBox(
                  height: compact ? 100 : 115,
                  child: _buildDiceCard(compact: compact),
                ),
                SizedBox(height: gap),
                // 提示信息 - 固定高度
                SizedBox(
                  height: compact ? 58 : 68,
                  child: _buildFeedbackCard(compact: compact),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTurnCard({required bool compact}) {
    final color = playerColors[_currentPlayer];
    final avatarSize = compact ? 48.0 : 54.0;
    final statusText = _gameOver
        ? '本局已结束'
        : (_isPlayerTurn() ? '轮到你操作' : 'AI 自动操作中');

    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (context, child) => Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.8)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2 + _glowAnim.value * 0.1),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _slotIsAI[_currentPlayer]
                      ? 'AI'
                      : (_slotPlayers[_currentPlayer]?.emoji ?? '🙂'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _slotIsAI[_currentPlayer]
                        ? (compact ? 14 : 16)
                        : (compact ? 18 : 22),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '终点 ${_finished(_currentPlayer)}/4 · 在途 ${_routeCount(_currentPlayer)} · 机库 ${_hangarCount(_currentPlayer)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiceCard({required bool compact}) {
    final canRoll =
        _isPlayerTurn() && !_rolling && _diceValue == 0 && !_gameOver;
    final diceSize = compact ? 64.0 : 72.0;

    String tipText;
    if (_gameOver) {
      tipText = '本局已结束';
    } else if (_rolling) {
      tipText = '骰子滚动中…';
    } else if (_diceValue == 0) {
      tipText = canRoll ? '点击骰子' : '等待回合';
    } else if (_movablePlanes.length > 1) {
      tipText = '选择飞机';
    } else {
      tipText = '等待结算';
    }

    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8F0F8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '行动',
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C7BF2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tipText,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '已掷 $_totalRolls 次',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: canRoll ? _rollDice : null,
            child: AnimatedBuilder(
              animation: _diceAnim,
              builder: (context, child) => Transform.rotate(
                angle: _rolling ? _diceAnim.value * pi * 4 : 0,
                child: child,
              ),
              child: Container(
                width: diceSize,
                height: diceSize,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: canRoll
                        ? const [Color(0xFFFFB347), Color(0xFFFF8C3B)]
                        : const [Color(0xFFE5EAF2), Color(0xFFD2D9E4)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (canRoll
                                  ? const Color(0xFFFFA726)
                                  : const Color(0xFFB8C2D0))
                              .withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _rolling
                      ? const Icon(
                          Icons.casino_rounded,
                          size: 28,
                          color: Colors.white,
                        )
                      : Text(
                          _diceValue == 0 ? 'GO' : '$_diceValue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 26 : 30,
                            fontWeight: FontWeight.w900,
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

  Widget _buildFeedbackCard({required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8F0F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates_rounded,
                size: compact ? 12 : 14,
                color: const Color(0xFF1C7BF2),
              ),
              const SizedBox(width: 6),
              Text(
                '提示',
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C7BF2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              _message.isEmpty ? '等待本局开始。' : _message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquadCard({required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8F0F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '队伍状态',
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C7BF2),
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: compact ? 4 : 6,
              crossAxisSpacing: compact ? 4 : 6,
              childAspectRatio: 2.2,
              children: List.generate(4, (i) => _buildTeamMiniTile(i, compact: compact)),
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          // 特殊航点图例
          _buildLegendSection(compact: compact),
        ],
      ),
    );
  }

  Widget _buildLegendSection({required bool compact}) {
    final legends = [
      (Icons.bolt_rounded, '加速', '下次移动额外+3格', const Color(0xFFE67E00)),
      (Icons.shield_rounded, '护盾', '抵挡一次撞击返航', const Color(0xFF1A6BC5)),
      (Icons.sync_alt_rounded, '传送', '瞬移到配对传送门', const Color(0xFFA855F7)),
      (Icons.blur_circular_rounded, '陨石', '立即返回机库重置', const Color(0xFF5C6370)),
      (Icons.build_rounded, '维修', '随机获得护盾或加速', const Color(0xFF6D4C2A)),
    ];

    final iconSize = compact ? 14.0 : 16.0;
    final nameSize = compact ? 10.0 : 11.0;
    final descSize = compact ? 8.0 : 9.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: legends.map((item) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 2.0 : 3.0),
          child: Row(
            children: [
              Icon(item.$1, size: iconSize, color: item.$4),
              SizedBox(width: compact ? 4 : 6),
              Text(
                item.$2,
                style: TextStyle(
                  fontSize: nameSize,
                  fontWeight: FontWeight.w800,
                  color: item.$4,
                ),
              ),
              SizedBox(width: compact ? 4 : 6),
              Expanded(
                child: Text(
                  item.$3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: descSize,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTeamMiniTile(int player, {required bool compact}) {
    final color = playerColors[player];
    final isCurrent = !_gameOver && player == _currentPlayer;
    final isWinner = _gameOver && player == _winner;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isCurrent || isWinner ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isWinner
              ? const Color(0xFFF59E0B)
              : color.withValues(alpha: isCurrent ? 0.4 : 0.15),
          width: isCurrent || isWinner ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 20 : 24,
            height: compact ? 20 : 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _slotIsAI[player] ? 'AI' : (_slotPlayers[player]?.emoji ?? '🙂'),
                style: TextStyle(
                  fontSize: _slotIsAI[player] ? (compact ? 8 : 10) : (compact ? 11 : 13),
                  fontWeight: FontWeight.w800,
                  color: _slotIsAI[player] ? color : null,
                ),
              ),
            ),
          ),
          SizedBox(width: compact ? 6 : 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  colorNames[player],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 11 : 12,
                    color: color,
                  ),
                ),
                Text(
                  '${_finished(player)}/${_routeCount(player)}/${_hangarCount(player)}',
                  style: TextStyle(
                    fontSize: compact ? 9 : 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isWinner)
            Icon(Icons.emoji_events_rounded, size: compact ? 14 : 16, color: const Color(0xFFF59E0B))
          else if (isCurrent)
            Container(
              width: compact ? 6 : 8,
              height: compact ? 6 : 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _BoardGeometry {
  _BoardGeometry(this.size)
    : center = Offset(size / 2, size / 2),
      cellSize = size * 0.052,
      tokenSize = size * 0.042,
      goalRadius = size * 0.055,
      // 停机坪放在内侧四角（调整位置）
      // 红队(0)：左上角，黄队(1)：右上角，蓝队(2)：左下角，绿队(3)：右下角
      _hangarRects = [
        Rect.fromLTWH(size * 0.22, size * 0.16, size * 0.18, size * 0.18),
        Rect.fromLTWH(size * 0.62, size * 0.16, size * 0.18, size * 0.18),
        Rect.fromLTWH(size * 0.22, size * 0.66, size * 0.18, size * 0.18),
        Rect.fromLTWH(size * 0.62, size * 0.66, size * 0.18, size * 0.18),
      ],
      // 终点航线方向向量（从外圈入口指向棋盘中心）
      _homeVectors = [
        Offset(0, size * 0.068),   // 红队向下（从顶边入口）
        Offset(-size * 0.068, 0),  // 黄队向左（从右边入口）
        Offset(size * 0.068, 0),   // 蓝队向右（从左边入口）
        Offset(0, -size * 0.068),  // 绿队向上（从底边入口）
      ] {
    // 预计算所有跑道格子的位置和角度
    _trackPositions = _computeTrackPositions();
    // 终点航线入口位置：动态取对应外圈格子的实际坐标，确保与跑道无缝衔接
    final entries = _FlyingChessScreenState.homeEntries;
    _homeStarts = [
      _trackPositions[entries[0]].center, // 红队：32号格（顶边）
      _trackPositions[entries[1]].center, // 黄队：45号格（右边）
      _trackPositions[entries[2]].center, // 蓝队：19号格（左边）
      _trackPositions[entries[3]].center, // 绿队：6号格（底边）
    ];
  }

  final double size;
  final Offset center;
  final double cellSize;
  final double tokenSize;
  final double goalRadius;
  final List<Rect> _hangarRects;
  late final List<Offset> _homeStarts;
  final List<Offset> _homeVectors;

  late final List<_TrackCell> _trackPositions;

  Offset get goalCenter => center;

  Rect hangarRect(int player) => _hangarRects[player];

  _TrackCell trackCell(int pos) => _trackPositions[pos % _FlyingChessScreenState.trackSize];

  Offset trackCenter(int pos) => trackCell(pos).center;

  double trackAngle(int pos) => trackCell(pos).angle;

  /// 计算跑道格子位置
  /// 跑道沿外圈排列，从右下角开始顺时针
  /// 每边12格 + 4个转角格 = 52格
  List<_TrackCell> _computeTrackPositions() {
    const cellsPerSide = _FlyingChessScreenState.cellsPerSide;

    final cells = <_TrackCell>[];
    // 使用更小的边距确保格子不会溢出
    final trackMargin = size * 0.04;
    final trackLength = size - trackMargin * 2;
    final step = trackLength / cellsPerSide;

    // 底边（从右下角向左）：0 ~ 11（12格），飞机向左
    for (var i = 0; i < cellsPerSide; i++) {
      final x = size - trackMargin - (i * step);
      final y = size - trackMargin;
      cells.add(_TrackCell(Offset(x, y), pi)); // 向左
    }
    // 转角格12：左下角，飞机开始向上
    cells.add(_TrackCell(Offset(trackMargin, size - trackMargin), -pi / 2));

    // 左边（从左下角向上）：13 ~ 24（12格），飞机向上
    for (var i = 0; i < cellsPerSide; i++) {
      final x = trackMargin;
      final y = size - trackMargin - (i * step);
      cells.add(_TrackCell(Offset(x, y), -pi / 2)); // 向上
    }
    // 转角格25：左上角，飞机开始向右
    cells.add(_TrackCell(Offset(trackMargin, trackMargin), 0));

    // 顶边（从左上角向右）：26 ~ 37（12格），飞机向右
    for (var i = 0; i < cellsPerSide; i++) {
      final x = trackMargin + (i * step);
      final y = trackMargin;
      cells.add(_TrackCell(Offset(x, y), 0)); // 向右
    }
    // 转角格38：右上角，飞机开始向下
    cells.add(_TrackCell(Offset(size - trackMargin, trackMargin), pi / 2));

    // 右边（从右上角向下）：39 ~ 50（12格），飞机向下
    for (var i = 0; i < cellsPerSide; i++) {
      final x = size - trackMargin;
      final y = trackMargin + (i * step);
      cells.add(_TrackCell(Offset(x, y), pi / 2)); // 向下
    }
    // 转角格51：右下角，飞机开始向左（回到起点）
    cells.add(_TrackCell(Offset(size - trackMargin, size - trackMargin), pi));

    return cells;
  }

  Offset homeCenter(int player, int step) {
    return _homeStarts[player] + (_homeVectors[player] * step.toDouble());
  }

  Offset hangarCenter(int player, int plane) {
    final rect = _hangarRects[player];
    final points = [
      Offset(rect.left + rect.width * 0.3, rect.top + rect.height * 0.3),
      Offset(rect.left + rect.width * 0.7, rect.top + rect.height * 0.3),
      Offset(rect.left + rect.width * 0.3, rect.top + rect.height * 0.7),
      Offset(rect.left + rect.width * 0.7, rect.top + rect.height * 0.7),
    ];
    return points[plane];
  }
}

/// 跑道格子的位置和角度
class _TrackCell {
  const _TrackCell(this.center, this.angle);

  final Offset center;
  final double angle;
}

class _PlaneEntry {
  const _PlaneEntry({
    required this.player,
    required this.plane,
    required this.center,
    required this.key,
  });

  final int player;
  final int plane;
  final Offset center;
  final String key;
}

class _BoardPainter extends CustomPainter {
  const _BoardPainter({required this.geometry, required this.activePlayer});

  final _BoardGeometry geometry;
  final int activePlayer;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackdrop(canvas, size);
    _paintTrackCells(canvas);
    _paintHangars(canvas);
    _paintHomeLanes(canvas);
    _paintGoal(canvas);
  }

  void _paintBackdrop(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFDFEFF), Color(0xFFF2F7FF)],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(size.width * 0.015),
        Radius.circular(size.width * 0.06),
      ),
      background,
    );

    final haloPaint = Paint()
      ..color = _FlyingChessScreenState.playerColors[activePlayer].withValues(
        alpha: 0.08,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;
    canvas.drawCircle(geometry.center, size.width * 0.18, haloPaint);
  }

  void _paintHangars(Canvas canvas) {
    for (var player = 0; player < 4; player++) {
      final color = _FlyingChessScreenState.playerColors[player];
      final rect = geometry.hangarRect(player);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.08),
          ],
        ).createShader(rect);
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(rect.width * 0.18),
      );
      canvas.drawRRect(rrect, paint);

      // 边框
      final borderPaint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(rrect, borderPaint);

      // 飞机图标
      final iconPainter = TextPainter(
        text: const TextSpan(
          text: '✈',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(
        canvas,
        Offset(
          rect.center.dx - iconPainter.width / 2,
          rect.center.dy - iconPainter.height / 2,
        ),
      );
    }
  }

  void _paintTrackCells(Canvas canvas) {
    final cellSize = geometry.cellSize * 0.88;
    final corner = cellSize * 0.15;

    for (var pos = 0; pos < _FlyingChessScreenState.trackSize; pos++) {
      final cell = geometry.trackCell(pos);
      final center = cell.center;
      final angle = cell.angle;
      final cellColor = _cellColor(pos);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      // 阴影
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.04)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-cellSize / 2 + 1, -cellSize / 2 + 1, cellSize, cellSize),
          Radius.circular(corner),
        ),
        shadowPaint,
      );

      // 格子填充
      final rect = Rect.fromCenter(center: Offset.zero, width: cellSize, height: cellSize);
      final fillPaint = Paint()..color = cellColor;
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(corner));
      canvas.drawRRect(rrect, fillPaint);

      // 边框
      final isStartPos = _FlyingChessScreenState.startPositions.contains(pos);
      final borderPaint = Paint()
        ..color = isStartPos
            ? _FlyingChessScreenState.playerColors[
                _FlyingChessScreenState.startPositions.indexOf(pos)]
            : const Color(0xFFD5E1F2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isStartPos ? 1.8 : 0.8;
      canvas.drawRRect(rrect, borderPaint);

      // 特殊格子标记
      _paintCellIcon(canvas, pos, cellSize);

      canvas.restore();
    }
  }

  void _paintCellIcon(Canvas canvas, int pos, double cellSize) {
    final iconSize = cellSize * 0.32;

    IconData? icon;
    Color? iconColor;

    if (_FlyingChessScreenState.portalCells.containsKey(pos)) {
      icon = Icons.sync_alt_rounded;
      iconColor = const Color(0xFFA855F7);
    } else if (_FlyingChessScreenState.meteorCells.contains(pos)) {
      icon = Icons.blur_circular_rounded;
      iconColor = const Color(0xFF5C6370);
    } else if (_FlyingChessScreenState.boostCells.contains(pos)) {
      icon = Icons.bolt_rounded;
      iconColor = const Color(0xFFE67E00);
    } else if (_FlyingChessScreenState.shieldCells.contains(pos)) {
      icon = Icons.shield_rounded;
      iconColor = const Color(0xFF1A6BC5);
    } else if (_FlyingChessScreenState.repairCells.contains(pos)) {
      icon = Icons.build_rounded;
      iconColor = const Color(0xFF6D4C2A);
    }

    if (icon != null && iconColor != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: iconSize,
            fontFamily: icon.fontFamily,
            color: iconColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
    }
  }

  Color _cellColor(int pos) {
    if (_FlyingChessScreenState.safeCells.contains(pos)) {
      final player = _FlyingChessScreenState.startPositions.indexOf(pos);
      return _FlyingChessScreenState.playerColors[player].withValues(alpha: 0.28);
    }
    if (_FlyingChessScreenState.boostCells.contains(pos)) {
      return const Color(0xFFFFE2B3);
    }
    if (_FlyingChessScreenState.shieldCells.contains(pos)) {
      return const Color(0xFFD9ECFF);
    }
    if (_FlyingChessScreenState.portalCells.containsKey(pos)) {
      return const Color(0xFFF0DEFF);
    }
    if (_FlyingChessScreenState.meteorCells.contains(pos)) {
      return const Color(0xFFE5E8EE);
    }
    if (_FlyingChessScreenState.repairCells.contains(pos)) {
      return const Color(0xFFE9DFC9);
    }
    return pos.isEven ? Colors.white : const Color(0xFFF8FBFF);
  }

  void _paintHomeLanes(Canvas canvas) {
    final cellSize = geometry.cellSize * 0.75;
    final corner = cellSize * 0.15;

    for (var player = 0; player < 4; player++) {
      final color = _FlyingChessScreenState.playerColors[player];
      final fill = Paint()..color = color.withValues(alpha: 0.25);
      final border = Paint()
        ..color = color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      for (var step = 0; step < 6; step++) {
        final center = geometry.homeCenter(player, step);
        final rect = Rect.fromCenter(center: center, width: cellSize, height: cellSize);
        final rrect = RRect.fromRectAndRadius(rect, Radius.circular(corner));
        canvas.drawRRect(rrect, fill);
        canvas.drawRRect(rrect, border);
      }
    }
  }

  void _paintGoal(Canvas canvas) {
    final glow = Paint()
      ..color = const Color(0xFFFFC84A).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(geometry.goalCenter, geometry.goalRadius * 1.15, glow);

    final fill = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFF6DC), Color(0xFFFFD864)],
      ).createShader(
        Rect.fromCircle(center: geometry.goalCenter, radius: geometry.goalRadius),
      );
    final border = Paint()
      ..color = const Color(0xFFF2B330)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(geometry.goalCenter, geometry.goalRadius, fill);
    canvas.drawCircle(geometry.goalCenter, geometry.goalRadius, border);

    final flagPainter = TextPainter(
      text: TextSpan(
        text: '⚑',
        style: TextStyle(
          fontSize: geometry.goalRadius * 0.95,
          color: const Color(0xFF6D4A00),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    flagPainter.paint(
      canvas,
      Offset(
        geometry.goalCenter.dx - flagPainter.width / 2,
        geometry.goalCenter.dy - flagPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) {
    return oldDelegate.activePlayer != activePlayer ||
        oldDelegate.geometry.size != geometry.size;
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: Color(0xFF39A96B),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _LobbyPill extends StatelessWidget {
  const _LobbyPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1C7BF2)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF23415F),
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenBadge extends StatelessWidget {
  const _TokenBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, size: 10, color: color),
    );
  }
}
