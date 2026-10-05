import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:puzzle_rules/puzzle_rules.dart';
import 'stitch_art.dart';

const ink = Color(0xFF24334B),
    cream = Color(0xFFFFFDF7),
    coral = Color(0xFFFF7355),
    sky = Color(0xFF59BDF7),
    sun = Color(0xFFFFD45B),
    mint = Color(0xFF65CDAA),
    lilac = Color(0xFFB49BFA);
const gameColors = [sky, sun, coral, mint, lilac, Color(0xFFFFAAC8)];
const gameIcons = [
  Icons.grid_on_rounded,
  Icons.numbers_rounded,
  Icons.local_florist_rounded,
  Icons.flight_rounded,
  Icons.edit_note_rounded,
  Icons.style_rounded,
];
String nameOf(String? id) => id == null ? '电脑伙伴' : roleNames[roles.indexOf(id)];
String durationLabel(int ms, {bool precise = false}) {
  final seconds = ms ~/ 1000;
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}${precise ? '.${((ms % 1000) ~/ 10).toString().padLeft(2, '0')}' : ''}';
}

ThemeData islandTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: cream,
  colorScheme: ColorScheme.fromSeed(seedColor: coral, surface: cream),
  fontFamily: 'Noto Sans SC',
  fontFamilyFallback: const [
    'Noto Sans SC',
    'PingFang SC',
    'Noto Sans CJK SC',
    'Microsoft YaHei',
  ],
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: ink, fontSize: 15),
    titleLarge: TextStyle(
      color: ink,
      fontSize: 24,
      fontWeight: FontWeight.w800,
    ),
    titleMedium: TextStyle(
      color: ink,
      fontSize: 18,
      fontWeight: FontWeight.w800,
    ),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.all(Colors.white),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? mint
          : const Color(0xFFE4EAF7),
    ),
    trackOutlineColor: WidgetStateProperty.all(ink),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: cream,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: const BorderSide(color: ink, width: 3),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
  ),
);

class ToyCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final bool shadow;
  final double radius;
  final double borderWidth, depth;
  const ToyCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(16),
    this.shadow = true,
    this.radius = 24,
    this.borderWidth = 3,
    this.depth = 6,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Color.alphaBlend(color, cream),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: ink, width: borderWidth),
      boxShadow: shadow
          ? [BoxShadow(color: ink, offset: Offset(0, depth))]
          : null,
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class ToyButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  const ToyButton(
    this.label, {
    super.key,
    this.onPressed,
    this.color = coral,
    this.icon,
  });
  @override
  State<ToyButton> createState() => _ToyButtonState();
}

class _ToyButtonState extends State<ToyButton> {
  bool pressed = false;
  String get label => widget.label;
  VoidCallback? get onPressed => widget.onPressed;
  Color get color => widget.color;
  IconData? get icon => widget.icon;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) {
      if (onPressed != null) setState(() => pressed = true);
    },
    onPointerUp: (_) => setState(() => pressed = false),
    onPointerCancel: (_) => setState(() => pressed = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      transform: Matrix4.translationValues(0, pressed ? 4 : 0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!pressed && onPressed != null)
            const BoxShadow(color: ink, offset: Offset(0, 4)),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: ink,
          disabledBackgroundColor: Colors.grey.shade200,
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.symmetric(
            horizontal: label.isEmpty ? 8 : 16,
            vertical: 12,
          ),
          elevation: 0,
          shadowColor: ink,
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: ink, width: 3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 22),
              if (label.isNotEmpty) const SizedBox(width: 6),
            ],
            if (label.isNotEmpty)
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class IslandPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final VoidCallback? back;
  final Widget? leading;
  final bool centerTitle;
  const IslandPage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.back,
    this.leading,
    this.centerTitle = false,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    body: CustomPaint(
      painter: const PaperDots(),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 32,
                vertical: MediaQuery.sizeOf(context).height < 500 ? 8 : 16,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: ink, width: 3)),
                boxShadow: [BoxShadow(color: ink, offset: Offset(0, 3))],
              ),
              child: centerTitle
                  ? Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ToyButton(
                              '返回大厅',
                              icon: Icons.arrow_back_rounded,
                              color: Colors.white,
                              onPressed: back,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF0FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ink, width: 2),
                          ),
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 6,
                              runSpacing: 4,
                              children: actions,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(width: 20),
                        ] else if (back != null) ...[
                          ToyButton(
                            '返回大厅',
                            icon: Icons.arrow_back_rounded,
                            color: Colors.white,
                            onPressed: back,
                          ),
                          const SizedBox(width: 14),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: sun,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: ink, width: 2),
                            ),
                            child: const Icon(
                              Icons.cottage_rounded,
                              color: ink,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: leading != null
                              ? const SizedBox()
                              : Align(
                                  alignment: back == null
                                      ? Alignment.centerLeft
                                      : Alignment.center,
                                  child: Container(
                                    padding: back == null
                                        ? EdgeInsets.zero
                                        : const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 9,
                                          ),
                                    decoration: back == null
                                        ? null
                                        : BoxDecoration(
                                            color: const Color(0xFFEAF0FF),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: ink,
                                              width: 2,
                                            ),
                                          ),
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: ink,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        ...actions,
                      ],
                    ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  MediaQuery.sizeOf(context).height < 500 ? 12 : 24,
                  24,
                  16,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PaperDots extends CustomPainter {
  const PaperDots();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(cream, BlendMode.src);
    final dot = Paint()..color = const Color(0xFFE8EDF5);
    for (double x = 10; x < size.width; x += 32) {
      for (double y = 12; y < size.height; y += 32) {
        canvas.drawCircle(Offset(x, y), 2, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PaperDots oldDelegate) => false;
}

class Tag extends StatelessWidget {
  final String text;
  final Color color;
  const Tag(this.text, {super.key, this.color = sun});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: ink, width: 2),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: ink,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    ),
  );
}

