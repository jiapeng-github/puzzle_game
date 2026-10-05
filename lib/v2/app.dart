import 'package:flutter/material.dart';
import 'package:puzzle_rules/puzzle_rules.dart';

import 'controller.dart';
import 'storage.dart';
import 'design.dart';
import 'illustrations.dart';
import 'stitch_art.dart';
import 'boards.dart' show CardBackDots;
import 'play.dart';
import 'records.dart';

class PuzzleApp extends StatefulWidget {
  final GameStore? store;
  final bool audioEnabled;
  const PuzzleApp({super.key, this.store, this.audioEnabled = true});
  @override
  State<PuzzleApp> createState() => _PuzzleAppState();
}

class _PuzzleAppState extends State<PuzzleApp> with WidgetsBindingObserver {
  late final IslandModel model = IslandModel(
    store: widget.store,
    audioEnabled: widget.audioEnabled,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    model.load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    model.sound.background(state != AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '趣玩小岛',
    debugShowCheckedModeBanner: false,
    theme: islandTheme(),
    home: ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        if (model.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (model.error != null) {
          return Scaffold(
            body: Center(
              child: ToyCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(model.error!),
                    const SizedBox(height: 16),
                    ToyButton('重新打开', onPressed: model.load),
                  ],
                ),
              ),
            ),
          );
        }
        return HomePage(model: model);
      },
    ),
  );
}

class HomePage extends StatefulWidget {
  final IslandModel model;
  const HomePage({super.key, required this.model});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool opening = false;
  IslandModel get m => widget.model;
  @override
  void initState() {
    super.initState();
    m.sound.home();
  }

