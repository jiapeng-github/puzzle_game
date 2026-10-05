import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:puzzle_rules/puzzle_rules.dart';
import 'controller.dart';
import 'design.dart';

const flightPalette = [
  Color(0xFFFF6B57),
  Color(0xFFFFC93C),
  Color(0xFF4D96FF),
  Color(0xFF6BCB77),
];
const flightTeams = ['红队', '黄队', '蓝队', '绿队'];

/// One geometry model drives all 48 track cells, 24 home cells and hit targets.
class FlightGeometry {
  final Size size;
  const FlightGeometry(this.size);
  double get cellW => size.width / 13;
  double get cellH => size.height / 13;
  bool get compact => size.height < 400;
  Offset outer(int index) {
    final k = index % 48, n = k % 12;
    return switch (k ~/ 12) {
      0 => Offset((n + .5) * cellW, cellH * .5),
      1 => Offset(cellW * 12.5, (n + .5) * cellH),
      2 => Offset((12.5 - n) * cellW, cellH * 12.5),
      _ => Offset(cellW * .5, (12.5 - n) * cellH),
    };
  }

  Rect base(int team) {
    final left = team == 0 || team == 3;
    final top = team == 0 || team == 1;
    return Rect.fromLTWH(
      size.width * (left ? .083 : .544),
      size.height * (top ? .09 : .55),
      size.width * .373,
      size.height * .36,
    );
  }

  Offset home(int team, int p) {
    final t = (p - 49) / 5;
    return switch (team) {
      3 => Offset(size.width * .5, size.height * (.115 + .295 * t)),
      2 => Offset(size.width * (.87 - .295 * t), size.height * .5),
      0 => Offset(size.width * .5, size.height * (.885 - .295 * t)),
      _ => Offset(size.width * (.13 + .295 * t), size.height * .5),
    };
  }

  Rect slot(int team, int index) {
    final b = base(team);
    final center = compact
        ? Offset(b.left + b.width * ((index + .5) / 4), b.top + b.height * .65)
        : Offset(
            b.left + b.width * (index % 2 == 0 ? .30 : .70),
            b.top + b.height * (index < 2 ? .43 : .77),
          );
    return Rect.fromCircle(center: center, radius: compact ? 22 : 28);
  }

  Offset plane(int team, int index, int progress) {
    if (progress >= 49) return home(team, progress);
    if (progress >= 0) return outer(flightStarts[team] + progress);
    final r = slot(team, index);
    return r.center;
  }
}

String flightEventText(RuleState s) {
  final events = s.data['flightEvents'] as List? ?? [];
  if (events.isEmpty) return '掷出6点，让第一架飞机起飞吧！';
  return events
      .map((e) {
        final who =
            '${flightTeams[e['seat'] as int]}${e['plane'] == null ? '' : '${(e['plane'] as int) + 1}号'}';
        return switch (e['kind']) {
          'boost' => '$who：加速前进3格',
          'shield' => '$who：获得单次护盾',
          'meteor' => '$who：陨石来袭，退后3格',
          'meteorBlocked' => '$who：护盾抵挡陨石',
          'collisionBlocked' => '$who：护盾抵挡撞击',
          'collision' => '$who：被撞回基地',
          'takeoff' => '$who：起飞！',
          'home' => '$who：抵达终点！',
          'roll' => '$who：掷出${e['value']}点',
          'noMove' => '$who无可走飞机，轮到下一队',
          _ => '$who：飞行完成',
        };
      })
      .join(' · ');
}

