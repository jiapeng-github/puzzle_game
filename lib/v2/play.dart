import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:puzzle_rules/puzzle_rules.dart';

import 'controller.dart';
import 'storage.dart';
import 'design.dart';
import 'boards.dart';
import 'records.dart';
import 'flight.dart';

class PlayPage extends StatefulWidget {
  final IslandModel model;
  final Session session;
  final bool resumed;
  const PlayPage({
    super.key,
    required this.model,
    required this.session,
    this.resumed = false,
  });
  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> with WidgetsBindingObserver {
  late final PlayController c = PlayController(
    widget.model,
    widget.session,
    resumed: widget.resumed,
  );
  int selected = -1;
  bool notes = false, leaving = false, restarting = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_changed);
    widget.model.visibleSession = c.session.id;
    if (widget.resumed && !c.state.terminal) {
      // Selecting Continue in the lobby is an explicit request to resume play.
      unawaited(c.resume());
    } else {
      widget.model.sound.game(c.state.config.game);
      if (c.state.terminal) widget.model.sound.finish();
      if (c.paused) widget.model.sound.suspend();
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !c.saved) unawaited(c.pause());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_changed);
    c.dispose();
    if (widget.model.visibleSession == c.session.id) {
      widget.model.visibleSession = null;
    }
    super.dispose();
  }

  Future<void> leave() async {
    if (leaving || c.busy || c.error != null) return;
    if (!c.saved) {
      await c.pause();
      if (c.error != null) return;
    }
    if (!mounted) return;
    widget.model.sound.suspend();
    setState(() => leaving = true);
    // Let PopScope receive canPop before asking the route to close.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> restart() async {
    if (restarting || c.busy) return;
    if (!c.saved) {
      if (!await confirmAction(
        context,
        '放弃这局，重新开始？',
        '本局家庭积分为0，当前进度将被替换。',
        confirm: '放弃并重开',
        cancel: '保留当前局',
      )) {
        return;
      }
    }
    setState(() => restarting = true);
    try {
      if (!c.saved) {
        await c.pause();
        if (c.error != null) return;
        await widget.model.abandon(c.session);
      }
      final old = c.state.config;
      final config = old.game == Game.gobang && c.saved
          ? GameConfig(
              game: old.game,
              mode: old.mode,
              difficulty: old.difficulty,
              humanColor: 3 - old.humanColor,
              players: old.players.reversed.toList(),
            )
          : old;
      final session = await widget.model.create(config);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PlayPage(model: widget.model, session: session),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('暂时无法重开：$e')));
      }
    } finally {
      if (mounted) setState(() => restarting = false);
    }
  }

  Future<void> undo() async {
    final d = c.state.data;
    if (c.state.config.mode == 'local') {
      final history = ints(d['history']);
      if (history.isEmpty) return;
      final owner = (d['board'][history.last] as int) - 1;
      final accepted = await confirmAction(
        context,
        '${nameOf(c.state.config.players[owner])}想悔棋一次',
        '请${nameOf(c.state.config.players[1 - owner])}确认。同意后整局记为辅助对局；拒绝不消耗次数。',
        confirm: '同意悔棋',
        cancel: '不同意',
      );
      if (accepted) {
        await c.command('undo', {'approved': true, 'requester': owner});
      }
    } else {
      await c.command('undo');
    }
  }

  Future<void> _flightHelp() async {
    if (c.state.terminal || c.busy) return;
    await c.pause();
    if (!mounted || c.error != null) return;
    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          FlightRulesDialog(adventure: c.state.config.mode == 'adventure'),
    );
    if (mounted && resume == true && c.error == null) c.resume();
  }

  @override
  Widget build(BuildContext context) {
    final s = c.state, cfg = s.config;
    return PopScope(
      canPop: leaving || c.saved,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !leaving) unawaited(c.pause());
      },
      child: cfg.game == Game.flying
          ? FlightScene(
              controller: c,
              onBack: leave,
              onPause: () => c.pause(),
              onHelp: _flightHelp,
              overlay: s.terminal
                  ? _result()
                  : c.paused
                  ? _pause()
                  : null,
            )
          : IslandPage(
              title: MediaQuery.sizeOf(context).width < 1100
                  ? gameNames[cfg.game.index]
                  : switch (cfg.game) {
                      Game.game2048 => '趣玩2048 · 标准4×4',
                      Game.memory => '记忆翻牌 · ${cfg.pairs}对',
                      Game.match3 => '消消乐 · 50步挑战',
                      Game.sudoku => '数独 · 9×9',
                      _ => gameNames[cfg.game.index],
                    },
              back: leave,
              actions: [
                Tag(
                  s.assisted ? '辅助对局' : '独立对局',
                  color: s.assisted ? lilac : mint,
                ),
                const SizedBox(width: 10),
                FamilyPortrait(cfg.players.first, size: 36),
                const SizedBox(width: 10),
                Text(
                  durationLabel(c.session.durationMs),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                ToyIconButton(
                  color: lilac,
                  tooltip: '暂停',
                  onPressed: s.terminal ? null : c.pause,
                  icon: Icons.pause_rounded,
                ),
              ],
              child: s.terminal
                  ? _result()
                  : c.paused
                  ? _pause()
                  : s.data['milestonePending'] == true
                  ? _milestone()
                  : _arena(),
            ),
    );
  }

  Widget _arena() => LayoutBuilder(
    builder: (context, box) {
      final game = c.state.config.game;
      final compact = box.maxHeight < 440;
      final board = GameBoard(
        controller: c,
        selected: selected,
        select: (i) => setState(() => selected = i),
      );
      Widget panel(Widget child) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: ToyCard(child: child),
      );
      if (game == Game.match3 || game == Game.sudoku || game == Game.game2048) {
        const gap = 20.0;
        final panelWidth = math.min(320.0, box.maxWidth * .36);
        final boardSize = math.min(
          box.maxHeight - 8, // Leave room for the card's bottom shadow.
          box.maxWidth - panelWidth - gap,
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: boardSize, child: board),
            const SizedBox(width: gap),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: game == Game.game2048
                    ? SingleChildScrollView(child: _dashboard2048())
                    : game == Game.sudoku
                    ? _sudokuDashboard()
                    : _matchDashboard(),
              ),
            ),
          ],
        );
      }
      if (game == Game.gobang) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: box.maxWidth * .22,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: _playerCard(0),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: board,
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(
              width: box.maxWidth * .24,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _playerCard(1),
                    const SizedBox(height: 14),
                    _gobangActions(),
                  ],
                ),
              ),
            ),
          ],
        );
      }
      return Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: game == Game.game2048
                      ? 6
                      : game == Game.flying || game == Game.memory
                      ? 8
                      : 7,
                  child: Column(
                    children: [
                      Expanded(child: board),
                      if (!compact &&
                          game != Game.flying &&
                          game != Game.memory)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Tag(switch (game) {
                            Game.sudoku => '任意行、列及3×3宫格内数字不重复',
                            _ => '每翻开第二张牌记一次尝试',
                          }, color: Colors.white),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 28),
                Expanded(
                  flex: game == Game.flying || game == Game.memory ? 4 : 5,
                  child: game == Game.game2048
                      ? SingleChildScrollView(child: _dashboard2048())
                      : game == Game.memory
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _memoryDashboard(),
                        )
                      : panel(_controls()),
                ),
              ],
            ),
          ),
          if (game == Game.flying) ...[
            const SizedBox(height: 12),
            _arenaFooter('安全格保护飞机 · 加速格立即前进3格 · 精确抵达终点'),
          ],
        ],
      );
    },
  );

  Widget _arenaFooter(String text) => Row(
    children: [
      Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ToyButton(
        '重新开始',
        color: const Color(0xFFE5ECFC),
        icon: Icons.restart_alt,
        onPressed: c.busy || restarting ? null : restart,
      ),
      const SizedBox(width: 10),
      ToyButton('暂停并保存', icon: Icons.save_outlined, onPressed: c.pause),
    ],
  );

  Widget _sudokuDashboard() {
    final d = c.state.data;
    final total = (d['puzzle'] as List).where((v) => v == 0).length;
    final editable =
        c.canInput &&
        selected >= 0 &&
        d['puzzle'][selected] == 0 &&
        !(d['hinted'] as List).contains(selected);
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxHeight < 400;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ToyCard(
              padding: EdgeInsets.all(compact ? 8 : 12),
              color: const Color(0xFFEAF6FF),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        ['入门', '进阶', '挑战'][c.state.config.difficulty],
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Text('错误 ${d['errors']} 次'),
                      const Spacer(),
                      Text('完成 ${_sudokuDone()} / $total'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 1 : _sudokuDone() / total,
                      minHeight: 6,
                      color: mint,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ToyCard(
                padding: EdgeInsets.all(compact ? 8 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      editable
                          ? (notes ? '笔记模式 · 标记候选数字' : '选好数字，填入这一格')
                          : '先选一个可填写的格子',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, keysBox) {
                          final columns = compact ? 9 : 3;
                          final rows = compact ? 1 : 3;
                          final height = math.min(
                            compact ? 56.0 : 64.0,
                            (keysBox.maxHeight - (rows - 1) * 6) / rows,
                          );
                          return Align(
                            alignment: Alignment.topCenter,
                            child: GridView.count(
                              key: const ValueKey('sudoku-keypad'),
                              crossAxisCount: columns,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                              childAspectRatio:
                                  ((keysBox.maxWidth - (columns - 1) * 6) /
                                      columns) /
                                  height,
                              children: [
                                for (var n = 1; n <= 9; n++)
                                  ElevatedButton(
                                    onPressed: editable
                                        ? () => c.command(
                                            notes ? 'note' : 'number',
                                            {'index': selected, 'number': n},
                                          )
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.all(4),
                                      backgroundColor: notes
                                          ? const Color(0xFFEDE5FF)
                                          : const Color(0xFFDDF2FF),
                                      disabledBackgroundColor: const Color(
                                        0xFFEEF7FC,
                                      ),
                                      foregroundColor: ink,
                                      disabledForegroundColor: ink.withValues(
                                        alpha: .55,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: const BorderSide(
                                          color: ink,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Center(
                                          child: Text(
                                            '$n',
                                            style: const TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: Text(
                                            '${math.max(0, 9 - (d['board'] as List).where((v) => v == n).length)}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ToyButton(
                            notes ? '笔记中' : '笔记',
                            color: notes ? lilac : const Color(0xFFEDE5FF),
                            onPressed: () => setState(() => notes = !notes),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ToyButton(
                            '擦除',
                            color: Colors.white,
                            onPressed: editable
                                ? () => c.command('erase', {'index': selected})
                                : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ToyButton(
                            '提示 ${3 - (d['hints'] as int)}',
                            color: sun,
                            onPressed: editable && d['hints'] < 3
                                ? () => c.command('hint', {'index': selected})
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!compact)
                  const Expanded(
                    child: Text(
                      '每行、每列、每宫数字不重复',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                TextButton(
                  onPressed: _showSudokuRules,
                  child: const Text('玩法说明'),
                ),
                if (compact) ...[
                  const Spacer(),
                  ToyButton(
                    '重新开始',
                    color: sun,
                    onPressed: c.busy || restarting ? null : restart,
                  ),
                ],
              ],
            ),
            if (!compact)
              ToyButton(
                '重新开始',
                icon: Icons.restart_alt,
                color: sun,
                onPressed: c.busy || restarting ? null : restart,
              ),
          ],
        );
      },
    );
  }

  Future<void> _showSudokuRules() async {
    await c.pause();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('数独 · 玩法说明'),
        content: const SingleChildScrollView(
          child: Text(
            '每行、每列及3×3宫格内，数字1–9不重复。\n\n选择可填写的格子，再点击数字；开启笔记可记录候选数字。\n\n按键角标为该数字剩余数量。错误可修改，提示格会锁定。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('继续游戏'),
          ),
        ],
      ),
    );
    if (mounted && c.error == null) await c.resume();
  }

  Widget _matchDashboard() {
    final d = c.state.data;
    Widget guide(IconData icon, Color color, String title, String detail) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: ink, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(detail, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToyCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: d['left'] <= 10 ? coral : sun,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ink, width: 2),
                    ),
                    child: Text(
                      '${d['left']} 步',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: d['left'] <= 10 ? Colors.white : ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${d['score']} / 2000 分',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: ((d['score'] as int) / 2000).clamp(0, 1),
                  minHeight: 10,
                  color: mint,
                  backgroundColor: const Color(0xFFE2E8F2),
                  semanticsLabel: '目标2000分',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(d['left'] <= 10 ? '步数不多啦，加油！' : '水果大挑战'),
                  Text('本次连锁 ${d['chain']} 连击'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('match-rules-scroll'),
            padding: const EdgeInsets.only(bottom: 8),
            child: ToyCard(
              color: cream,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '玩法与奖励',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  guide(
                    Icons.swap_horiz_rounded,
                    const Color(0xFFDDF2FF),
                    '三连消除',
                    '交换相邻水果，连成三个或更多相同图案。',
                  ),
                  guide(
                    Icons.bolt_rounded,
                    const Color(0xFFFFEDAD),
                    '制造水果炸弹',
                    '四连或交叉匹配生成炸弹。',
                  ),
                  guide(
                    Icons.apps_rounded,
                    const Color(0xFFE8DFFF),
                    '清除周围 3×3',
                    '炸弹参与匹配或被爆炸波及即可触发。',
                  ),
                  const Divider(height: 16),
                  const Text(
                    '家庭奖励',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Wrap(
                    spacing: 6,
                    runSpacing: 8,
                    children: [
                      Tag('通关 +20', color: mint),
                      Tag('剩余≥10步 +5', color: sun),
                      Tag('最高连锁≥3 +5', color: Color(0xFFE8DFFF)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '提示限3次，使用后归入辅助纪录。无可行交换时自动洗牌，不扣步数。',
                    style: TextStyle(fontSize: 12),
                  ),
                  if (d['event'] == 'shuffle') ...[
                    const SizedBox(height: 8),
                    const Text(
                      '棋盘已重新整理，不扣步数',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ToyButton(
                '提示（${3 - (d['hints'] as int)}）',
                icon: Icons.lightbulb_outline,
                color: sun,
                onPressed: c.canInput && d['hints'] < 3
                    ? () => c.command('hint')
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ToyButton(
                '重新开始',
                icon: Icons.restart_alt,
                color: const Color(0xFFEAF0FF),
                onPressed: c.busy || restarting ? null : restart,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _memoryDashboard() {
    final d = c.state.data, cfg = c.state.config;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToyCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  FamilyPortrait(cfg.players.first, size: 36),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nameOf(cfg.players.first),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${d['moves']}次尝试',
                    style: const TextStyle(
                      fontSize: 20,
                      color: coral,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '已配对 ${d['pairsFound']} / ${cfg.pairs} 对',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < cfg.pairs; i++)
                    Expanded(
                      child: Container(
                        height: 12,
                        margin: EdgeInsets.only(
                          right: i == cfg.pairs - 1 ? 0 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: i < d['pairsFound'] ? mint : cream,
                          border: Border.all(color: ink),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ToyCard(
            color: cream,
            padding: const EdgeInsets.all(12),
            child: Scrollbar(
              child: SingleChildScrollView(
                key: const ValueKey('memory-tips-scroll'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '家庭共玩小贴士',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    const Text('翻开两张卡片，找出相同图案。'),
                    const SizedBox(height: 8),
                    const Text('每翻开第二张牌记一次尝试。'),
                    const SizedBox(height: 8),
                    Text('${cfg.pairs + 2}次以内完成，可获额外奖励。'),
                    if (d['remainingMs'] > 0) ...[
                      const SizedBox(height: 8),
                      const Text(
                        '正在观察，稍后继续翻牌…',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF227AC1),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ToyButton(
          '重新开始本局',
          icon: Icons.restart_alt,
          color: sun,
          onPressed: c.busy || restarting ? null : restart,
        ),
      ],
    );
  }

  Widget _playerCard(int seat) {
    final cfg = c.state.config, d = c.state.data;
    final active = d['turn'] == seat + 1;
    final compact = MediaQuery.sizeOf(context).height < 500;
    return ToyCard(
      padding: EdgeInsets.all(compact ? 10 : 14),
      color: active ? const Color(0xFFE5F6EB) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FamilyPortrait(cfg.players[seat], size: compact ? 40 : 60),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  nameOf(cfg.players[seat]),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            seat == 0 ? '● 执黑 · 先手' : '○ 执白 · 后手',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '已落子 ${ints(d['board']).where((v) => v == seat + 1).length} 颗',
            style: const TextStyle(fontSize: 13),
          ),
          if (active) ...[
            const SizedBox(height: 6),
            Text(
              c.thinking ? '● 思考中' : '● 落子中',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF246A50),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gobangActions() {
    final s = c.state, d = s.data, cfg = s.config;
    Widget action(String label, Color color, VoidCallback? tap) => Expanded(
      child: ElevatedButton(
        onPressed: tap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: ink,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: ink, width: 2),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
    return ToyCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              if (cfg.mode == 'ai') ...[
                action(
                  '提示 ${3 - (d['hints'] as int)}',
                  sun,
                  c.canInput && d['hints'] < 3 && d['turn'] == cfg.humanColor
                      ? c.hintGobang
                      : null,
                ),
                const SizedBox(width: 6),
              ],
              action(
                '悔棋',
                const Color(0xFFDDF2FF),
                c.canInput && _canUndo() ? undo : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              action(
                '认输',
                Colors.white,
                c.canInput && s.started
                    ? () async {
                        final color = d['turn'];
                        if (await confirmAction(
                          context,
                          '确认认输？',
                          '本局将记录正常胜负，对手获得获胜奖励。',
                          confirm: '确认认输',
                        )) {
                          await c.command('resign', {'color': color});
                        }
                      }
                    : null,
              ),
              const SizedBox(width: 6),
              action('规则', Colors.white, c.busy ? null : _gobangHelp),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _gobangHelp() async {
    if (c.busy || c.state.terminal) return;
    await c.pause();
    if (!mounted || c.error != null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('五子棋 · 玩法说明'),
        content: SingleChildScrollView(
          child: Text(
            '自由五子棋，连成至少五子获胜，无禁手、无回合限时。\n\n'
            '${c.state.config.mode == 'ai' ? '提示限3次；悔棋退回上一轮人机两手，每局1次。' : '每人可申请悔棋1次，由对方确认。'}'
            '\n\n使用提示或悔棋后，本局记为辅助对局。重新开始请打开顶栏暂停菜单。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('继续游戏'),
          ),
        ],
      ),
    );
    if (mounted && c.error == null) await c.resume();
  }

  Widget _dashboard2048() {
    final d = c.state.data;
    Widget metric(String title, String value, Color color, IconData icon) =>
        ToyCard(
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 38,
                          fontFamily: 'Rubik',
                          fontFamilyFallback: ['Noto Sans SC'],
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(icon, color: color, size: 26),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: metric(
                '本局积分',
                '${d['score']}',
                coral,
                Icons.flag_outlined,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: metric(
                '我的最高成绩',
                '${_best2048()}',
                ink,
                Icons.emoji_events_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: metric('当前最高数字', '${d['highest']}', ink, Icons.numbers),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: metric(
                '已用时间',
                durationLabel(c.session.durationMs),
                ink,
                Icons.timer_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        ToyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.workspace_premium_outlined, color: coral),
                  SizedBox(width: 8),
                  Text(
                    '家庭积分奖励',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text('当前最高数字 ${d['highest']}，正常结束可获得'),
              const SizedBox(height: 10),
              Text(
                '+${_estimate2048(d['highest'])} 积分',
                style: const TextStyle(
                  fontSize: 27,
                  color: coral,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (d['highest'] as int).clamp(0, 2048) / 2048,
                  minHeight: 12,
                  color: mint,
                  backgroundColor: const Color(0xFFECE7DB),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '128 → 10分    512 → 20分    1024 → 35分    2048 → 50分',
                style: TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 14),
              const Tag('达到2048可以继续挑战，整局只结算一次', color: Color(0xFFF0F2FF)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (d['milestone'] == true)
          ToyButton(
            '结束并结算',
            color: mint,
            onPressed: c.canInput ? () => c.command('finish') : null,
          ),
        _arenaFooter(''),
      ],
    );
  }

  Widget _stat(String label, dynamic value, {Color color = sun}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: ToyCard(
      color: color.withValues(alpha: .22),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shadow: false,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$value',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _controls() {
    final s = c.state, d = s.data, config = s.config, game = config.game;
    final can = c.canInput;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (game == Game.memory)
          Row(
            children: [
              FamilyPortrait(config.players.first, size: 48),
              const SizedBox(width: 10),
              Text(
                nameOf(config.players.first),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        const SizedBox(height: 8),
        if (game == Game.game2048) ...[
          _stat('本局成绩', d['score']),
          _stat('最高数字', d['highest'], color: coral),
          _stat('我的最高成绩', _best2048(), color: sky),
          const Text('滑动棋盘或使用方向键合并数字'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in [
                ('left', '←'),
                ('up', '↑'),
                ('down', '↓'),
                ('right', '→'),
              ])
                ToyButton(
                  item.$2,
                  color: Colors.white,
                  onPressed: can
                      ? () => c.command('move', {'direction': item.$1})
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '正常结束预计家庭积分 +${_estimate2048(d['highest'])}\n尚未结算，主动放弃不计积分。',
            style: const TextStyle(fontSize: 12),
          ),
          if (d['milestone'] == true)
            ToyButton(
              '结束并结算',
              color: mint,
              onPressed: can ? () => c.command('finish') : null,
            ),
        ],
        if (game == Game.gobang) ...[
          Text(
            c.thinking
                ? '电脑正在思考…'
                : '轮到${nameOf(config.players[(d['turn'] as int) - 1])}落子',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (config.mode == 'ai')
            ToyButton(
              '提示（剩余${3 - (d['hints'] as int)}）',
              color: sun,
              onPressed: can && d['hints'] < 3 && d['turn'] == config.humanColor
                  ? c.hintGobang
                  : null,
            ),
          const SizedBox(height: 8),
          ToyButton(
            '申请悔棋',
            color: sky,
            onPressed: can && _canUndo() ? undo : null,
          ),
          const SizedBox(height: 8),
          ToyButton(
            '认输',
            color: Colors.white,
            onPressed: can && s.started
                ? () async {
                    final color = d['turn'];
                    if (await confirmAction(
                      context,
                      '确认认输？',
                      '本局将记录正常胜负，对手获得获胜奖励。',
                      confirm: '确认认输',
                    )) {
                      await c.command('resign', {'color': color});
                    }
                  }
                : null,
          ),
          const SizedBox(height: 8),
          Text(config.mode == 'ai' ? '悔棋退回上一轮人机两手，每局1次。' : '每人可申请悔棋1次，由对方确认。'),
          const Text('连成至少五子获胜，无回合限时。'),
        ],
        if (game == Game.match3) ...[
          const Text(
            '目标与对局状态',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          _stat('本局成绩', '${d['score']} / 2000'),
          _stat('剩余步数', d['left'], color: sky),
          _stat('本次连锁', d['chain'], color: coral),
          ToyButton(
            '提示（剩余${3 - (d['hints'] as int)}）',
            color: sun,
            onPressed: can && d['hints'] < 3 ? () => c.command('hint') : null,
          ),
          const SizedBox(height: 10),
          const Text('点选相邻的两个水果交换。炸弹参与同色匹配或被爆炸触及时，清除周围3×3。'),
          if (d['event'] == 'shuffle') const Tag('棋盘已重新整理，不扣步数', color: mint),
        ],
        if (game == Game.memory) ...[
          _stat('已配对', '${d['pairsFound']} / ${config.pairs}'),
          _stat('尝试次数', d['moves'], color: sky),
          if (d['remainingMs'] > 0) const Tag('正在观察，稍后继续翻牌…', color: lilac),
          const SizedBox(height: 10),
          const Text('每翻开第二张牌记一次尝试。\n先比较尝试次数，再比较用时。'),
        ],
        if (game == Game.sudoku) ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Tag(['入门', '进阶', '挑战'][config.difficulty]),
              Tag('错误 ${d['errors']} 次', color: sky),
              Tag(
                '完成 ${_sudokuDone()} / ${(d['puzzle'] as List).where((v) => v == 0).length}',
                color: mint,
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.8,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (var n = 1; n <= 9; n++)
                ToyButton(
                  '$n',
                  color: Colors.white,
                  onPressed: can && selected >= 0
                      ? () => c.command(notes ? 'note' : 'number', {
                          'index': selected,
                          'number': n,
                        })
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ToyButton(
                '笔记',
                color: notes ? sun : lilac,
                onPressed: () => setState(() => notes = !notes),
              ),
              ToyButton(
                '擦除',
                color: Colors.white,
                onPressed: can
                    ? () => c.command('erase', {'index': selected})
                    : null,
              ),
              ToyButton(
                '提示 ${3 - (d['hints'] as int)}',
                color: sky,
                onPressed: can && selected >= 0 && d['hints'] < 3
                    ? () => c.command('hint', {'index': selected})
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('选中空格后填数。错误可修改，提示格会锁定。', style: TextStyle(fontSize: 12)),
        ],
        if (game == Game.flying) ...[
          const Text(
            '本局机长位',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ToyCard(
                radius: 16,
                shadow: false,
                padding: const EdgeInsets.all(8),
                color: d['turn'] == i
                    ? Color.alphaBlend(
                        FlightPainter.colors[i].withValues(alpha: .18),
                        cream,
                      )
                    : Colors.white,
                child: Row(
                  children: [
                    FamilyPortrait(config.players[i], size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${['红队', '黄队', '蓝队', '绿队'][i]} · ${config.players[i] == null ? '电脑${config.players.take(i + 1).where((p) => p == null).length}' : nameOf(config.players[i])}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '到达 ${ints(d['planes'][i]).where((p) => p == 54).length}/4架${d['turn'] == i ? ' · 行动中' : ' · 等待中'}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (d['turn'] == i)
                      Icon(
                        Icons.play_arrow_rounded,
                        color: FlightPainter.colors[i],
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
          _stat(
            '骰子',
            d['dice'] == 0 ? '待掷' : '${d['dice']}点',
            color: FlightPainter.colors[d['turn'] as int],
          ),
          Text(
            c.thinking
                ? '电脑正在行动…'
                : '${nameOf(config.players[d['turn'] as int])}的回合',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ToyButton(
            '掷骰子',
            color: sun,
            onPressed:
                can &&
                    d['dice'] == 0 &&
                    config.players[d['turn'] as int] != null
                ? () => c.command('roll')
                : null,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < 4; i++)
                ToyButton(
                  '${i + 1}号飞机',
                  color: FlightPainter.colors[d['turn'] as int],
                  onPressed:
                      can &&
                          config.players[d['turn'] as int] != null &&
                          legalPlanes(d).contains(i)
                      ? () => c.command('fly', {
                          'seat': d['turn'],
                          'plane': i,
                          'rollId': d['rollId'],
                        })
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '安 = 安全格 · +3 = 立即加速\n6点起飞，精确到达终点。没有飞机在途且连续3次未掷6，下次必出6。',
            style: TextStyle(fontSize: 12),
          ),
        ],
        if (![Game.gobang, Game.game2048, Game.flying].contains(game)) ...[
          const SizedBox(height: 20),
          ToyButton(
            '重新开始',
            icon: Icons.restart_alt,
            color: sun,
            onPressed: c.busy || restarting ? null : restart,
          ),
          const SizedBox(height: 8),
          ToyButton(
            '保存并回大厅',
            icon: Icons.home_outlined,
            color: Colors.white,
            onPressed: c.busy ? null : leave,
          ),
        ],
        if (c.busy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  bool _canUndo() {
    final d = c.state.data, h = ints(d['history']), config = c.state.config;
    if (h.isEmpty) return false;
    if (config.mode == 'ai') {
      return d['turn'] == config.humanColor &&
          h.length >= 2 &&
          d['board'][h[h.length - 2]] == config.humanColor &&
          d['undos'][config.humanColor - 1] == 0;
    }
    return d['undos'][(d['board'][h.last] as int) - 1] == 0;
  }

  int _sudokuDone() => List.generate(
    81,
    (i) =>
        c.state.data['puzzle'][i] == 0 &&
        c.state.data['board'][i] == c.state.data['solution'][i],
  ).where((v) => v).length;
  int _best2048() {
    var best = 0;
    for (final r in widget.model.records) {
      if (r['player'] == c.state.config.players.first &&
          r['config']['game'] == 'game2048' &&
          r['eligible'] == true) {
        best = math.max(best, r['metrics']['score'] as int);
      }
    }
    return best;
  }

  int _estimate2048(int v) => v >= 2048
      ? 50
      : v >= 1024
      ? 35
      : v >= 512
      ? 20
      : v >= 128
      ? 10
      : 0;
  Widget _overlay(
    String title,
    List<Widget> children, {
    List<Widget> footer = const [],
  }) => LayoutBuilder(
    builder: (context, bounds) {
      final compact = bounds.maxHeight < 500;
      return ColoredBox(
        color: c.state.terminal ? const Color(0xFF929DAF) : Colors.transparent,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, compact ? 18 : 24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: c.paused ? 800 : 920),
              child: ToyCard(
                key: const ValueKey('game-overlay-card'),
                color: Colors.white,
                radius: 32,
                borderWidth: 4,
                depth: 10,
                padding: EdgeInsets.all(compact ? 14 : 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        key: const ValueKey('game-overlay-scroll'),
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!c.state.terminal)
                              Icon(
                                c.paused
                                    ? Icons.nightlight_round
                                    : Icons.emoji_events_rounded,
                                size: compact ? 40 : 60,
                                color: ink,
                              ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: compact ? 6 : 10,
                              ),
                              decoration: BoxDecoration(
                                color: c.state.terminal ? coral : sun,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: ink, width: 3),
                              ),
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: c.state.terminal
                                          ? Colors.white
                                          : ink,
                                    ),
                              ),
                            ),
                            SizedBox(height: compact ? 12 : 18),
                            ...children,
                          ],
                        ),
                      ),
                    ),
                    if (footer.isNotEmpty) ...[
                      const Divider(height: 20),
                      ...footer,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  Widget _pause() => _overlay('休息一下', [
    const Text('游戏已完全暂停，盘面已隐藏，准备好后继续挑战吧！'),
    const SizedBox(height: 18),
    Row(
      children: [
        Expanded(
          child: ToyCard(
            shadow: false,
            color: const Color(0xFFF0F2FF),
            child: Row(
              children: [
                FamilyPortrait(c.state.config.players.first, size: 40),
                const SizedBox(width: 8),
                Expanded(child: Text(nameOf(c.state.config.players.first))),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ToyCard(
            shadow: false,
            color: const Color(0xFFF0F2FF),
            child: Column(
              children: [
                const Text('已用时间（冻结中）', style: TextStyle(fontSize: 11)),
                Text(
                  durationLabel(c.session.durationMs),
                  style: const TextStyle(
                    fontFamily: 'Rubik',
                    fontFamilyFallback: ['Noto Sans SC'],
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ToyCard(
            shadow: false,
            color: const Color(0xFFF0F2FF),
            child: Column(
              children: [
                const Text('当前对局', style: TextStyle(fontSize: 11)),
                Text(
                  gameNames[c.state.config.game.index],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 14),
    if (c.error != null) ...[
      Text(c.error!, style: const TextStyle(color: Colors.red)),
      ToyButton('重新保存', onPressed: c.busy ? null : c.retry),
    ] else
      Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: [
          ToyButton('继续游戏', onPressed: c.busy ? null : c.resume),
          ToyButton('保存并回大厅', color: sky, onPressed: c.busy ? null : leave),
          ToyButton(
            '重新开始',
            color: sun,
            onPressed: c.busy || restarting ? null : restart,
          ),
        ],
      ),
    const SizedBox(height: 12),
    const Text('返回大厅会保留进度，重新开始需要确认放弃。'),
  ]);
  Widget _milestone() => _overlay('你合成了2048！', [
    const Icon(Icons.auto_awesome_rounded, size: 60, color: sun),
    const Text('继续挑战不重复领奖。结束本局后家庭积分+50，此时尚未结算。'),
    const SizedBox(height: 16),
    Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ToyButton(
          '继续挑战',
          onPressed: c.busy ? null : () => c.command('dismissMilestone'),
        ),
        ToyButton(
          '结束并结算',
          color: mint,
          onPressed: c.busy ? null : () => c.command('finish'),
        ),
      ],
    ),
  ]);
  bool _newRecord(Json result) {
    final game = c.state.config.game;
    if (!c.saved ||
        result['player'] == null ||
        result['eligible'] != true ||
        [Game.gobang, Game.flying].contains(game)) {
      return false;
    }
    final previous = gameRanking(
      widget.model.records.where((r) => r['id'] != c.session.id).toList(),
      c.state.config,
      assisted: c.state.assisted,
    ).firstWhere((r) => r['player'] == result['player']);
    return previous['missing'] == true ||
        comparePerformance(game, {
              ...result,
              'durationMs': c.session.durationMs,
            }, previous) <
            0;
  }

  List<(String, String)> _resultMetrics() {
    final d = c.state.data;
    return switch (c.state.config.game) {
      Game.game2048 => [
        ('最高数字', '${d['highest']}'),
        ('本局成绩', '${d['score']}'),
        ('已用时间', durationLabel(c.session.durationMs)),
      ],
      Game.memory => [
        ('配对完成', '${d['pairsFound']} / ${c.state.config.pairs}'),
        ('尝试次数', '${d['moves']}次'),
        ('所用时间', durationLabel(c.session.durationMs)),
      ],
      Game.match3 => [
        ('本局成绩', '${d['score']}'),
        ('剩余步数', '${d['left']}步'),
        ('最高连锁', '${d['maxChain']}连击'),
      ],
      Game.sudoku => [
        ('所用时间', durationLabel(c.session.durationMs)),
        ('错误次数', '${d['errors']}次'),
        ('提示次数', '${d['hints']}次'),
      ],
      _ => [],
    };
  }

  Widget _singleResult(Json result) {
    final metrics = _resultMetrics();
    final breakdown = result['breakdown'] as Map;
    Widget stats() => ToyCard(
      radius: 16,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '对局成绩',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: [
              for (var i = 0; i < metrics.length; i++)
                Container(
                  width: 170,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: i == 1
                        ? const Color(0xFFFFEEE8)
                        : const Color(0xFFF0F3FF),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(metrics[i].$1, style: const TextStyle(fontSize: 12)),
                      Text(
                        metrics[i].$2,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontFamilyFallback: ['Noto Sans SC'],
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: i == 1 ? coral : ink,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_newRecord(result))
                const SizedBox(width: 170, child: Tag('新的个人纪录', color: sun)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('按本局成绩记录，独立与辅助对局分别统计。', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
    Widget rewards() => ToyCard(
      radius: 16,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '家庭奖励结算',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 16),
          for (final entry in breakdown.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ToyCard(
                radius: 16,
                shadow: false,
                padding: const EdgeInsets.all(10),
                color: const Color(0xFFFFF5D8),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Color(0xFFBF9923)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${entry.key}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      '+${entry.value} 积分',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          ToyCard(
            radius: 16,
            color: sun,
            shadow: false,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FamilyPortrait(result['player'], size: 42),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('本次合计增加', style: TextStyle(fontSize: 12)),
                ),
                Text(
                  '+${result['reward']}',
                  style: const TextStyle(
                    fontFamily: 'Rubik',
                    fontFamilyFallback: ['Noto Sans SC'],
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth < 650
            ? Column(children: [stats(), const SizedBox(height: 20), rewards()])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: stats()),
                  const SizedBox(width: 24),
                  Expanded(flex: 5, child: rewards()),
                ],
              ),
      ),
    );
  }

  Widget _result() {
    final s = c.state,
        preview = Settlement(
          s,
          c.session.durationMs,
          c.session.endedAt!,
        ).toJson(),
        receipt = c.receipt ?? preview,
        rs = receipt['results'] as List;
    final title = s.outcome == 'draw'
        ? '势均力敌！'
        : s.outcome == 'abandoned'
        ? '本局已放弃'
        : s.outcome == 'lost'
        ? (s.config.game == Game.game2048 ? '本局结束' : '这次差一点！')
        : '挑战完成！';
    return _overlay(
      title,
      [
        Tag(
          c.saved
              ? '已保存 · 已计入家庭积分'
              : c.error != null
              ? '保存失败，积分尚未计入'
              : '正在保存本局结果…',
          color: c.saved
              ? mint
              : c.error != null
              ? coral
              : sun,
        ),
        const SizedBox(height: 14),
        if (rs.length == 1 && _resultMetrics().isNotEmpty)
          _singleResult(Map<String, dynamic>.from(rs.first))
        else ...[
          for (final r in rs)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ToyCard(
                shadow: false,
                color: r['outcome'] == 'won'
                    ? sun.withValues(alpha: .25)
                    : Colors.white,
                child: Row(
                  children: [
                    FamilyPortrait(r['player'], size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${nameOf(r['player'])} · ${{'won': '完成 / 获胜', 'lost': '本局结束', 'draw': '平局', 'abandoned': '已放弃'}[r['outcome']]}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            resultSummary(
                              s.config.game,
                              r,
                              c.session.durationMs,
                            ),
                          ),
                          if (_newRecord(Map<String, dynamic>.from(r)))
                            const Tag('新的个人纪录', color: mint),
                          if ((r['breakdown'] as Map).isNotEmpty)
                            Text(
                              (r['breakdown'] as Map).entries
                                  .map((e) => '${e.key} +${e.value}')
                                  .join(' · '),
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      r['player'] == null ? '电脑不计分' : '+${r['reward']}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (s.assisted) const Text('本局记为辅助对局，独立纪录与辅助纪录分别统计。'),
        if (s.config.game == Game.gobang) const Text('再来一局将交换黑白先手。'),
        if (c.error != null) ...[
          Text(c.error!, style: const TextStyle(fontSize: 12)),
          const Text('重试不会重复加分。'),
        ],
      ],
      footer: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            if (c.error != null)
              ToyButton('重新保存', onPressed: c.busy ? null : c.retry),
            ToyButton(
              restarting ? '正在准备…' : '再来一局',
              onPressed: c.saved && !restarting ? restart : null,
            ),
            ToyButton('返回大厅', color: sky, onPressed: c.saved ? leave : null),
            ToyButton(
              '查看纪录',
              color: Colors.white,
              onPressed: c.saved
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => RecordsPage(model: widget.model),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
