import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/v2/controller.dart';
import 'package:puzzle_game/v2/design.dart';
import 'package:puzzle_game/v2/play.dart';
import 'package:puzzle_game/v2/storage.dart';
import 'package:puzzle_rules/puzzle_rules.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  for (final game in Game.values) {
    for (final failed in [false, true]) {
      testWidgets(
        '${game.name} ${failed ? 'failed' : 'saved'} result fits landscape with visible actions',
        (tester) async {
          sqfliteFfiInit();
          final size = failed ? const Size(960, 432) : const Size(1280, 800);
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final store = (await tester.runAsync(
            () => GameStore.open(
              factory: databaseFactoryFfi,
              path: inMemoryDatabasePath,
            ),
          ))!;
          final model = IslandModel(store: store, audioEnabled: false);
          await tester.runAsync(model.load);
          final config = GameConfig(
            game: game,
            mode: game == Game.gobang ? 'local' : 'standard',
            players: game == Game.flying
                ? ['boy', null, null, null]
                : game == Game.gobang
                ? ['boy', 'girl']
                : ['boy'],
          );
          final initial = Rules.create(config, 42);
          final session = Session(
            id: 'layout',
            seed: 42,
            createdAt: DateTime.utc(2026),
            endedAt: DateTime.utc(2026, 1, 1, 0, 1),
            state: Rules.apply(
              initial,
              'abandon',
              {},
              revision: initial.revision,
            ).state,
          );
          await tester.runAsync(() => store.save(session));
          if (failed) {
            // Preserve the real conflict protection and exercise its long error UI.
            await tester.runAsync(
              () => store.db.update('game_sessions_v2', {'revision': 99}),
            );
          }
          await tester.pumpWidget(
            MaterialApp(
              theme: islandTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(failed ? 1.4 : 1),
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                ),
                child: child!,
              ),
              home: PlayPage(model: model, session: session),
            ),
          );
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final card = tester.getRect(
            find.byKey(const ValueKey('game-overlay-card')),
          );
          expect(card.top, greaterThanOrEqualTo(24));
          expect(card.bottom, lessThanOrEqualTo(size.height - 24));
          for (final label in ['再来一局', '返回大厅', '查看纪录', if (failed) '重新保存']) {
            final rect = tester.getRect(
              find.descendant(
                of: find.byKey(const ValueKey('game-overlay-card')),
                matching: find.text(label),
              ),
            );
            expect(rect.top, greaterThanOrEqualTo(card.top));
            expect(rect.bottom, lessThan(card.bottom));
          }
          final scroll = find.byKey(const ValueKey('game-overlay-scroll'));
          await tester.drag(scroll, const Offset(0, -1200));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (failed) expect(find.textContaining('结算版本冲突'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          model.dispose();
          await tester.runAsync(store.close);
        },
      );
    }
  }
}
