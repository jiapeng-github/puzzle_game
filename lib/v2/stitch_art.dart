import 'package:flutter/material.dart';

/// An atlas is kept intact; cells are selected at render time.
class AtlasSprite extends StatelessWidget {
  final String asset;
  final int index, columns, rows;
  const AtlasSprite(
    this.asset, {
    super.key,
    required this.index,
    required this.columns,
    required this.rows,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (_, box) {
          final alignment = Alignment(
            columns == 1 ? 0 : -1 + 2 * (index % columns) / (columns - 1),
            rows == 1 ? 0 : -1 + 2 * (index ~/ columns) / (rows - 1),
          );
          return ClipRect(
            child: OverflowBox(
              alignment: alignment,
              minWidth: box.maxWidth * columns,
              maxWidth: box.maxWidth * columns,
              minHeight: box.maxHeight * rows,
              maxHeight: box.maxHeight * rows,
              child: Image.asset(
                asset,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// Hand-tuned bounds keep the generated sticker silhouettes intact.
class MemoryCardArt extends StatelessWidget {
  final String theme;
  final int index;
  const MemoryCardArt({super.key, required this.theme, required this.index});

  static const _traffic = <Rect>[
    Rect.fromLTRB(0, 60, 374, 390),
    Rect.fromLTRB(365, 70, 724, 380),
    Rect.fromLTRB(730, 0, 1074, 390),
    Rect.fromLTRB(1080, 20, 1448, 388),
    Rect.fromLTRB(0, 394, 355, 704),
    Rect.fromLTRB(365, 393, 740, 698),
    Rect.fromLTRB(744, 390, 1064, 710),
    Rect.fromLTRB(1072, 392, 1448, 705),
    Rect.fromLTRB(0, 704, 366, 1086),
    Rect.fromLTRB(376, 698, 710, 1086),
    Rect.fromLTRB(724, 706, 1070, 1086),
    Rect.fromLTRB(1080, 714, 1448, 1086),
  ];

  @override
  Widget build(BuildContext context) {
    if (theme != 'traffic' && theme != 'sports') {
      return SizedBox.square(
        dimension: 48,
        child: AtlasSprite(
          'assets/images/stitch/${theme == 'fruit' ? 'fruits' : 'animals'}.png',
          index: index,
          columns: 4,
          rows: 3,
        ),
      );
    }
    final row = index ~/ 4;
    final rect = theme == 'traffic'
        ? _traffic[index]
        : Rect.fromLTRB(
            (index % 4) * 362,
            [0.0, 358.0, 697.0][row],
            (index % 4 + 1) * 362,
            [358.0, 697.0, 1086.0][row],
          );
    return Center(
      child: AspectRatio(
        aspectRatio: rect.width / rect.height,
        child: LayoutBuilder(
          builder: (context, box) {
            final scale = box.maxWidth / rect.width;
            return ClipRect(
              child: Stack(
                children: [
                  Positioned(
                    left: -rect.left * scale,
                    top: -rect.top * scale,
                    width: 1448 * scale,
                    height: 1086 * scale,
                    child: Image.asset(
                      'assets/images/stitch/$theme.png',
                      fit: BoxFit.fill,
                      excludeFromSemantics: true,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