  Future<void> launch(Game game, {bool resume = false}) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      var old = m.saves[game];
      Session? session;
      if (resume && old != null) {
        session = old;
      } else {
        if (old != null) {
          if (old.state.terminal) {
            session = old;
          } else {
            if (!await confirmAction(
              context,
              '放弃这局，重新开始？',
              '当前进度将被替换，本局家庭积分为0。想稍后继续，请选择继续对局。',
              confirm: '放弃并重开',
              cancel: '保留旧局',
            )) {
              return;
            }
            await m.abandon(old);
          }
        }
        if (session == null) {
          if (!mounted) return;
          final config = [Game.game2048, Game.match3].contains(game)
              ? GameConfig(game: game, players: [m.role])
              : await showDialog<GameConfig>(
                  context: context,
                  builder: (_) => SetupDialog(game: game, role: m.role),
                );
          if (config == null) return;
          session = await m.create(config);
        }
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              PlayPage(model: m, session: session!, resumed: resume),
        ),
      );
      if (!mounted) return;
      m.sound.home();
      await m.refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('暂时无法开始：$e')));
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => IslandPage(
    title: '趣玩小岛',
    leading: Row(
      children: [
        ToyCard(
          color: const Color(0xFFFFE08F),
          radius: 16,
          borderWidth: 4,
          depth: 4,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  'assets/images/stitch/logo.png',
                  width: 36,
                  height: 36,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '趣玩小岛',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    ),
    actions: [
      ToyCard(
        shadow: false,
        color: const Color(0xFFEAF0FF),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_outlined, color: ink),
            const SizedBox(width: 8),
            Text(
              '家庭总积分 ${m.total.fold<int>(0, (n, r) => n + (r['points'] as int))}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      const SizedBox(width: 18),
      TextButton(
        onPressed: opening ? null : () => chooseRole(context, m),
        child: Row(
          children: [
            FamilyPortrait(m.role, size: 42),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nameOf(m.role),
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text('切换角色', style: TextStyle(fontSize: 11, color: ink)),
              ],
            ),
          ],
        ),
      ),
      ToyIconButton(
        color: sun,
        tooltip: '家庭排行榜',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => RecordsPage(model: m)),
        ),
        icon: Icons.leaderboard_outlined,
      ),
      ToyIconButton(
        tooltip: '音效开关',
        color: const Color(0xFFDEE8FF),
        icon: m.preferences['sound'] == false
            ? Icons.volume_off_outlined
            : Icons.volume_up_outlined,
        onPressed: () => m.setting('sound', m.preferences['sound'] == false),
      ),
      ToyIconButton(
        tooltip: '设置',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => SettingsDialog(model: m),
        ),
        icon: Icons.settings_outlined,
      ),
    ],
    child: Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final short = box.maxHeight < 450;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(3, 3, 3, 8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisExtent: short ? 220 : (box.maxHeight - 30) / 2,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 20,
                ),
                itemCount: 6,
                itemBuilder: (context, i) {
                  final game = [
                        Game.game2048,
                        Game.gobang,
                        Game.match3,
                        Game.flying,
                        Game.sudoku,
                        Game.memory,
                      ][i],
                      save = m.saves[game];
                  final g = game.index;
                  const labels = [
                    '双人 / 人机对战',
                    '经典4×4',
                    '50步·2000分',
                    '1–4人欢乐同玩',
                    '三档难度',
                    '主题配对',
                  ];
                  const colors = [mint, coral, sky, sun, lilac, mint];
                  const buttons = [
                    '开始对弈',
                    '开始挑战',
                    '进入挑战',
                    '起飞对战',
                    '开启解题',
                    '翻牌挑战',
                  ];
                  return ToyCard(
                    color: Colors.white,
                    radius: 24,
                    borderWidth: 4,
                    depth: 8,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                gameNames[g],
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Tag(
                              labels[g],
                              color: colors[g].withValues(alpha: .28),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (save != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '有存档 · ${nameOf(save.state.config.players.first)} · ${durationLabel(save.durationMs)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Container(
                          height: short ? 76 : 96,
                          decoration: BoxDecoration(
                            color: colors[g].withValues(alpha: .17),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ink, width: 2),
                          ),
                          child: save != null && game == Game.game2048
                              ? _Resume2048(save: save)
                              : Center(
                                  child: SizedBox(
                                    width: g == 2 || g == 3 || g == 0
                                        ? 280
                                        : 180,
                                    height: 95,
                                    child: GameThumbnail(g),
                                  ),
                                ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: ToyButton(
                                save == null
                                    ? buttons[g]
                                    : save.state.terminal
                                    ? '保存结果'
                                    : '继续对局',
                                icon: gameIcons[g],
                                color: colors[g],
                                onPressed: opening
                                    ? null
                                    : () => launch(game, resume: save != null),
                              ),
                            ),
                            if (save != null && !save.state.terminal) ...[
                              const SizedBox(width: 8),
                              ToyButton(
                                '新开一局',
                                color: Colors.white,
                                onPressed: opening ? null : () => launch(game),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (opening) const LinearProgressIndicator(minHeight: 3),
      ],
    ),
  );
}

Future<void> chooseRole(BuildContext context, IslandModel model) async {
  var current = model.role;
  final selected = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        title: const Center(
          child: Text('今天谁来玩？', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        content: SizedBox(
          width: 1000,
          child: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (ctx, box) => Wrap(
                spacing: 16,
                runSpacing: 18,
                children: [
                  for (final role in roles)
                    SizedBox(
                      width: (box.maxWidth - 32) / 3,
                      child: InkWell(
                        onTap: () => setDialog(() => current = role),
                        child: ToyCard(
                          color: current == role
                              ? const Color(0xFFFFF4CE)
                              : Colors.white,
                          child: Row(
                            children: [
                              FamilyPortrait(role, size: 64),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nameOf(role),
                                      style: const TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      current == role
                                          ? '已选中 · 一起出发吧'
                                          : '动动脑筋，快乐挑战',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 6),
                                    Tag(
                                      '家庭小玩家',
                                      color: const Color(0xFFEAF0FF),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          Row(
            children: [
              ToyButton(
                '返回大厅',
                color: Colors.white,
                onPressed: () => Navigator.pop(ctx),
              ),
              const Spacer(),
              ToyButton(
                '就选我啦（${nameOf(current)}）',
                icon: Icons.check_circle_outline,
                onPressed: () => Navigator.pop(ctx, current),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  if (selected != null) await model.setting('role', selected);
}

class _Resume2048 extends StatelessWidget {
  final Session save;
  const _Resume2048({required this.save});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Row(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFBBADA0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ink, width: 2),
            ),
            child: GridView.count(
              crossAxisCount: 4,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: [
                for (final n in ints(save.state.data['board']))
                  Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: n == 0
                          ? const Color(0xFFD4C8B6)
                          : n >= 128
                          ? sun
                          : cream,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FittedBox(
                      child: Text(
                        n == 0 ? '' : '$n',
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'Rubik',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '2048 棋盘',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '本局 ${save.state.data['score']}分 · 最大方块 ${save.state.data['highest']}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class GameThumbnail extends StatelessWidget {
  final int game;
  const GameThumbnail(this.game, {super.key});
  @override
  Widget build(BuildContext context) {
    if (game == 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final label in ['黑子', '执子博弈', '白子'])
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: label == '黑子' ? ink : Colors.white,
                border: Border.all(color: ink, width: 2),
                borderRadius: BorderRadius.circular(99),
                boxShadow: const [BoxShadow(color: ink, offset: Offset(0, 3))],
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: label == '黑子' ? Colors.white : ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      );
    }
    if (game == 3) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: [coral, sky, mint, sun][i],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ink, width: 3),
                boxShadow: const [BoxShadow(color: ink, offset: Offset(0, 3))],
              ),
              child: Icon(
                i == 3 ? Icons.casino : Icons.flight,
                color: i == 3 ? ink : Colors.white,
              ),
            ),
        ],
      );
    }
    if (game == 2) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final i in [0, 2, 3, 1])
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  [coral, sun, lilac, mint][i].withValues(alpha: .3),
                  cream,
                ),
                border: Border.all(color: ink, width: 3),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: ink, offset: Offset(0, 2))],
              ),
              child: AtlasSprite(
                'assets/images/stitch/fruits.png',
                index: i,
                columns: 4,
                rows: 3,
              ),
            ),
        ],
      );
    }
    if (game == 5) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                width: 43,
                height: 70,
                child: ToyCard(
                  radius: 12,
                  padding: const EdgeInsets.all(5),
                  color: i == 2 ? mint : Colors.white,
                  child: i == 2
                      ? const Icon(
                          Icons.question_mark_rounded,
                          color: Colors.white,
                        )
                      : const AtlasSprite(
                          'assets/images/stitch/animals.png',
                          index: 4,
                          columns: 4,
                          rows: 3,
                        ),
                ),
              ),
            ),
        ],
      );
    }
    return CustomPaint(painter: GameArt(game));
  }
}