/// Repo-native illustrated portraits: no external image service or font emoji.
class FamilyPortrait extends StatelessWidget {
  final String? role;
  final double size;
  const FamilyPortrait(this.role, {super.key, this.size = 64});
  @override
  Widget build(BuildContext context) => Semantics(
    label: nameOf(role),
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: role == null
            ? sky.withValues(alpha: .2)
            : gameColors[roles.indexOf(role!)].withValues(alpha: .3),
        shape: BoxShape.circle,
        border: Border.all(color: ink, width: 1.5),
      ),
      child: ClipOval(
        child: role == null
            ? CustomPaint(painter: _PortraitPainter(role))
            : AtlasSprite(
                'assets/images/stitch/family.png',
                index: const {
                  'boy': 0,
                  'girl': 1,
                  'dad': 2,
                  'mom': 3,
                  'grandpa': 4,
                  'grandma': 5,
                }[role]!,
                columns: 3,
                rows: 2,
              ),
      ),
    ),
  );
}

class _PortraitPainter extends CustomPainter {
  final String? role;
  _PortraitPainter(this.role);
  @override
  void paint(Canvas canvas, Size size) {
    final i = role == null ? 6 : roles.indexOf(role!), scale = size.width / 100;
    canvas.scale(scale);
    final fill = Paint(),
        stroke = Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
    void oval(Rect r, Color c) {
      fill.color = c;
      canvas.drawOval(r, fill);
      canvas.drawOval(r, stroke);
    }

    oval(
      const Rect.fromLTWH(2, 2, 96, 96),
      [sky, Color(0xFFFFAAC8), mint, lilac, sun, coral, sky][i],
    );
    if (i == 6) {
      final head = RRect.fromRectAndRadius(
        const Rect.fromLTWH(22, 28, 56, 47),
        const Radius.circular(14),
      );
      canvas.drawRRect(head, fill..color = Colors.white);
      canvas.drawRRect(head, stroke);
      canvas.drawCircle(const Offset(38, 48), 5, fill..color = ink);
      canvas.drawCircle(const Offset(62, 48), 5, fill);
      canvas.drawLine(const Offset(40, 63), const Offset(60, 63), stroke);
      canvas.drawLine(const Offset(50, 15), const Offset(50, 28), stroke);
      return;
    }
    final hair = i >= 4 ? const Color(0xFFF4F0E9) : const Color(0xFF584139);
    if (i == 1 || i == 3 || i == 5) {
      oval(const Rect.fromLTWH(17, 23, 66, 60), hair);
    }
    oval(
      const Rect.fromLTWH(18, 74, 64, 44),
      [coral, lilac, sky, sun, mint, sky][i],
    );
    oval(const Rect.fromLTWH(24, 22, 52, 58), const Color(0xFFFFD8B4));
    final path = Path()
      ..moveTo(24, 42)
      ..cubicTo(19, 12, 76, 9, 76, 42)
      ..lineTo(61, 30)
      ..lineTo(49, 39)
      ..lineTo(38, 31)
      ..close();
    canvas.drawPath(path, fill..color = hair);
    canvas.drawPath(path, stroke);
    canvas.drawCircle(const Offset(39, 51), 2.8, fill..color = ink);
    canvas.drawCircle(const Offset(61, 51), 2.8, fill);
    canvas.drawOval(
      const Rect.fromLTWH(29, 58, 11, 6),
      fill..color = const Color(0xFFFFAE9C),
    );
    canvas.drawOval(const Rect.fromLTWH(60, 58, 11, 6), fill);
    canvas.drawArc(
      const Rect.fromLTWH(42, 56, 16, 13),
      0,
      math.pi,
      false,
      stroke,
    );
    if (i >= 4) {
      canvas.drawCircle(const Offset(39, 51), 8, stroke);
      canvas.drawCircle(const Offset(61, 51), 8, stroke);
      canvas.drawLine(const Offset(47, 51), const Offset(53, 51), stroke);
    }
    if (i == 1) {
      oval(const Rect.fromLTWH(68, 23, 14, 12), coral);
    }
    if (i == 2) {
      canvas.drawPath(
        Path()
          ..moveTo(43, 66)
          ..lineTo(50, 62)
          ..lineTo(57, 66),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_PortraitPainter old) => old.role != role;
}

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String detail, {
  String confirm = '确认',
  String cancel = '取消',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(detail),
        ),
        actions: [
          ToyButton(
            cancel,
            color: Colors.white,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ToyButton(confirm, onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    ) ??
    false;

/// Outlined, tactile icon control shared by the approved top bars.
class ToyIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  const ToyIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.color = Colors.white,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 10),
    child: Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 48,
        height: 48,
        child: ToyButton('', icon: icon, color: color, onPressed: onPressed),
      ),
    ),
  );
}
