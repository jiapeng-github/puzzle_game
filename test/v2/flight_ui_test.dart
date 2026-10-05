import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/v2/flight.dart';
import 'package:puzzle_game/v2/controller.dart';
import 'package:puzzle_game/v2/design.dart';
import 'package:puzzle_game/v2/play.dart';
import 'package:puzzle_game/v2/storage.dart';
import 'package:puzzle_rules/puzzle_rules.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'rectangular board has 48 unique outer and 24 distinct home centers',
    () {
      for (final size in [const Size(1226, 598), const Size(906, 262)]) {
        final g = FlightGeometry(size);
        final ring = List.generate(48, g.outer);
        expect(ring.toSet().length, 48);
        expect(ring.every((p) => (Offset.zero & size).contains(p)), true);
        final homes = [
          for (var t = 0; t < 4; t++)
            for (var p = 49; p <= 54; p++) g.home(t, p),
        ];
        expect(homes.toSet().length, 24);
        expect(homes.every((p) => (Offset.zero & size).contains(p)), true);
        for (var t = 0; t < 4; t++) {
          for (var i = 0; i < 4; i++) {
            expect(g.base(t).contains(g.plane(t, i, -1)), true);
            expect(g.slot(t, i).width, closeTo(g.slot(t, i).height, .0001));
            expect(g.plane(t, i, -1), g.slot(t, i).center);
          }
        }
      }
    },
  );
  for (final viaBoard in [true, false]) {
    testWidgets(
      'adventure ${viaBoard ? 'board' : 'number'} tap moves and persists same plane on large-text phone',
      (tester) async {
        sqfliteFfiInit();
        tester.view.physicalSize = const Size(960, 432);
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
        final initial = Rules.create(
          GameConfig(
            game: Game.flying,
            mode: 'adventure',
            players: ['boy', 'girl', 'dad', 'mom'],
          ),
          42,
        );
        final d = copyJson(initial.data)
          ..addAll({'turn': 0, 'dice': 6, 'rollId': 1, 'started': true});
        d['shields'][0][0] = 1;
        d['flightEvents'] = [
          for (var i = 0; i < 4; i++)
            {'kind': 'collisionBlocked', 'seat': 1, 'plane': i},
        ];
        final session = Session(
          id: 'flight-ui',
          seed: 42,
          createdAt: DateTime.utc(2026),
          state: RuleState(initial.config, d, initial.rng),
        );
        await tester.runAsync(() => store.save(session));
        await tester.pumpWidget(
          MaterialApp(
            theme: islandTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.4)),
              child: child!,
            ),
            home: PlayPage(model: model, session: session),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final bounds = tester.getRect(find.byType(FlightBoard));
        expect(bounds.width, greaterThan(900));
        expect(bounds.height, greaterThan(260));
        if (viaBoard) {
          await tester.tap(find.byKey(const ValueKey('plane-0-0')));
        } else {
          await tester.tap(find.byTooltip('1号飞机'));
        }
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump(const Duration(milliseconds: 250));
        expect(session.state.data['planes'][0][0], 0);
        expect(session.state.data['shields'][0][0], 1);
        final saved = (await tester.runAsync(store.active))![Game.flying]!;
        expect(saved.state.config.mode, 'adventure');
        expect(saved.state.data['planes'][0][0], 0);
        expect(saved.state.data['shields'][0][0], 1);
        await tester.tap(find.byTooltip('规则说明'));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(find.byType(FlightRulesDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        model.dispose();
        await tester.runAsync(store.close);
      },
    );
  }
}
