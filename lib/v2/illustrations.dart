import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'design.dart';

/// Hand-drawn vector assets scale to phone/tablet without downloaded bitmaps.
class FruitArt extends CustomPainter {
  final int kind;
  FruitArt(this.kind);
  @override
  void paint(Canvas c, Size size) {
    c.scale(size.width / 60, size.height / 60);
    final fill = Paint(),
        line = Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round;
    void oval(Rect r, Color color) {
      c.drawOval(r, fill..color = color);
      c.drawOval(r, line);
    }

    void leaf() {
      oval(const Rect.fromLTWH(27, 6, 19, 9), mint);
      c.drawLine(const Offset(30, 16), const Offset(33, 9), line);
    }

    final variant = kind >= 6;
    switch (kind % 6) {
      case 0:
        final p = Path()
          ..moveTo(11, 23)
          ..cubicTo(7, 4, 52, 4, 49, 23)
          ..cubicTo(48, 38, 38, 49, 30, 53)
          ..cubicTo(19, 48, 12, 36, 11, 23)
          ..close();
        c.drawPath(p, fill..color = variant ? const Color(0xFFFFAEC8) : coral);
        c.drawPath(p, line);
        for (final pt in [
          const Offset(20, 24),
          const Offset(31, 21),
          const Offset(41, 25),
          const Offset(25, 35),
          const Offset(37, 35),
          const Offset(30, 44),
        ]) {
          c.drawOval(
            Rect.fromCenter(center: pt, width: 2.5, height: 4),
            fill..color = sun,
          );
        }
        leaf();
      case 1:
        oval(
          const Rect.fromLTWH(9, 13, 42, 42),
          variant ? const Color(0xFFD5DC74) : const Color(0xFFFFB657),
        );
        leaf();
        c.drawArc(
          const Rect.fromLTWH(16, 20, 28, 28),
          math.pi,
          1.1,
          false,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      case 2:
        oval(const Rect.fromLTWH(6, 15, 48, 33), variant ? mint : sun);
        c.drawLine(
          const Offset(13, 33),
          const Offset(16, 24),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 3,
        );
        leaf();
      case 3:
        oval(const Rect.fromLTWH(9, 9, 43, 43), const Color(0xFFA67B52));
        oval(const Rect.fromLTWH(13, 13, 35, 35), variant ? sun : mint);
        oval(const Rect.fromLTWH(25, 25, 11, 11), cream);
        for (var i = 0; i < 9; i++) {
          final a = i * math.pi * 2 / 9;
          c.drawCircle(
            Offset(30 + 12 * math.cos(a), 30 + 12 * math.sin(a)),
            1.4,
            fill..color = ink,
          );
        }
      case 4:
        for (final pt in [
          const Offset(20, 21),
          const Offset(36, 21),
          const Offset(14, 33),
          const Offset(29, 34),
          const Offset(43, 33),
          const Offset(23, 46),
          const Offset(35, 46),
        ]) {
          oval(Rect.fromCircle(center: pt, radius: 8), variant ? mint : lilac);
        }
        leaf();
      case 5:
        final p = Path()
          ..moveTo(30, 20)
          ..cubicTo(9, 1, 0, 30, 15, 44)
          ..quadraticBezierTo(30, 58, 46, 42)
          ..cubicTo(59, 26, 49, 3, 30, 20)
          ..close();
        c.drawPath(p, fill..color = variant ? coral : const Color(0xFFFFAAC8));
        c.drawPath(p, line);
        c.drawArc(const Rect.fromLTWH(22, 20, 13, 28), -.9, 1.8, false, line);
        leaf();
    }
  }

  @override
  bool shouldRepaint(FruitArt old) => kind != old.kind;
}

class AnimalArt extends CustomPainter {
  final int kind;
  AnimalArt(this.kind);
  @override
  void paint(Canvas c, Size size) {
    c.scale(size.width / 60, size.height / 60);
    final fill = Paint(),
        line = Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    final colors = [sun, Colors.white, coral, lilac, mint, sky];
    final color = colors[kind % 6];
    void oval(Rect r, Color color) {
      c.drawOval(r, fill..color = color);
      c.drawOval(r, line);
    }

    if (kind % 3 == 0) {
      for (final x in [10.0, 37.0]) {
        final p = Path()
          ..moveTo(x, 27)
          ..lineTo(x + 2, 5)
          ..lineTo(x + 15, 22)
          ..close();
        c.drawPath(p, fill..color = color);
        c.drawPath(p, line);
      }
    } else if (kind % 3 == 1) {
      oval(const Rect.fromLTWH(14, 0, 10, 30), color);
      oval(const Rect.fromLTWH(36, 0, 10, 30), color);
    } else {
      oval(const Rect.fromLTWH(7, 9, 18, 20), color);
      oval(const Rect.fromLTWH(35, 9, 18, 20), color);
    }
    oval(const Rect.fromLTWH(9, 18, 42, 37), color);
    if (kind >= 6) {
      oval(const Rect.fromLTWH(13, 25, 14, 14), const Color(0xFFD4AB8B));
      oval(const Rect.fromLTWH(33, 25, 14, 14), const Color(0xFFD4AB8B));
    }
    c.drawCircle(const Offset(21, 32), 2.8, fill..color = ink);
    c.drawCircle(const Offset(39, 32), 2.8, fill);
    oval(const Rect.fromLTWH(25, 39, 10, 6), ink);
    c.drawArc(const Rect.fromLTWH(24, 41, 12, 8), 0, math.pi, false, line);
    if (kind % 3 == 0) {
      c.drawLine(const Offset(13, 42), const Offset(3, 38), line);
      c.drawLine(const Offset(47, 42), const Offset(57, 38), line);
    }
  }

