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
    testWidgets(
      '${game.name} paused header returns home and preserves resumable save',
      (tester) async {
        sqfliteFfiInit();
        tester.view.physicalSize = const Size(1280, 800);
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
          players: game == Game.gobang
              ? ['boy', 'girl']
              : game == Game.flying
              ? ['boy', 'girl', 'dad', 'mom']
              : ['boy'],
        );
        final session = Session(
          id: game.name,
          seed: 42,
          createdAt: DateTime.utc(2026),
          durationMs: 13000,
          state: Rules.create(config, 42),
        );
        await tester.runAsync(() => store.save(session));
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            theme: islandTheme(),
            home: const Scaffold(body: Text('大厅测试页')),
          ),
        );
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                PlayPage(model: model, session: session, resumed: true),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('休息一下'), findsNothing);
        await tester.tap(find.byTooltip('暂停'));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(find.text('休息一下'), findsOneWidget);
        await tester.tap(find.text('返回大厅'));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(find.byType(PlayPage), findsNothing);
        expect(find.text('大厅测试页'), findsOneWidget);
        final restored = (await tester.runAsync(store.active))![game]!;
        expect(restored.id, session.id);
        expect(restored.durationMs, 13000);
        expect(restored.state.toJson(), session.state.toJson());
        expect(restored.state.terminal, isFalse);
        final controller = PlayController(model, restored, resumed: true);
        expect(controller.paused, isTrue);
        controller.dispose();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        model.dispose();
        await tester.runAsync(store.close);
      },
    );
  }
}
