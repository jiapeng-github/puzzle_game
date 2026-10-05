import 'package:flutter/material.dart';
import 'package:puzzle_rules/puzzle_rules.dart';

import 'controller.dart';
import 'design.dart';

String performance(Game game, Json r) {
  if (r['missing'] == true) {
    return [Game.gobang, Game.flying].contains(game) ? '未参与' : '暂无纪录';
  }
  final m = r['metrics'] as Map;
  return switch (game) {
    Game.gobang || Game.flying =>
      '${r['wins']}胜 / ${r['completed']}局 · ${((r['wins'] as int) * 100 / (r['completed'] as int)).toStringAsFixed(0)}%',
    Game.game2048 => '${m['score']}分 · 最高${m['highest']}',
    Game.match3 => '${m['score']}分 · 剩余${m['left']}步',
    Game.sudoku =>
      '${durationLabel(r['durationMs'], precise: true)} · 错误${m['errors']}次',
    Game.memory =>
      '${m['moves']}次 · ${durationLabel(r['durationMs'], precise: true)}',
  };
}

String resultSummary(Game game, Json r, int duration) {
  final m = r['metrics'] as Map;
  return switch (game) {
    Game.gobang => '落子${m['moves']}手 · ${durationLabel(duration)}',
    Game.flying => '到达${m['finished']}/4架 · 掷骰${m['rolls']}次',
    Game.game2048 => '本局${m['score']}分 · 最高数字${m['highest']}',
    Game.match3 => '本局${m['score']}分 · 剩余${m['left']}步 · 最高${m['maxChain']}连锁',
    Game.sudoku =>
      '${durationLabel(duration, precise: true)} · 错误${m['errors']}次 · 提示${m['hints']}次',
    Game.memory =>
      '${m['moves']}次尝试 · ${durationLabel(duration, precise: true)}',
  };
}