class FlightScene extends StatelessWidget {
  final PlayController controller;
  final VoidCallback onBack, onPause, onHelp;
  final Widget? overlay;
  const FlightScene({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onPause,
    required this.onHelp,
    this.overlay,
  });
  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state, d = s.data;
    final adventure = s.config.mode == 'adventure';
    final small = MediaQuery.sizeOf(context).height < 500;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: small ? 56 : 64,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: ink, width: 3)),
              ),
              child: Row(
                children: [
                  ToyButton(
                    '返回大厅',
                    color: Colors.white,
                    icon: Icons.arrow_back,
                    onPressed: onBack,
                  ),
                  const SizedBox(width: 14),
                  if (!small)
                    Tag('累计掷骰 ${d['rolls']} 次', color: const Color(0xFFE7EEFF)),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          children: [
                            const Icon(Icons.flight_takeoff, color: coral),
                            const SizedBox(width: 8),
                            Text(
                              '飞行棋 · ${adventure ? '冒险航线' : '经典航线'}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Tag(adventure ? '冒险模式' : '经典模式'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ToyIconButton(
                    tooltip: '规则说明',
                    icon: Icons.menu_book_rounded,
                    color: const Color(0xFFC7E7FF),
                    onPressed: onHelp,
                  ),
                  ToyIconButton(
                    tooltip: '暂停',
                    icon: Icons.pause_rounded,
                    onPressed: s.terminal ? null : onPause,
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  overlay ??
                  Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            small ? 8 : 14,
                            16,
                            small ? 8 : 14,
                          ),
                          child: FlightBoard(controller: c),
                        ),
                      ),
                      _dock(context),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dock(BuildContext context) {
    final c = controller, s = c.state, d = s.data;
    final turn = d['turn'] as int, dice = d['dice'] as int;
    final human = s.config.players[turn] != null;
    final small = MediaQuery.sizeOf(context).height < 500;
    final options = legalPlanes(d);
    final can = c.canInput && human;
    return Container(
      height: small ? 76 : 88,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ink, width: 3)),
      ),
      child: Row(
        children: [
          if (!small) ...[
            const Tag('加速+3', color: Color(0xFFFFE382)),
            const SizedBox(width: 6),
            if (s.config.mode == 'adventure') ...[
              const Tag('护盾×1', color: Color(0xFFC7E7FF)),
              const SizedBox(width: 6),
              const Tag('陨石−3', color: Color(0xFFFFDAD3)),
            ],
            const SizedBox(width: 16),
          ],
          FamilyPortrait(s.config.players[turn], size: small ? 32 : 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flightEventText(s),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: small ? 11 : 12),
                ),
                const SizedBox(height: 3),
                Text(
                  c.thinking
                      ? '${flightTeams[turn]}电脑正在行动…'
                      : '${flightTeams[turn]} · ${nameOf(s.config.players[turn])}${dice == 0 ? '，请掷骰子' : '，请选择飞机'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color.lerp(flightPalette[turn], ink, .45),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            label: '骰子${dice == 0 ? '待掷' : '$dice点'}',
            child: SizedBox(
              width: 48,
              height: 48,
              child: CustomPaint(painter: DicePainter(dice)),
            ),
          ),
          const SizedBox(width: 12),
          if (dice == 0)
            SizedBox(
              width: small ? 116 : 160,
              child: ToyButton(
                c.thinking ? '电脑行动中' : '掷骰子',
                icon: Icons.casino,
                color: flightPalette[turn],
                onPressed: can ? () => c.command('roll') : null,
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Tooltip(
                        message: '${i + 1}号飞机',
                        child: ToyButton(
                          '${i + 1}',
                          color: flightPalette[turn],
                          onPressed: can && options.contains(i)
                              ? () => c.command('fly', {
                                  'seat': turn,
                                  'plane': i,
                                  'rollId': d['rollId'],
                                })
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class FlightBoard extends StatelessWidget {
  final PlayController controller;
  const FlightBoard({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final c = controller, d = c.state.data, cfg = c.state.config;
    return ToyCard(
      radius: 28,
      borderWidth: 3,
      depth: 6,
      color: const Color(0xFFFAF7F0),
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, box) {
          final geo = FlightGeometry(Size(box.maxWidth, box.maxHeight));
          final options = legalPlanes(d), turn = d['turn'] as int;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (e) async {
              if (!c.canInput || cfg.players[turn] == null || options.isEmpty) {
                return;
              }
              final nearest = [...options]
                ..sort(
                  (a, b) =>
                      (geo.plane(turn, a, d['planes'][turn][a]) -
                              e.localPosition)
                          .distance
                          .compareTo(
                            (geo.plane(turn, b, d['planes'][turn][b]) -
                                    e.localPosition)
                                .distance,
                          ),
                );
              final index = nearest.first;
              if ((geo.plane(turn, index, d['planes'][turn][index]) -
                          e.localPosition)
                      .distance <=
                  28) {
                final candidates = options
                    .where(
                      (i) =>
                          geo.plane(turn, i, d['planes'][turn][i]) ==
                          geo.plane(turn, index, d['planes'][turn][index]),
                    )
                    .toList();
                final revision = c.state.revision;
                final chosen = candidates.length == 1
                    ? index
                    : await showDialog<int>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('选择要移动的飞机'),
                          content: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final i in candidates)
                                ToyButton(
                                  '${i + 1}号飞机',
                                  color: flightPalette[turn],
                                  onPressed: () => Navigator.pop(context, i),
                                ),
                            ],
                          ),
                        ),
                      );
                if (chosen != null &&
                    c.canInput &&
                    c.state.revision == revision) {
                  c.command('fly', {
                    'seat': turn,
                    'plane': chosen,
                    'rollId': d['rollId'],
                  });
                }
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: AdventureBoardPainter(
                      geo,
                      cfg.mode == 'adventure',
                      turn,
                    ),
                  ),
                ),
                for (var t = 0; t < 4; t++)
                  Positioned(
                    left: geo.base(t).left + 8,
                    top: geo.base(t).top + 4,
                    width: geo.base(t).width - 16,
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: flightPalette[t], size: 10),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${flightTeams[t]}·${cfg.players[t] == null ? '电脑${cfg.players.take(t + 1).where((p) => p == null).length}' : nameOf(cfg.players[t])}${t == turn ? ' · 行动中' : ''}',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: geo.compact ? 10 : 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Tooltip(
                          message:
                              '${ints(d['planes'][t]).where((p) => p == 54).length}架已抵达，共4架',
                          child: Semantics(
                            label:
                                '${flightTeams[t]}，${ints(d['planes'][t]).where((p) => p == 54).length}架已抵达，共4架',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .85),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    ints(d['planes'][t]).every((p) => p == 54)
                                        ? Icons.emoji_events_rounded
                                        : Icons.flag_rounded,
                                    size: geo.compact ? 12 : 16,
                                    color: ink,
                                  ),
                                  for (var i = 0; i < 4; i++)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 3),
                                      child: Icon(
                                        d['planes'][t][i] == 54
                                            ? Icons.check_circle
                                            : Icons.circle_outlined,
                                        size: geo.compact ? 9 : 13,
                                        color: d['planes'][t][i] == 54
                                            ? flightPalette[t]
                                            : ink.withValues(alpha: .25),
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
                for (var t = 0; t < 4; t++)
                  for (var i = 0; i < 4; i++)
                    Positioned.fromRect(
                      rect: geo.slot(t, i),
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ParkingPainter(
                            flightPalette[t],
                            d['planes'][t][i] != -1,
                          ),
                        ),
                      ),
                    ),
                if (c.canInput && cfg.players[turn] != null)
                  for (final i in options) _landing(geo, turn, i),
                for (final activeLayer in [false, true])
                  for (var t = 0; t < 4; t++)
                    for (var i = 0; i < 4; i++)
                      if (d['planes'][t][i] != 54 &&
                          activeLayer ==
                              (c.canInput &&
                                  cfg.players[turn] != null &&
                                  t == turn &&
                                  options.contains(i)))
                        _plane(context, geo, t, i, activeLayer),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _landing(FlightGeometry geo, int team, int index) {
    final s = controller.state;
    final projected = Rules.apply(s, 'fly', {
      'seat': team,
      'plane': index,
      'rollId': s.data['rollId'],
    }, revision: s.revision).state;
    final at = geo.plane(team, index, projected.data['planes'][team][index]);
    return Positioned(
      left: at.dx - 12,
      top: at.dy - 12,
      width: 24,
      height: 24,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .9),
            shape: BoxShape.circle,
            border: Border.all(color: flightPalette[team], width: 2),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  Widget _plane(
    BuildContext context,
    FlightGeometry geo,
    int team,
    int index,
    bool active,
  ) {
    final c = controller, d = c.state.data;
    final progress = d['planes'][team][index] as int;
    final point = geo.plane(team, index, progress);
    final shield = (d['shields'] as List?)?[team][index] == 1;
    final complete = progress == 54;
    final occupants = progress < 0
        ? 1
        : [
            for (var t = 0; t < 4; t++)
              for (var i = 0; i < 4; i++)
                if (d['planes'][t][i] >= 0 &&
                    d['planes'][t][i] != 54 &&
                    (geo.plane(t, i, d['planes'][t][i]) - point).distance < .1)
                  i,
          ].length;
    final marker = geo.compact ? 28.0 : 38.0;
    return AnimatedPositioned(
      key: ValueKey('plane-$team-$index'),
      duration: Duration(milliseconds: c.model.reducedMotion ? 0 : 220),
      curve: Curves.easeOut,
      left: point.dx - 22,
      top: point.dy - 22,
      width: 44,
      height: 44,
      child: Semantics(
        button: true,
        enabled: active,
        onTap: active
            ? () => c.command('fly', {
                'seat': team,
                'plane': index,
                'rollId': d['rollId'],
              })
            : null,
        label:
            '${flightTeams[team]}${index + 1}号飞机${shield ? '有护盾' : ''}${complete ? '已到达' : ''}',
        child: Tooltip(
          message:
              '${flightTeams[team]}${index + 1}号${shield ? ' · 单次护盾' : ''}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: null,
            child: Center(
              child: Container(
                width: marker,
                height: marker,
                decoration: BoxDecoration(
                  color: complete ? Colors.white : flightPalette[team],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: shield ? sky : ink,
                    width: shield ? 4 : 2,
                  ),
                  boxShadow: [
                    if (active) const BoxShadow(color: sun, spreadRadius: 4),
                    const BoxShadow(color: ink, offset: Offset(0, 2)),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (occupants > 1)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          color: sun,
                          child: Text(
                            '×$occupants',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    Icon(
                      complete ? Icons.check : Icons.flight,
                      size: marker * .60,
                      color: team == 1 || complete ? ink : Colors.white,
                    ),
                    Positioned(
                      right: 1,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: ink,
                            fontFamily: 'Rubik',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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

class _ParkingPainter extends CustomPainter {
  final Color color;
  final bool empty;
  const _ParkingPainter(this.color, this.empty);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    canvas.drawOval(rect, Paint()..color = Colors.white.withValues(alpha: .65));
    final border = Paint()
      ..color = color.withValues(alpha: empty ? .35 : .65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (empty) {
      for (var i = 0; i < 12; i++) {
        canvas.drawArc(rect, i * math.pi / 6, math.pi / 10, false, border);
      }
    } else {
      canvas.drawOval(rect, border);
    }
  }

  @override
  bool shouldRepaint(_ParkingPainter old) =>
      old.color != color || old.empty != empty;
}

class AdventureBoardPainter extends CustomPainter {
  final FlightGeometry geo;
  final bool adventure;
  final int turn;
  AdventureBoardPainter(this.geo, this.adventure, this.turn);
  void label(
    Canvas c,
    String text,
    Offset point,
    double size, {
    Color color = ink,
    String font = 'Rubik',
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: font,
          fontFamilyFallback: const ['Noto Sans SC'],
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, point - Offset(tp.width / 2, tp.height / 2));
  }

  void tile(
    Canvas c,
    Rect rect,
    Color color, {
    double radius = 12,
    double border = 1.5,
  }) {
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    c.drawRRect(rr.shift(const Offset(0, 2)), Paint()..color = ink);
    c.drawRRect(rr, Paint()..color = color);
    c.drawRRect(
      rr,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = border,
    );
  }

  void icon(Canvas c, IconData icon, Offset at, double size, Color color) =>
      label(
        c,
        String.fromCharCode(icon.codePoint),
        at,
        size,
        color: color,
        font: icon.fontFamily!,
      );
  @override
  void paint(Canvas canvas, Size size) {
    for (var t = 0; t < 4; t++) {
      tile(
        canvas,
        geo.base(t),
        Color.alphaBlend(flightPalette[t].withValues(alpha: .12), Colors.white),
        border: 2,
      );
      if (t == turn) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(geo.base(t), const Radius.circular(12)),
          Paint()
            ..color = flightPalette[t]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5,
        );
      }
    }
    for (var k = 0; k < 48; k++) {
      final at = geo.outer(k), team = flightStarts.indexOf(k);
      final boost = accelerators.contains(k),
          shield = adventure && shieldCells.contains(k),
          meteor = adventure && meteorCells.contains(k);
      final color = team >= 0
          ? flightPalette[team]
          : boost
          ? const Color(0xFFFFE382)
          : shield
          ? const Color(0xFFC7E7FF)
          : meteor
          ? const Color(0xFFE8B0A4)
          : Colors.white;
      tile(
        canvas,
        Rect.fromCenter(
          center: at,
          width: geo.cellW - 4,
          height: geo.cellH - 4,
        ),
        color,
        radius: 10,
      );
      final symbol = team >= 0
          ? Icons.flight_takeoff
          : boost
          ? Icons.bolt
          : shield
          ? Icons.shield_outlined
          : meteor
          ? Icons.local_fire_department
          : null;
      if (symbol == null) {
        label(
          canvas,
          '$k',
          at,
          geo.compact ? 8 : 10,
          color: ink.withValues(alpha: .45),
        );
        if ([3, 15, 27, 39].contains(k)) {
          icon(
            canvas,
            [
              Icons.arrow_forward_rounded,
              Icons.arrow_downward_rounded,
              Icons.arrow_back_rounded,
              Icons.arrow_upward_rounded,
            ][k ~/ 12],
            at + Offset(geo.cellW * .28, 0),
            geo.compact ? 12 : 18,
            ink,
          );
        }
      } else if (geo.compact) {
        icon(canvas, symbol, at, 17, ink);
      } else {
        icon(canvas, symbol, at - const Offset(0, 5), 21, ink);
        label(
          canvas,
          team >= 0
              ? '起点·安全'
              : boost
              ? '+3'
              : shield
              ? '护盾'
              : '−3',
          at + const Offset(0, 12),
          9,
          font: 'Noto Sans SC',
        );
      }
    }
    for (var t = 0; t < 4; t++) {
      for (var p = 49; p <= 54; p++) {
        final at = geo.home(t, p);
        final vertical = t == 0 || t == 3;
        final w = vertical
            ? (geo.compact ? 18.0 : 30.0)
            : math.min(38.0, geo.size.width * .037);
        final h = vertical
            ? geo.size.height * .040
            : (geo.compact ? 18.0 : 30.0);
        tile(
          canvas,
          Rect.fromCenter(center: at, width: w, height: h),
          Color.alphaBlend(
            flightPalette[t].withValues(alpha: .65),
            Colors.white,
          ),
          radius: 4,
          border: 1,
        );
        if (p == 54) {
          icon(
            canvas,
            [
              Icons.arrow_upward_rounded,
              Icons.arrow_forward_rounded,
              Icons.arrow_back_rounded,
              Icons.arrow_downward_rounded,
            ][t],
            at,
            geo.compact ? 12 : 18,
            ink,
          );
        } else {
          label(canvas, '${p - 48}', at, geo.compact ? 9 : 12);
        }
      }
    }
    final center = Offset(size.width / 2, size.height / 2);
    tile(
      canvas,
      Rect.fromCenter(
        center: center,
        width: size.width * .10,
        height: size.height * .10,
      ),
      const Color(0xFFFFF0C0),
      radius: 18,
      border: 2,
    );
    icon(
      canvas,
      Icons.emoji_events_outlined,
      center - Offset(0, geo.compact ? 4 : 9),
      geo.compact ? 20 : 28,
      const Color(0xFFB88700),
    );
    label(
      canvas,
      '胜利小岛',
      center + Offset(0, geo.compact ? 10 : 16),
      geo.compact ? 9 : 12,
      font: 'Noto Sans SC',
    );
  }

  @override
  bool shouldRepaint(AdventureBoardPainter old) =>
      old.turn != turn ||
      old.adventure != adventure ||
      old.geo.size != geo.size;
}

class DicePainter extends CustomPainter {
  final int value;
  const DicePainter(this.value);
  @override
  void paint(Canvas c, Size s) {
    final rr = RRect.fromRectAndRadius(
      Offset.zero & s,
      const Radius.circular(12),
    );
    c.drawRRect(rr, Paint()..color = Colors.white);
    c.drawRRect(
      rr.deflate(1.5),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final points = <Offset>[
      if (value.isOdd) const Offset(.5, .5),
      if (value >= 2) ...[const Offset(.25, .25), const Offset(.75, .75)],
      if (value >= 4) ...[const Offset(.75, .25), const Offset(.25, .75)],
      if (value == 6) ...[const Offset(.25, .5), const Offset(.75, .5)],
    ];
    for (final p in points) {
      c.drawCircle(
        Offset(p.dx * s.width, p.dy * s.height),
        3.5,
        Paint()..color = coral,
      );
    }
    if (value == 0) {
      final text = TextPainter(
        text: const TextSpan(
          text: '?',
          style: TextStyle(
            color: ink,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        c,
        s.center(Offset.zero) - Offset(text.width / 2, text.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(DicePainter old) => old.value != value;
}

class FlightRulesDialog extends StatelessWidget {
  final bool adventure;
  const FlightRulesDialog({super.key, required this.adventure});
  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${adventure ? '冒险航线 · 特殊格' : '经典航线'}与规则指南',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text('48格环岛 + 6格终点道 · 首队4架全部到达获胜'),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in [
                  (
                    Icons.bolt,
                    '加速格',
                    '前进3格',
                    '共8格。落入后前进3格，最多到外环入口48，不连锁触发特殊格。',
                    sun,
                  ),
                  if (adventure)
                    (
                      Icons.shield_outlined,
                      '护盾格',
                      '1层护盾',
                      '共4格。抵挡一次普通撞击或陨石后消失；不叠加，自动使用。',
                      sky,
                    ),
                  if (adventure)
                    (
                      Icons.local_fire_department,
                      '陨石格',
                      '退后3格',
                      '共4格。退后3格，不低于起点0；有护盾则消耗护盾免退。',
                      coral,
                    ),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ToyCard(
                        color: Color.alphaBlend(
                          item.$5.withValues(alpha: .14),
                          Colors.white,
                        ),
                        child: Column(
                          children: [
                            Icon(item.$1, color: item.$5, size: 40),
                            Text(
                              item.$2,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Tag(item.$3, color: item.$5),
                            const SizedBox(height: 16),
                            Text(item.$4, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              '掷6起飞并奖励再掷 · 精确抵达54 · 安全格免撞击 · 终点道无事件\n无在途飞机且连续3次未掷6，下次必出6。特殊格每次只触发一次，按最终落点处理碰撞。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 24),
            ToyButton(
              '我知道了，继续对局',
              icon: Icons.play_arrow,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    ),
  );
}