  @override
  bool shouldRepaint(AnimalArt old) => kind != old.kind;
}

class GameArt extends CustomPainter {
  final int game;
  GameArt(this.game);
  @override
  void paint(Canvas c, Size size) {
    c.scale(size.width / 200, size.height / 120);
    final fill = Paint(),
        line = Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
    void box(Rect rect, Color color, {double radius = 12}) {
      final r = RRect.fromRectAndRadius(rect, Radius.circular(radius));
      c.drawRRect(r.shift(const Offset(0, 4)), fill..color = ink);
      c.drawRRect(r, fill..color = color);
      c.drawRRect(r, line);
    }

    void text(String value, Offset at, double font) {
      final p = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'sans-serif',
            fontSize: font,
            color: ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(c, at - Offset(p.width / 2, p.height / 2));
    }

    if (game == 0) {
      box(const Rect.fromLTWH(40, 7, 120, 100), const Color(0xFFFFDFA0));
      for (var i = 0; i < 5; i++) {
        final p = 54 + i * 23.0;
        c.drawLine(Offset(p, 19), Offset(p, 95), line..strokeWidth = 1);
        c.drawLine(Offset(54, 19 + i * 19.0), Offset(146, 19 + i * 19.0), line);
      }
      for (final (x, y, v) in [
        (1, 1, 1),
        (2, 2, 1),
        (3, 3, 1),
        (1, 2, 2),
        (2, 3, 2),
      ]) {
        c.drawCircle(
          Offset(54 + x * 23, 19 + y * 19),
          8,
          fill..color = v == 1 ? ink : Colors.white,
        );
      }
    }
    if (game == 1) {
      for (var i = 0; i < 4; i++) {
        final x = 47.0 + i % 2 * 57, y = 4.0 + i ~/ 2 * 55;
        box(Rect.fromLTWH(x, y, 51, 48), [cream, sun, coral, mint][i]);
        text(['2', '4', '8', '16'][i], Offset(x + 25, y + 24), 25);
      }
    }
    if (game == 2) {
      for (var i = 0; i < 6; i++) {
        c.save();
        c.translate(32 + i % 3 * 45.0, 8 + i ~/ 3 * 46.0);
        FruitArt(i).paint(c, const Size(46, 46));
        c.restore();
      }
    }
    if (game == 3) {
      box(const Rect.fromLTWH(69, 46, 59, 57), Colors.white);
      for (final p in [
        const Offset(83, 60),
        const Offset(114, 60),
        const Offset(98, 74),
        const Offset(83, 90),
        const Offset(114, 90),
      ]) {
        c.drawCircle(p, 4.5, fill..color = ink);
      }
      for (var i = 0; i < 3; i++) {
        c.save();
        c.translate(35 + i * 66.0, 22 + (i % 2) * 6.0);
        c.rotate(-.4);
        final path = Path()
          ..moveTo(0, -17)
          ..lineTo(5, -7)
          ..lineTo(19, 0)
          ..lineTo(19, 6)
          ..lineTo(4, 2)
          ..lineTo(4, 14)
          ..lineTo(8, 18)
          ..lineTo(0, 16)
          ..lineTo(-8, 18)
          ..lineTo(-4, 14)
          ..lineTo(-4, 2)
          ..lineTo(-19, 6)
          ..lineTo(-19, 0)
          ..lineTo(-5, -7)
          ..close();
        c.drawPath(path, fill..color = [coral, sky, mint][i]);
        c.drawPath(path, line);
        c.restore();
      }
    }
    if (game == 4) {
      box(const Rect.fromLTWH(44, 4, 112, 104), Colors.white);
      for (var i = 1; i < 3; i++) {
        c.drawLine(Offset(44 + i * 37.3, 4), Offset(44 + i * 37.3, 108), line);
        c.drawLine(Offset(44, 4 + i * 34.6), Offset(156, 4 + i * 34.6), line);
      }
      for (var i = 0; i < 9; i++) {
        if (i == 1 || i == 4 || i == 8) continue;
        text(
          '${[1, 0, 3, 4, 0, 6, 7, 8, 0][i]}',
          Offset(62 + i % 3 * 37.3, 21 + i ~/ 3 * 34.6),
          22,
        );
      }
    }
    if (game == 5) {
      for (var i = 0; i < 3; i++) {
        c.save();
        c.translate(58 + i * 42.0, 61);
        c.rotate((i - 1) * .18);
        box(
          const Rect.fromLTWH(-27, -42, 54, 84),
          [sky, lilac, Colors.white][i],
        );
        if (i < 2) {
          text('?', const Offset(0, 0), 35);
        } else {
          c.save();
          c.translate(-24, -24);
          AnimalArt(0).paint(c, const Size(48, 48));
          c.restore();
        }
        c.restore();
      }
    }
  }

  @override
  bool shouldRepaint(GameArt old) => old.game != game;
}