class SetupDialog extends StatefulWidget {
  final Game game;
  final String role;
  const SetupDialog({super.key, required this.game, required this.role});
  @override
  State<SetupDialog> createState() => _SetupDialogState();
}

class _SetupDialogState extends State<SetupDialog> {
  int difficulty = 1, pairs = 8;
  String mode = 'ai', theme = 'animals', flightMode = 'adventure';
  late List<String?> players;
  @override
  void initState() {
    super.initState();
    players = [widget.role, ...List<String?>.filled(3, null)];
  }

  Widget choices<T>(
    String title,
    List<T> values,
    T selected,
    String Function(T) label,
    void Function(T) select,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: values
            .map(
              (v) => ChoiceChip(
                label: Text(label(v)),
                selected: selected == v,
                onSelected: (_) => setState(() => select(v)),
                selectedColor: sun,
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 18),
    ],
  );
  GameConfig get config {
    if (widget.game == Game.gobang) {
      return GameConfig(
        game: widget.game,
        mode: mode,
        difficulty: difficulty,
        players: [players[0], mode == 'ai' ? null : players[1]],
      );
    }
    if (widget.game == Game.flying) {
      return GameConfig(game: widget.game, mode: flightMode, players: players);
    }
    return GameConfig(
      game: widget.game,
      difficulty: difficulty,
      pairs: pairs,
      theme: theme,
      players: [widget.role],
    );
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: IslandPage(
      title: widget.game == Game.flying
          ? '飞行棋 · 模式与座位'
          : '${gameNames[widget.game.index]} · 开局设置',
      back: () => Navigator.pop(context),
      actions: [
        FamilyPortrait(widget.role, size: 42),
        const SizedBox(width: 8),
        Text(nameOf(widget.role)),
      ],
      child: Column(
        children: [
          Expanded(
            child: widget.game == Game.memory
                ? _memorySetup()
                : SingleChildScrollView(child: _setupContent()),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text('进度自动保存 · 准备好就出发吧', style: TextStyle(fontSize: 12)),
              ),
              ToyButton(
                widget.game == Game.flying
                    ? (flightMode == 'adventure' ? '起飞吧！开始冒险' : '开始经典对局')
                    : '开始游戏',
                icon: Icons.play_circle_outline,
                onPressed: () => Navigator.pop(context, config),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _setupContent() {
    if (widget.game == Game.memory) return _memorySetup();
    if (widget.game == Game.gobang) return _gobangSetup();
    if (widget.game == Game.flying) return _flightSetup();
    if (widget.game == Game.sudoku) return _sudokuSetup();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: ToyCard(
            child: Column(
              children: [
                const Text(
                  '准备开始挑战',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                SizedBox(
                  height: 240,
                  child: Center(
                    child: SizedBox(
                      width: 300,
                      height: 160,
                      child: GameThumbnail(widget.game.index),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: ToyCard(
            color: cream,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FamilyPortrait(widget.role, size: 64),
                    const SizedBox(width: 12),
                    Text(
                      nameOf(widget.role),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  '玩法与奖励',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.game == Game.game2048
                      ? '滑动合并相同数字，首次达到2048可继续挑战。\n\n最高数字128 / 512 / 1024 / 2048\n奖励10 / 20 / 35 / 50分\n\n正常结束只领取一档，主动放弃不计分。'
                      : '50步内达到2000分。相邻水果交换，三连消除；四连或交叉匹配生成炸弹。\n\n通关20分，剩余≥10步加5分，最高连锁≥3加5分。\n\n提示3次，使用后归入辅助纪录。',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _memorySetup() {
    const themes = {
      'animals': '动物萌宠',
      'fruit': '水果乐园',
      'traffic': '交通工具',
      'sports': '趣味运动',
    };
    final columns = pairs == 12 ? 6 : 4;
    final rows = pairs * 2 ~/ columns;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('memory-setup-options'),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ToyCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '选择挑战规模',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              for (final count in [6, 8, 12])
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: count == 12 ? 0 : 8,
                                    ),
                                    child: ToyButton(
                                      '$count对 / ${count * 2}张',
                                      key: ValueKey('memory-pairs-$count'),
                                      color: pairs == count ? sun : cream,
                                      onPressed: () =>
                                          setState(() => pairs = count),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            '挑选喜欢的卡面',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (var row = 0; row < 2; row++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: row == 0 ? 10 : 0,
                              ),
                              child: Row(
                                children: [
                                  for (var col = 0; col < 2; col++)
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          right: col == 0 ? 10 : 0,
                                        ),
                                        child: Semantics(
                                          button: true,
                                          selected:
                                              theme ==
                                              themes.keys.elementAt(
                                                row * 2 + col,
                                              ),
                                          child: InkWell(
                                            onTap: () => setState(
                                              () => theme = themes.keys
                                                  .elementAt(row * 2 + col),
                                            ),
                                            child: ToyCard(
                                              shadow: false,
                                              radius: 16,
                                              padding: const EdgeInsets.all(10),
                                              color:
                                                  theme ==
                                                      themes.keys.elementAt(
                                                        row * 2 + col,
                                                      )
                                                  ? const Color(0xFFE0F5EC)
                                                  : cream,
                                              child: Row(
                                                children: [
                                                  SizedBox.square(
                                                    dimension: 36,
                                                    child: MemoryCardArt(
                                                      theme: themes.keys
                                                          .elementAt(
                                                            row * 2 + col,
                                                          ),
                                                      index: 0,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      themes.values.elementAt(
                                                        row * 2 + col,
                                                      ),
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                  if (theme ==
                                                      themes.keys.elementAt(
                                                        row * 2 + col,
                                                      ))
                                                    const Icon(
                                                      Icons.check_circle,
                                                      size: 18,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
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
                const SizedBox(height: 10),
                ToyCard(
                  key: const ValueKey('memory-setup-rewards'),
                  color: const Color(0xFFFFF3CE),
                  padding: const EdgeInsets.all(10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '完成 +${{6: 10, 8: 15, 12: 20}[pairs]}分',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text('≤${pairs + 2}次 +5分'),
                      TextButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('计分说明'),
                            content: const Text(
                              '每翻开第二张牌计一次尝试。尝试次数越少越好，同次数比较用时。开局全部背面朝上，不提供牌面预览或提示。',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('知道了'),
                              ),
                            ],
                          ),
                        ),
                        child: const Text('计分说明'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 5,
            child: ToyCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${themes[theme]} · $pairs对 · $columns×$rows',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: Row(
                      children: [
                        for (var i = 0; i < 4; i++)
                          Expanded(
                            child: MemoryCardArt(theme: theme, index: i),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => GridView.count(
                        key: const ValueKey('memory-setup-preview'),
                        padding: EdgeInsets.zero,
                        crossAxisCount: columns,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio:
                            ((box.maxWidth - (columns - 1) * 6) / columns) /
                            ((box.maxHeight - (rows - 1) * 6) / rows),
                        children: [
                          for (var i = 0; i < pairs * 2; i++)
                            Container(
                              key: ValueKey('memory-preview-card-$i'),
                              decoration: BoxDecoration(
                                color: sky,
                                border: Border.all(color: ink, width: 1.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: CustomPaint(
                                painter: const CardBackDots(),
                                child: const Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Icon(
                                      Icons.stars_rounded,
                                      color: sun,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '主题与排列示意 · 开局全部背面朝上',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sudokuSetup() {
    Widget reward(String title, String value, Color color) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          const SizedBox(width: 8),
          Tag(value, color: color),
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '选择你的挑战',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text('按推理策略分级，找到适合自己的节奏', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Semantics(
                    button: true,
                    selected: difficulty == i,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => setState(() => difficulty = i),
                      child: ToyCard(
                        color: difficulty == i
                            ? const Color(0xFFFFF1C2)
                            : Colors.white,
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: [
                                  sky,
                                  sun,
                                  mint,
                                ][i].withValues(alpha: .25),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                [
                                  Icons.spa_outlined,
                                  Icons.psychology_outlined,
                                  Icons.auto_awesome,
                                ][i],
                                color: ink,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${['入门', '进阶', '挑战'][i]}数独',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    [
                                      '从单一候选开始，熟悉数字规律',
                                      '结合区块与数对，练习逻辑推理',
                                      '发现复杂候选关系，挑战进阶思考',
                                    ][i],
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '通关基础奖励 +${[20, 30, 40][i]}分',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF607895),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              difficulty == i
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: difficulty == i ? coral : ink,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ToyCard(
                color: const Color(0xFFEAF5FF),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.grid_on_rounded, color: ink),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '数字小课堂',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('每行、每列及每个3×3宫格内，填入不重复的数字1–9。'),
                    const SizedBox(height: 12),
                    const Wrap(
                      spacing: 6,
                      runSpacing: 8,
                      children: [
                        Tag('标准9×9', color: Colors.white),
                        Tag('唯一解', color: Colors.white),
                        Tag('无需猜测', color: Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ToyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emoji_events_outlined, color: coral),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${['入门', '进阶', '挑战'][difficulty]} · 积分奖励',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    reward('完成挑战', '+${[20, 30, 40][difficulty]}分', mint),
                    reward('未使用提示', '+10分', const Color(0xFFDDF2FF)),
                    reward('无提示且零错误', '+10分', const Color(0xFFEDE5FF)),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '本局最高可获',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Tag('${[40, 50, 60][difficulty]} 积分', color: sun),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '每局提示3次，错误可以修改。使用提示后仅获基础奖励。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gobangSetup() {
    Widget player(int seat) => Expanded(
      child: ToyCard(
        shadow: false,
        radius: 18,
        color: seat == 0 ? const Color(0xFFEDF2FA) : cream,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            FamilyPortrait(
              seat == 1 && mode == 'ai' ? null : players[seat],
              size: 56,
            ),
            const SizedBox(height: 6),
            Text(
              nameOf(seat == 1 && mode == 'ai' ? null : players[seat]),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: seat == 0 ? ink : Colors.white,
                    border: Border.all(color: ink),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    seat == 0 ? '黑棋 · 先手' : '白棋 · 后手',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final option in ['ai', 'local'])
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: option == 'ai' ? 16 : 0),
                  child: Semantics(
                    selected: mode == option,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => setState(() {
                        mode = option;
                        if (option == 'local' && players[1] == null) {
                          players[1] = roles.firstWhere((r) => r != players[0]);
                        }
                      }),
                      child: ToyCard(
                        color: mode == option
                            ? const Color(0xFFFFF0BA)
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              option == 'ai'
                                  ? Icons.smart_toy_outlined
                                  : Icons.people_alt_outlined,
                              size: 30,
                              color: ink,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option == 'ai' ? '人机对战' : '双人对战',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    option == 'ai'
                                        ? '与电脑练习，挑战不同难度'
                                        : '同屏轮流落子，与家人切磋',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              mode == option
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: mode == option ? coral : ink,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ToyCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '对局阵容',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            player(0),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'VS',
                                style: TextStyle(
                                  color: coral,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            player(1),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          '黑棋先行 · 再来一局自动交换先手',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ToyCard(
                    color: const Color(0xFFF0F8EE),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '连成五子获胜',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            TextButton(
                              onPressed: _gobangSetupRules,
                              child: const Text('玩法说明'),
                            ),
                          ],
                        ),
                        Text(
                          mode == 'ai' ? '提示3次 · 悔棋1次' : '每人悔棋1次 · 对方确认',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (mode == 'ai') ...[
                    ToyCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '选择难度',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < 3; i++)
                            Padding(
                              padding: EdgeInsets.only(bottom: i == 2 ? 0 : 10),
                              child: Semantics(
                                selected: difficulty == i,
                                button: true,
                                child: InkWell(
                                  onTap: () => setState(() => difficulty = i),
                                  child: ToyCard(
                                    shadow: false,
                                    radius: 16,
                                    padding: const EdgeInsets.all(12),
                                    color: difficulty == i
                                        ? const Color(0xFFFFF0BA)
                                        : cream,
                                    child: Row(
                                      children: [
                                        Icon(
                                          [
                                            Icons.sentiment_satisfied_alt,
                                            Icons.psychology_outlined,
                                            Icons.bolt,
                                          ][i],
                                          color: ink,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          ['入门', '进阶', '挑战'][i],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            [
                                              '熟悉连线与阻挡',
                                              '练习布局，攻守兼备',
                                              '挑战更强的电脑对手',
                                            ][i],
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          difficulty == i
                                              ? Icons.check_circle
                                              : Icons.circle_outlined,
                                          color: difficulty == i ? coral : ink,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (mode == 'local')
                    ToyCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '选择对局成员',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _seat(0, '黑方', allowAi: false),
                          _seat(1, '白方', allowAi: false),
                          const Text(
                            '同屏轮流落子 · 黑棋先行',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Future<void> _gobangSetupRules() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('五子棋 · 玩法说明'),
      content: SingleChildScrollView(
        child: Text(
          '横、竖或斜线连成至少五子获胜。自由五子棋，无禁手、无回合限时。\n\n'
          '${mode == 'ai' ? '提示3次、悔棋1次；使用后整局记为辅助对局。' : '每人可申请悔棋1次，由对方确认；同意后整局记为辅助对局。'}'
          '\n\n黑棋先行，再来一局自动交换先手。进度自动保存。',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  );

  Widget _flightSetup() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          for (final item in [
            ('standard', '经典模式', '纯粹飞行 · 加速与策略', Icons.flight_takeoff, sky),
            ('adventure', '冒险模式', '8加速 · 4护盾 · 4陨石', Icons.explore, sun),
          ])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: InkWell(
                  onTap: () => setState(() => flightMode = item.$1),
                  child: ToyCard(
                    color: flightMode == item.$1
                        ? const Color(0xFFFFF1CB)
                        : Colors.white,
                    borderWidth: flightMode == item.$1 ? 4 : 2,
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: item.$5,
                          child: Icon(item.$4, size: 32, color: ink),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$2,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.$3,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.$1 == 'adventure'
                                    ? '护盾抵挡一次伤害，陨石让飞机退后3格'
                                    : '48格环岛航线，安全格保护飞机',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          flightMode == item.$1
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: flightMode == item.$1 ? coral : ink,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 3 ? 0 : 20),
                child: ToyCard(
                  color: [coral, sun, sky, mint][i].withValues(alpha: .10),
                  child: Column(
                    children: [
                      Text(
                        '${['红队', '黄队', '蓝队', '绿队'][i]}（${i + 1}号位）',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FamilyPortrait(players[i], size: 48),
                      const SizedBox(height: 10),
                      Text(
                        players[i] == null
                            ? '电脑${players.take(i + 1).where((p) => p == null).length}'
                            : nameOf(players[i]),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        players[i] == null ? '电脑托管' : '真人座位',
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      _seat(i, '角色', allowAi: i != 0),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      ToyCard(
        shadow: false,
        child: Wrap(
          spacing: 14,
          runSpacing: 12,
          children: [
            const Text('家庭成员', style: TextStyle(fontWeight: FontWeight.w800)),
            for (final role in roles)
              Tag(
                '${nameOf(role)}${players.contains(role) ? ' · 已入座' : ''}',
                color: players.contains(role) ? mint : const Color(0xFFEFF2FC),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),

      Row(
        children: [
          for (final rule in [
            '48格外圈 + 6格终点道',
            '6点起飞 · 精确抵达',
            '加速格前进3格 · 只触发一次',
            '首队4架全部到达即结束',
          ])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ToyCard(
                  child: Text(rule, style: const TextStyle(fontSize: 13)),
                ),
              ),
            ),
        ],
      ),
    ],
  );

  Widget _seat(int seat, String label, {required bool allowAi}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        SizedBox(width: 64, child: Text(label)),
        Expanded(
          child: DropdownButton<String>(
            isExpanded: true,
            value: players[seat] ?? 'ai',
            items: [
              if (allowAi)
                const DropdownMenuItem(value: 'ai', child: Text('电脑伙伴')),
              for (final role in roles)
                DropdownMenuItem(
                  value: role,
                  enabled: players[seat] == role || !players.contains(role),
                  child: Text(
                    '${nameOf(role)}${players[seat] != role && players.contains(role) ? '（已选）' : ''}',
                  ),
                ),
            ],
            onChanged: (v) =>
                setState(() => players[seat] = v == 'ai' ? null : v),
          ),
        ),
      ],
    ),
  );
}

class SettingsDialog extends StatelessWidget {
  final IslandModel model;
  const SettingsDialog({super.key, required this.model});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => Dialog.fullscreen(
      child: IslandPage(
        title: '游戏设置',
        back: () => Navigator.pop(context),
        actions: const [Tag('V2 设置 · 随心玩', color: sun)],
        child: SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ToyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.volume_up_outlined, color: sky),
                          SizedBox(width: 10),
                          Text(
                            '音量与音效',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text('独立调节音乐和游戏反馈音效'),
                      const SizedBox(height: 26),
                      _volume('背景音乐', 'music', 'musicVolume', .5),
                      const SizedBox(height: 20),
                      _volume('按键与棋子音效', 'sound', 'soundVolume', .7),
                      const SizedBox(height: 20),
                      ToyButton(
                        '快捷静音 · 一键关闭声音',
                        color: const Color(0xFFE6EDFF),
                        icon: Icons.volume_off_outlined,
                        onPressed: () async {
                          await model.setting('music', false);
                          await model.setting('sound', false);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Column(
                  children: [
                    ToyCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.visibility_outlined, color: sun),
                              SizedBox(width: 10),
                              Text(
                                '视觉与护眼体验',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SwitchListTile(
                            title: const Text('减少动效模式'),
                            subtitle: const Text('减少装饰动画，不改变规则与观察时间'),
                            value: model.reducedMotion,
                            onChanged: (v) => model.setting('reducedMotion', v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ToyCard(
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.save_outlined, color: sky),
                              SizedBox(width: 10),
                              Text(
                                '存档与对局说明',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 24),
                          Tag('对局进度和成绩保存在本机', color: Color(0xFFEDF1FF)),
                          SizedBox(height: 24),
                          Text('家庭周榜按上海时间统计：周一00:00至下周一00:00，以对局结束时间归属。'),
                          SizedBox(height: 20),
                          Text(
                            '趣玩小岛 · V2规则\n和家人一起，动动脑筋',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
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
  );
  Widget _volume(
    String title,
    String toggle,
    String volume,
    double fallback,
  ) => ToyCard(
    shadow: false,
    color: const Color(0xFFF1F3FF),
    child: Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          value: model.preferences[toggle] != false,
          onChanged: (v) => model.setting(toggle, v),
        ),
        Row(
          children: [
            const Icon(Icons.volume_down_outlined, size: 20),
            Expanded(
              child: Slider(
                value: (model.preferences[volume] as num? ?? fallback)
                    .toDouble(),
                activeColor: ink,
                thumbColor: sun,
                onChanged: (v) => model.setting(volume, v),
              ),
            ),
            Text(
              '${(((model.preferences[volume] as num? ?? fallback)) * 100).round()}%',
            ),
          ],
        ),
      ],
    ),
  );
}
