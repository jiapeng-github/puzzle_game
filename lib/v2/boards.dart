import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_rules/puzzle_rules.dart';
import 'controller.dart';
import 'design.dart';
import 'stitch_art.dart';

class GameBoard extends StatefulWidget {
  final PlayController controller;
  final int selected;
  final ValueChanged<int> select;
  const GameBoard({
    super.key,
    required this.controller,
    required this.selected,
    required this.select,
  });
  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  final FocusNode focus = FocusNode();
  Offset drag = Offset.zero;
  PlayController get c => widget.controller;
  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  void tile(int i) {
    if (!c.canInput) return;
    final s = c.state;
    switch (s.config.game) {
      case Game.sudoku:
        widget.select(i);
      case Game.memory:
        c.command('flip', {'index': i});
      case Game.match3:
        if (widget.selected >= 0 && widget.selected != i) {
          c.command('swap', {'from': widget.selected, 'to': i});
          widget.select(-1);
        } else {
          widget.select(i);
        }
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = c.state, d = s.data, game = s.config.game;
    Widget board;
    if (game == Game.gobang) {
      board = LayoutBuilder(
        builder: (context, box) => GestureDetector(
          onTapUp: (event) {
            if (!c.canInput) return;
            final side = math.min(box.maxWidth, box.maxHeight),
                step = (side - 32) / 14;
            final x = ((event.localPosition.dx - 16) / step).round(),
                y = ((event.localPosition.dy - 16) / step).round();
            if (x < 0 || y < 0 || x >= 15 || y >= 15) return;
            c.command('place', {'index': y * 15 + x, 'color': d['turn']});
          },
          child: CustomPaint(
            size: Size.square(math.min(box.maxWidth, box.maxHeight)),
            painter: GobangPainter(d),
          ),
        ),
      );
    } else if (game == Game.flying) {
      board = LayoutBuilder(
        builder: (context, box) => GestureDetector(
          onTapUp: (event) {
            if (!c.canInput || s.config.players[d['turn'] as int] == null) {
              return;
            }
            final centers = flightTokenCenters(
              d,
              Size(box.maxWidth, box.maxHeight),
            );
            final options = legalPlanes(d)
              ..sort(
                (a, b) =>
                    (centers[(d['turn'] as int) * 4 + a] - event.localPosition)
                        .distance
                        .compareTo(
                          (centers[(d['turn'] as int) * 4 + b] -
                                  event.localPosition)
                              .distance,
                        ),
              );
            if (options.isNotEmpty &&
                (centers[(d['turn'] as int) * 4 + options.first] -
                            event.localPosition)
                        .distance <
                    math.min(box.maxWidth, box.maxHeight) / 18) {
              c.command('fly', {
                'seat': d['turn'],
                'plane': options.first,
                'rollId': d['rollId'],
              });
            }
          },
          child: CustomPaint(
            painter: FlightPainter(d),
            child: const SizedBox.expand(),
          ),
        ),
      );
    } else {
      final count = game == Game.sudoku
          ? 81
          : game == Game.match3
          ? 64
          : game == Game.memory
          ? s.config.pairs * 2
          : 16;
      final columns = game == Game.sudoku
          ? 9
          : game == Game.match3
          ? 8
          : game == Game.memory && s.config.pairs == 12
          ? 6
          : 4;
      final gap = game == Game.sudoku
              ? 0.0
              : game == Game.match3
              ? 2.0
              : game == Game.game2048
              ? 14.0
              : 10.0,
          rows = count ~/ columns;
      board = LayoutBuilder(
        builder: (context, box) => GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            childAspectRatio:
                ((box.maxWidth - gap * (columns - 1)) / columns) /
                ((box.maxHeight - gap * (rows - 1)) / rows),
          ),
          itemCount: count,
          itemBuilder: (context, i) => _cell(i),
        ),
      );
    }
    final ratio = game == Game.memory
        ? (s.config.pairs == 6
              ? 4 / 3
              : s.config.pairs == 12
              ? 6 / 4
              : 1.0)
        : 1.0;
    return Center(
      child: AspectRatio(
        aspectRatio: ratio,
        child: ToyCard(
          radius: game == Game.game2048 ? 32 : 24,
          borderWidth: game == Game.game2048 ? 4 : 3,
          padding: EdgeInsets.all(
            game == Game.gobang
                ? 4
                : game == Game.sudoku
                ? 4
                : game == Game.game2048
                ? 16
                : 10,
          ),
          color: game == Game.gobang
              ? const Color(0xFFECCC92)
              : game == Game.game2048
              ? const Color(0xFFE5D7B8)
              : game == Game.memory
              ? const Color(0xFFE7F8F0)
              : Colors.white,
          child: game == Game.game2048
              ? KeyboardListener(
                  focusNode: focus,
                  autofocus: true,
                  onKeyEvent: (event) {
                    if (event is! KeyDownEvent || !c.canInput) return;
                    final key = event.logicalKey;
                    final direction = {
                      LogicalKeyboardKey.arrowLeft: 'left',
                      LogicalKeyboardKey.arrowRight: 'right',
                      LogicalKeyboardKey.arrowUp: 'up',
                      LogicalKeyboardKey.arrowDown: 'down',
                    }[key];
                    if (direction != null) {
                      c.command('move', {'direction': direction});
                    }
                  },
                  child: GestureDetector(
                    onPanStart: (_) => drag = Offset.zero,
                    onPanUpdate: (e) => drag += e.delta,
                    onPanEnd: (_) {
                      if (!c.canInput || drag.distance < 24) return;
                      final direction = drag.dx.abs() > drag.dy.abs()
                          ? (drag.dx > 0 ? 'right' : 'left')
                          : (drag.dy > 0 ? 'down' : 'up');
                      c.command('move', {'direction': direction});
                    },
                    child: board,
                  ),
                )
              : board,
        ),
      ),
    );
  }

  Widget _cell(int i) {
    final s = c.state, d = s.data, g = s.config.game;
    final value = d['board'][i] as int;
    Color color = Colors.white;
    Widget child = const SizedBox();
    var selected = widget.selected == i;
    if (g == Game.game2048) {
      color = switch (value) {
        0 => const Color(0xFFDBCEB3),
        2 => const Color(0xFFFFFCF3),
        4 => const Color(0xFFFFF0CB),
        8 => const Color(0xFFFFB79A),
        16 => const Color(0xFFFFA071),
        32 || 64 => coral,
        128 || 256 => sun,
        _ => mint,
      };
      child = value == 0
          ? const Icon(Icons.circle, size: 9, color: Color(0xFFCEBFA0))
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    child: Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 44,
                        fontFamily: 'Rubik',
                        fontWeight: FontWeight.w900,
                        color: value == 32 || value == 64 ? Colors.white : ink,
                      ),
                    ),
                  ),
                ),
                if (MediaQuery.sizeOf(context).height > 500)
                  Text(
                    const {
                          2: 'SEEDS',
                          4: 'SPROUT',
                          8: 'BLOOM',
                          16: 'BRANCH',
                          32: 'FOREST',
                          64: 'ISLAND',
                          128: 'KINGDOM',
                        }[value] ??
                        'DREAM',
                    style: const TextStyle(
                      fontSize: 8,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            );
    } else if (g == Game.match3) {
      color = [
        coral,
        sun,
        sky,
        mint,
        lilac,
        const Color(0xFFFFABC9),
      ][value % 6].withValues(alpha: .22);
      selected = selected || (d['hint'] as List).contains(i);
      child = Stack(
        alignment: Alignment.center,
        children: [
          FractionallySizedBox(
            widthFactor: selected ? .84 : .74,
            heightFactor: selected ? .84 : .74,
            child: AtlasSprite(
              'assets/images/stitch/fruits.png',
              index: value % 6,
              columns: 4,
              rows: 3,
            ),
          ),
          if ((d['hint'] as List).contains(i))
            Positioned(
              right: 1,
              bottom: 1,
              child: Icon(
                ((d['hint'][0] as int) - (d['hint'][1] as int)).abs() == 1
                    ? Icons.swap_horiz_rounded
                    : Icons.swap_vert_rounded,
                size: 20,
                color: ink,
              ),
            ),
          if (value >= 6)
            const Positioned(
              right: 0,
              top: 0,
              child: Icon(Icons.bolt, color: ink, size: 16),
            ),
        ],
      );
    } else if (g == Game.memory) {
      final matched = (d['matched'] as List).contains(i),
          open = matched || (d['open'] as List).contains(i);
      color = matched
          ? mint.withValues(alpha: .45)
          : open
          ? sun.withValues(alpha: .35)
          : sky;
      child = open
          ? Padding(
              padding: const EdgeInsets.all(8),
              child: MemoryCardArt(theme: s.config.theme, index: value),
            )
          : CustomPaint(
              painter: const CardBackDots(),
              child: Center(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: sun,
                    shape: BoxShape.circle,
                    border: Border.all(color: ink, width: 2),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            );
      return Semantics(
        label: open
            ? '卡片${i + 1} 图案${value + 1}${matched ? ' 已配对' : ''}'
            : '卡片${i + 1} 背面',
        button: true,
        child: InkWell(
          onTap: () => tile(i),
          child: AnimatedContainer(
            duration: Duration(milliseconds: c.model.reducedMotion ? 0 : 180),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ink, width: 2),
            ),
            child: child,
          ),
        ),
      );
    } else if (g == Game.sudoku) {
      final fixed = d['puzzle'][i] != 0,
          hinted = (d['hinted'] as List).contains(i),
          wrong = value != 0 && value != d['solution'][i];
      final focus = widget.selected;
      final related =
          focus >= 0 &&
          (i ~/ 9 == focus ~/ 9 ||
              i % 9 == focus % 9 ||
              (i ~/ 27 == focus ~/ 27 && i % 9 ~/ 3 == focus % 9 ~/ 3));
      final same = focus >= 0 && value != 0 && d['board'][focus] == value;
      final completeBox = List.generate(
        9,
        (n) => (i ~/ 27) * 27 + (i % 9 ~/ 3) * 3 + (n ~/ 3) * 9 + n % 3,
      ).every((j) => d['board'][j] == d['solution'][j]);
      color = selected
          ? const Color(0xFFFFE58A)
          : wrong
          ? const Color(0xFFFFE1DB)
          : same
          ? const Color(0xFFB8E8DE)
          : related
          ? const Color(0xFFDDF0FF)
          : completeBox
          ? const Color(0xFFE4F7EC)
          : (i ~/ 27 + i % 9 ~/ 3).isEven
          ? const Color(0xFFF0F7FC)
          : Colors.white;
      final notes = ints(d['notes'][i]);
      child = value != 0
          ? FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$value${wrong ? '!' : ''}',
                style: TextStyle(
                  color: wrong
                      ? const Color(0xFFBF3029)
                      : fixed
                      ? ink
                      : const Color(0xFF227AC1),
                  fontSize: 24,
                  fontWeight: fixed ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            )
          : notes.isEmpty
          ? const SizedBox()
          : GridView.count(
              crossAxisCount: 3,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                for (var n = 1; n <= 9; n++)
                  Center(
                    child: FittedBox(
                      child: Text(
                        notes.contains(n) ? '$n' : '',
                        style: const TextStyle(
                          fontSize: 8,
                          color: Color(0xFF607895),
                        ),
                      ),
                    ),
                  ),
              ],
            );
      return Semantics(
        label:
            '第${i ~/ 9 + 1}行第${i % 9 + 1}列 ${value == 0 ? '空白' : value}${fixed ? ' 固定' : ''}${wrong ? ' 错误' : ''}',
        selected: selected,
        child: InkWell(
          onTap: () => tile(i),
          child: AnimatedContainer(
            duration: Duration(milliseconds: c.model.reducedMotion ? 0 : 160),
            decoration: BoxDecoration(
              color: color,
              border: Border(
                right: BorderSide(color: ink, width: i % 3 == 2 ? 2 : .4),
                bottom: BorderSide(color: ink, width: i ~/ 9 % 3 == 2 ? 2 : .4),
              ),
            ),
            padding: const EdgeInsets.all(2),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: AnimatedSwitcher(
                    duration: Duration(
                      milliseconds: c.model.reducedMotion ? 0 : 160,
                    ),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: KeyedSubtree(key: ValueKey(value), child: child),
                  ),
                ),
                if (hinted)
                  const Align(
                    alignment: Alignment.topRight,
                    child: Icon(
                      Icons.lock_rounded,
                      size: 9,
                      color: Color(0xFF607895),
                    ),
                  ),
                if (selected)
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: ink, width: 2),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return Semantics(
      label: g == Game.game2048
          ? '${value == 0 ? '空' : value}'
          : '水果${value % 6 + 1}${value >= 6 ? ' 炸弹' : ''}',
      button: g == Game.match3,
      child: InkWell(
        onTap: () => tile(i),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(g == Game.match3 ? 8 : 16),
            boxShadow: g == Game.game2048 && value != 0
                ? const [BoxShadow(color: ink, offset: Offset(0, 4))]
                : null,
            border: Border.all(
              color: selected
                  ? coral
                  : ink.withValues(
                      alpha: g == Game.game2048 && value != 0 ? 1 : .15,
                    ),
              width: selected || (g == Game.game2048 && value != 0) ? 3 : 1,
            ),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: c.model.reducedMotion ? 0 : 160),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: KeyedSubtree(key: ValueKey(value), child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class GobangPainter extends CustomPainter {
  final Json d;
  GobangPainter(this.d);
  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height),
        step = (side - 32) / 14,
        stroke = Paint()
          ..color = ink.withValues(alpha: .65)
          ..strokeWidth = 1;
    for (var i = 0; i < 15; i++) {
      final p = 16 + i * step;
      canvas.drawLine(Offset(16, p), Offset(side - 16, p), stroke);
      canvas.drawLine(Offset(p, 16), Offset(p, side - 16), stroke);
    }
    for (final point in [
      const Offset(3, 3),
      const Offset(11, 3),
      const Offset(7, 7),
      const Offset(3, 11),
      const Offset(11, 11),
    ]) {
      canvas.drawCircle(
        Offset(16 + point.dx * step, 16 + point.dy * step),
        2.5,
        Paint()..color = ink,
      );
    }
    for (var i = 0; i < 15; i++) {
      final column = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(65 + i),
          style: const TextStyle(
            fontSize: 8,
            color: ink,
            fontFamily: 'sans-serif',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      column.paint(canvas, Offset(16 + i * step - column.width / 2, 1));
      final row = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            fontSize: 8,
            color: ink,
            fontFamily: 'sans-serif',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      row.paint(canvas, Offset(1, 16 + i * step - row.height / 2));
    }
    final b = ints(d['board']), history = ints(d['history']);
    for (var i = 0; i < 225; i++) {
      final center = Offset(16 + i % 15 * step, 16 + i ~/ 15 * step);
      if (b[i] != 0) {
        canvas.drawCircle(
          center,
          step * .43,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-.4, -.5),
              colors: b[i] == 1
                  ? [const Color(0xFF657385), ink]
                  : [Colors.white, const Color(0xFFCAD4DF)],
            ).createShader(Rect.fromCircle(center: center, radius: step * .43)),
        );
        canvas.drawCircle(
          center,
          step * .43,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
        if (history.isNotEmpty && history.last == i) {
          canvas.drawCircle(center, 2.6, Paint()..color = coral);
        }
      }
      if (d['hint'] == i) {
        canvas.drawCircle(
          center,
          step * .36,
          Paint()
            ..color = coral
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }
  }

  @override
  bool shouldRepaint(GobangPainter old) => old.d != d;
}

class FlightPainter extends CustomPainter {
  final Json d;
  FlightPainter(this.d);
  static const colors = [coral, sun, sky, mint];
  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height), unit = side / 14;
    Offset outer(int k) => flightOuter(k, unit);

    final center = Offset(side / 2, side / 2);
    void dot(Offset at, Color color, String label, {double factor = .39}) {
      canvas.drawCircle(at, unit * factor, Paint()..color = color);
      canvas.drawCircle(
        at,
        unit * factor,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      if (label.isNotEmpty) {
        final text = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: ink,
              fontFamily: 'sans-serif',
              fontSize: unit * (factor < .3 ? .20 : .36),
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, at - Offset(text.width / 2, text.height / 2));
      }
    }

    final hangars = [
      Offset(side * .21, side * .79),
      Offset(side * .21, side * .21),
      Offset(side * .79, side * .79),
      Offset(side * .79, side * .21),
    ];
    for (var team = 0; team < 4; team++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: hangars[team],
          width: unit * 3.8,
          height: unit * 3.8,
        ),
        const Radius.circular(18),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = colors[team].withValues(alpha: .13),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final label = TextPainter(
        text: TextSpan(
          text: ['红队基地', '黄队基地', '蓝队基地', '绿队基地'][team],
          style: TextStyle(
            fontFamily: 'sans-serif',
            color: ink,
            fontSize: unit * .34,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        hangars[team] + Offset(-label.width / 2, -unit * 1.65),
      );
    }
    for (var k = 0; k < 48; k++) {
      final team = flightStarts.indexOf(k);
      dot(
        outer(k),
        team >= 0
            ? colors[team]
            : accelerators.contains(k)
            ? lilac
            : const Color(0xFFF2ECD9),
        team >= 0
            ? '安'
            : accelerators.contains(k)
            ? '+3'
            : '',
      );
    }
    Offset pos(int team, int p) {
      if (p <= 48) return outer((flightStarts[team] + p) % 48);
      return Offset.lerp(outer(flightStarts[team]), center, (p - 48) / 8)!;
    }

    for (var team = 0; team < 4; team++) {
      for (var p = 49; p <= 54; p++) {
        dot(
          pos(team, p),
          colors[team].withValues(alpha: .22),
          '${p - 48}',
          factor: .18,
        );
      }
    }
    dot(center, sun, '★', factor: .7);
    final options = legalPlanes(d), centers = flightTokenCenters(d, size);
    for (var t = 0; t < 4; t++) {
      for (var i = 0; i < 4; i++) {
        final at = centers[t * 4 + i];
        final active = t == d['turn'] && options.contains(i);
        if (active) {
          canvas.drawCircle(
            at,
            unit * .57,
            Paint()..color = colors[t].withValues(alpha: .3),
          );
        }
        dot(at, Colors.white, '', factor: active ? 0.65 : 0.56);
        final plane = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(Icons.flight.codePoint),
            style: TextStyle(
              fontFamily: Icons.flight.fontFamily,
              color: colors[t],
              fontSize: unit * .66,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        plane.paint(canvas, at - Offset(plane.width / 2, plane.height / 2));
        final number = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: TextStyle(
              fontFamily: 'sans-serif',
              fontSize: unit * .25,
              color: ink,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        number.paint(canvas, at + Offset(unit * .25, unit * .1));
      }
    }
  }

  @override
  bool shouldRepaint(FlightPainter old) => old.d != d;
}

List<Offset> flightTokenCenters(Json d, Size size) {
  final side = math.min(size.width, size.height),
      unit = side / 14,
      center = Offset(side / 2, side / 2);
  Offset outer(int k) => flightOuter(k, unit);

  final hangars = [
    Offset(side * .21, side * .79),
    Offset(side * .21, side * .21),
    Offset(side * .79, side * .79),
    Offset(side * .79, side * .21),
  ];
  final occupied = <String, int>{}, out = <Offset>[];
  for (var team = 0; team < 4; team++) {
    for (var i = 0; i < 4; i++) {
      final p = d['planes'][team][i] as int;
      var at = p == -1
          ? hangars[team] +
                Offset((i % 2 - .5) * unit * 1.4, (i ~/ 2 - .5) * unit * 1.4)
          : p <= 48
          ? outer(flightStarts[team] + p)
          : Offset.lerp(outer(flightStarts[team]), center, (p - 48) / 8)!;
      final key = '${at.dx},${at.dy}', offset = occupied[key] ?? 0;
      occupied[key] = offset + 1;
      at += Offset(offset * unit * .16, -offset * unit * .16);
      out.add(at);
    }
  }
  return out;
}

Offset flightOuter(int k, double unit) {
  const quarter = [
    Offset(6, 0),
    Offset(7, 0),
    Offset(8, 0),
    Offset(8, 1),
    Offset(8, 2),
    Offset(8, 3),
    Offset(8, 4),
    Offset(9, 4),
    Offset(10, 4),
    Offset(11, 4),
    Offset(12, 4),
    Offset(12, 5),
  ];
  k %= 48;
  var p = quarter[k % 12] - const Offset(6, 6);
  for (var r = 0; r < k ~/ 12; r++) {
    p = Offset(-p.dy, p.dx);
  }
  return (p + const Offset(7, 7)) * unit;
}

class CardBackDots extends CustomPainter {
  const CardBackDots();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: .7);
    for (double y = 8; y < size.height; y += 14) {
      for (double x = 8; x < size.width; x += 14) {
        canvas.drawCircle(Offset(x, y), 1.5, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CardBackDots oldDelegate) => false;
}
