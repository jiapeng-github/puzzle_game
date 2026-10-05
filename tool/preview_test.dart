// Manual visual capture: flutter test tool/preview_test.dart
// --dart-define=PREVIEW_FONT=/path/to/a/local/Chinese/font.ttf
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/v2/app.dart';
import 'package:puzzle_game/v2/controller.dart';
import 'package:puzzle_game/v2/design.dart';
import 'package:puzzle_game/v2/play.dart';
import 'package:puzzle_game/v2/records.dart';
import 'package:puzzle_game/v2/flight.dart';
import 'package:puzzle_game/v2/storage.dart';
import 'package:puzzle_rules/puzzle_rules.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('render actual Flutter V2 screens for visual review', (
    tester,
  ) async {
    sqfliteFfiInit();
    tester.view.devicePixelRatio = 1;
    await tester.runAsync(() async {
      for (final font in {
        'Noto Sans SC': 'NotoSansSC',
        'Rubik': 'Rubik',
        'Plus Jakarta Sans': 'PlusJakartaSans',
        'sans-serif': 'NotoSansSC',
      }.entries) {
        final loader = FontLoader(font.key)
          ..addFont(rootBundle.load('assets/fonts/${font.value}[wght].ttf'));
        await loader.load();
      }
    });
    await tester.runAsync(() async {
      final loader = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await loader.load();
    });
    final store = (await tester.runAsync(
      () => GameStore.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      ),
    ))!;
    final model = IslandModel(store: store, audioEnabled: false);
    await tester.runAsync(model.load);
    final captureTheme = islandTheme();
    final dir = Directory('docs/previews');
    await tester.runAsync(() => dir.create(recursive: true));
    Future<void> capture(String name, Widget screen, Size size) async {
      tester.view.physicalSize = size;
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: captureTheme,
            home: screen,
          ),
        ),
      );
      await tester.runAsync(() async {
        for (final asset in ['family', 'animals', 'fruits']) {
          await precacheImage(
            AssetImage('assets/images/stitch/$asset.png'),
            key.currentContext!,
          );
        }
      });
      await tester.pump(const Duration(milliseconds: 100));
      if (name == 'result') {
        for (var attempt = 0; attempt < 40; attempt++) {
          if (find.textContaining('正在保存').evaluate().isEmpty) break;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        expect(find.textContaining('正在保存'), findsNothing);
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${dir.path}/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }

    await capture('home', HomePage(model: model), const Size(1280, 800));
    for (final game in Game.values) {
      final config = GameConfig(
        game: game,
        mode: game == Game.gobang ? 'local' : 'standard',
        players: game == Game.flying
            ? ['boy', 'girl', 'dad', 'mom']
            : game == Game.gobang
            ? ['boy', 'girl']
            : ['boy'],
      );
      final session = Session(
        id: 'preview-${game.name}',
        seed: 42,
        createdAt: DateTime.utc(2026),
        state: Rules.create(config, 42),
      );
      await tester.runAsync(() => store.save(session));
      await capture(
        game.name,
        PlayPage(model: model, session: session),
        game == Game.sudoku ? const Size(960, 432) : const Size(1280, 800),
      );
    }
    // Deterministic presentation fixture: never loaded by the production app.
    final flightSeed = Rules.create(
      GameConfig(
        game: Game.flying,
        mode: 'adventure',
        players: ['boy', 'girl', 'dad', 'mom'],
      ),
      42,
    );
    final flightData = copyJson(flightSeed.data);
    flightData.addAll({
      'turn': 0,
      'dice': 4,
      'rollId': 8,
      'rolls': 14,
      'started': true,
      'planes': [
        [0, 17, -1, -1],
        [10, -1, -1, -1],
        [8, 21, -1, -1],
        [-1, -1, -1, -1],
      ],
      'shields': [
        [0, 1, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ],
      'flightEvents': [
        {'kind': 'shield', 'seat': 0, 'plane': 1},
      ],
    });
    final classicSave = (await tester.runAsync(store.active))?[Game.flying];
    if (classicSave != null) {
      await tester.runAsync(() => model.abandon(classicSave));
    }
    final adventure = Session(
      id: 'preview-adventure',
      seed: 42,
      createdAt: DateTime.utc(2026),
      state: RuleState(flightSeed.config, flightData, flightSeed.rng),
    );
    await tester.runAsync(() => store.save(adventure));
    await capture(
      'flying_adventure',
      PlayPage(model: model, session: adventure),
      const Size(1280, 800),
    );
    await capture(
      'flying_adventure_phone',
      PlayPage(model: model, session: adventure),
      const Size(960, 432),
    );
    await capture(
      'flying_rules',
      const Scaffold(body: FlightRulesDialog(adventure: true)),
      const Size(1280, 800),
    );
    await tester.runAsync(model.refresh);
    await capture('home_resume', HomePage(model: model), const Size(1280, 800));
    for (final game in Game.values) {
      await capture(
        'setup_${game.name}',
        SetupDialog(game: game, role: 'boy'),
        const Size(1280, 800),
      );
    }
    await capture(
      'settings',
      SettingsDialog(model: model),
      const Size(1280, 800),
    );
    await capture(
      'profile',
      ProfilePage(model: model, role: 'boy'),
      const Size(1280, 800),
    );
    final paused = Session(
      id: 'preview-pause',
      seed: 1,
      createdAt: DateTime.utc(2026),
      durationMs: 272000,
      state: Rules.create(GameConfig(game: Game.memory, players: ['boy']), 1),
    );
    final memorySave = (await tester.runAsync(store.active))?[Game.memory];
    if (memorySave != null) {
      await tester.runAsync(() => model.abandon(memorySave));
    }
    await tester.runAsync(() => store.save(paused));
    await capture(
      'pause',
      PlayPage(model: model, session: paused, resumed: true),
      const Size(1280, 800),
    );
    await tester.runAsync(() => model.abandon(paused));
    var won = Rules.create(GameConfig(game: Game.memory, players: ['boy']), 4);
    for (var value = 0; value < 8; value++) {
      final indexes = [
        for (var i = 0; i < 16; i++)
          if (won.data['board'][i] == value) i,
      ];
      for (final index in indexes) {
        won = Rules.apply(won, 'flip', {
          'index': index,
        }, revision: won.revision).state;
      }
    }
    final finished = Session(
      id: 'preview-result',
      seed: 4,
      createdAt: DateTime.utc(2026),
      state: won,
      durationMs: 124000,
      endedAt: DateTime.utc(2026, 10, 3),
    );
    await tester.runAsync(() => store.save(finished));
    await capture(
      'result',
      PlayPage(model: model, session: finished),
      const Size(1280, 800),
    );
    await capture(
      'leaderboard',
      RecordsPage(model: model),
      const Size(1280, 800),
    );
    model.dispose();
    await tester.runAsync(store.close);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