class RecordsPage extends StatefulWidget {
  final IslandModel model;
  const RecordsPage({super.key, required this.model});
  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  int tab = 0, difficulty = 1, pairs = 8, humans = 1;
  Game game = Game.sudoku;
  bool assisted = false;
  String mode = 'ai', flightMode = 'adventure';
  GameConfig get filter => GameConfig(
    game: game,
    difficulty: difficulty,
    pairs: pairs,
    mode: game == Game.gobang
        ? mode
        : game == Game.flying
        ? flightMode
        : 'standard',
    players: game == Game.gobang
        ? ['boy', mode == 'local' ? 'girl' : null]
        : game == Game.flying
        ? [for (var i = 0; i < 4; i++) i < humans ? roles[i] : null]
        : ['boy'],
  );
  Widget options<T>(
    List<T> values,
    T selected,
    String Function(T) name,
    void Function(T) change,
  ) => Wrap(
    spacing: 6,
    runSpacing: 4,
    children: [
      for (final v in values)
        ChoiceChip(
          label: Text(name(v)),
          selected: v == selected,
          onSelected: (_) => setState(() => change(v)),
          selectedColor: sun,
        ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final rows = tab == 2
        ? gameRanking(widget.model.records, filter, assisted: assisted)
        : tab == 0
        ? widget.model.weekly
        : widget.model.total;
    return IslandPage(
      title: '家庭排行榜',
      centerTitle: true,
      actions: [
        options(
          [0, 1, 2],
          tab,
          (v) => ['本周积分榜', '家庭总榜', '单项游戏纪录'][v],
          (v) => tab = v,
        ),
      ],
      back: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tab == 2) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: options(Game.values, game, (v) => gameNames[v.index], (v) {
                game = v;
                assisted = false;
              }),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (game == Game.gobang) ...[
                    options(
                      ['ai', 'local'],
                      mode,
                      (v) => v == 'ai' ? '人机' : '双人',
                      (v) => mode = v,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (game == Game.sudoku ||
                      (game == Game.gobang && mode == 'ai'))
                    options(
                      [0, 1, 2],
                      difficulty,
                      (v) => ['入门', '进阶', '挑战'][v],
                      (v) => difficulty = v,
                    ),
                  if (game == Game.memory)
                    options([6, 8, 12], pairs, (v) => '$v对', (v) => pairs = v),
                  if (game == Game.flying) ...[
                    options(
                      ['standard', 'adventure'],
                      flightMode,
                      (v) => v == 'adventure' ? '冒险模式' : '经典模式',
                      (v) => flightMode = v,
                    ),
                    const SizedBox(width: 8),
                    options(
                      [1, 2, 3, 4],
                      humans,
                      (v) => '$v位真人',
                      (v) => humans = v,
                    ),
                  ],
                  if ([
                    Game.gobang,
                    Game.match3,
                    Game.sudoku,
                  ].contains(game)) ...[
                    const SizedBox(width: 8),
                    options(
                      [false, true],
                      assisted,
                      (v) => v ? '辅助对局' : '独立完成',
                      (v) => assisted = v,
                    ),
                  ],
                  const SizedBox(width: 8),
                  const Tag('新版规则', color: mint),
                ],
              ),
            ),
          ] else
            Text(
              tab == 0
                  ? '上海时间 · ${shanghaiWeek(DateTime.now())} 起一周 · 按对局结束时间归属'
                  : '对局奖励累计，各游戏成绩独立统计',
              style: const TextStyle(fontSize: 13),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: ToyCard(
              borderWidth: 3.5,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Tag(
                          tab == 2
                              ? '单项游戏纪录'
                              : tab == 0
                              ? '家庭周榜'
                              : '家庭总榜',
                          color: sun,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            tab == 2 ? '相同规则的成绩公平比较' : '一起积累快乐，记录每一次进步',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, i) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final r = rows[i], id = r['player'] as String;
                        return ToyCard(
                          radius: 14,
                          shadow: false,
                          color: id == widget.model.role
                              ? sun.withValues(alpha: .28)
                              : const Color(0xFFF7F9FF),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    ProfilePage(model: widget.model, role: id),
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 54,
                                  child: CircleAvatar(
                                    radius: 19,
                                    backgroundColor: r['rank'] == 1
                                        ? sun
                                        : const Color(0xFFE7EEFF),
                                    child: Text(
                                      r['rank'] == null ? '—' : '${r['rank']}',
                                      style: const TextStyle(
                                        color: ink,
                                        fontFamily: 'Rubik',
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                FamilyPortrait(id, size: 48),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    nameOf(id),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                if (tab != 2 &&
                                    MediaQuery.sizeOf(context).width >
                                        1000) ...[
                                  Tag(
                                    '本周 +${tab == 0 ? r['points'] : widget.model.weekly.firstWhere((v) => v['player'] == id)['points']}',
                                    color: mint.withValues(alpha: .2),
                                  ),
                                  const SizedBox(width: 24),
                                  SizedBox(
                                    width: 120,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value:
                                            (rows.first['points'] as int) == 0
                                            ? 0
                                            : (r['points'] as int) /
                                                  (rows.first['points'] as int),
                                        minHeight: 10,
                                        color: id == widget.model.role
                                            ? coral
                                            : mint,
                                        backgroundColor: cream,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                ],
                                Flexible(
                                  child: Text(
                                    tab == 2
                                        ? performance(game, r)
                                        : '${r['points']}分',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tab == 2
                ? switch (game) {
                    Game.gobang || Game.flying => '胜场相同并列；胜率仅展示，不打破并列。',
                    Game.game2048 => '先比较单局成绩，再比较同一局最高数字。',
                    Game.match3 => '仅通关局：先比较成绩，再比较剩余步数。',
                    Game.sudoku => '同难度同辅助状态：先比较有效用时，再比较错误次数。点击记录可查看精确毫秒。',
                    Game.memory => '同对数：先比较尝试次数，再比较有效用时。点击记录可查看精确毫秒。',
                  }
                : '家庭积分记录参与积累，同分同名次。',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  final IslandModel model;
  final String role;
  const ProfilePage({super.key, required this.model, required this.role});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final rows = widget.model.records
        .where((r) => r['player'] == widget.role)
        .toList();
    final points = widget.model.total.firstWhere(
      (r) => r['player'] == widget.role,
    )['points'];
    return IslandPage(
      title: '${nameOf(widget.role)}的游戏记录',
      back: () => Navigator.pop(context),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ToyCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          FamilyPortrait(widget.role, size: 64),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              nameOf(widget.role),
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '累计完成 ${rows.where((r) => r['outcome'] != 'abandoned').length} 局',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: ToyCard(
                  color: const Color(0xFFFFEAE2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Tag('家庭奖励积分', color: coral),
                      const SizedBox(height: 18),
                      Text(
                        '$points 分',
                        style: const TextStyle(
                          fontSize: 32,
                          color: coral,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '用于家庭榜参与积累，各游戏成绩独立统计',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('还没有对局记录，玩一局试试吧！'))
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = rows[i], c = GameConfig.fromJson(r['config']);
                      return ToyCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        child: ExpansionTile(
                          title: Text(
                            '${gameNames[c.game.index]} · ${{'won': '完成 / 获胜', 'lost': '本局结束', 'draw': '平局', 'abandoned': '已放弃'}[r['outcome']]}',
                          ),
                          subtitle: Text(
                            '${c.game == Game.flying ? (c.mode == 'adventure' ? '冒险模式 · ' : '经典模式 · ') : ''}${resultSummary(c.game, r, r['durationMs'])}\n${r['assisted'] == true ? '辅助对局' : '独立对局'} · 家庭积分 +${r['reward']}',
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                '${r['endedAt']}\n${(r['breakdown'] as Map).entries.map((e) => '${e.key} +${e.value}').join(' / ')}\n规则：新版 · 有效用时 ${r['durationMs']}毫秒',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
