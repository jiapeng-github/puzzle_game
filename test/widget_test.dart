import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/v2/controller.dart';
import 'package:puzzle_game/v2/app.dart';
import 'package:puzzle_game/v2/design.dart';
import 'package:puzzle_game/v2/play.dart';
import 'package:puzzle_game/v2/storage.dart';
import 'package:puzzle_rules/puzzle_rules.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  testWidgets('landscape home renders six games and local family role', (
    tester,
  ) async {
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
    await tester.pumpWidget(PuzzleApp(store: store, audioEnabled: false));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('趣玩小岛'), findsOneWidget);
    for (final name in gameNames) {
      expect(find.text(name), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(store.close);
  });
  for (final game in Game.values) {
    testWidgets('${game.name} small landscape board and opaque pause', (
      tester,
    ) async {
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
        state: Rules.create(config, 42),
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
      if (game == Game.match3) {
        final hint = find.text('提示（3）');
        final restart = find.text('重新开始');
        expect(hint.hitTestable(), findsOneWidget);
        expect(restart.hitTestable(), findsOneWidget);
        final hintPosition = tester.getCenter(hint);
        final rules = find.byKey(const ValueKey('match-rules-scroll'));
        await tester.drag(rules, const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(tester.getCenter(hint), hintPosition);
        expect(restart.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      if (game == Game.memory) {
        final restart = find.text('重新开始本局');
        expect(restart.hitTestable(), findsOneWidget);
        expect(find.text('返回主菜单'), findsNothing);
        final position = tester.getCenter(restart);
        await tester.drag(
          find.byKey(const ValueKey('memory-tips-scroll')),
          const Offset(0, -250),
        );
        await tester.pumpAndSettle();
        expect(tester.getCenter(restart), position);
        expect(restart.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      if (game == Game.gobang) {
        expect(find.text('规则').hitTestable(), findsOneWidget);
        expect(find.text('悔棋').hitTestable(), findsOneWidget);
        expect(find.text('暂停并保存'), findsNothing);
        await tester.tap(find.text('规则'));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(find.text('五子棋 · 玩法说明'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, '继续游戏'));
        await tester.pumpAndSettle();
        expect(find.text('休息一下'), findsNothing);
      }
      await tester.tap(find.byTooltip('暂停'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(find.text('休息一下'), findsOneWidget);
      expect(find.textContaining('盘面已隐藏'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
      await tester.runAsync(store.close);
    });
  }
  for (final game in Game.values) {
    testWidgets('${game.name} setup fits short landscape with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(960, 432);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: islandTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: Scaffold(
            body: SetupDialog(game: game, role: 'boy'),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text(game == Game.flying ? '起飞吧！开始冒险' : '开始游戏'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final size in [const Size(1280, 800), const Size(960, 432)]) {
    testWidgets('memory setup all previews and rewards visible at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: islandTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: const SetupDialog(game: Game.memory, role: 'boy'),
        ),
      );
      for (final pairs in [6, 8, 12]) {
        await tester.tap(find.byKey(ValueKey('memory-pairs-$pairs')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final preview = tester.getRect(
          find.byKey(const ValueKey('memory-setup-preview')),
        );
        final last = tester.getRect(
          find.byKey(ValueKey('memory-preview-card-${pairs * 2 - 1}')),
        );
        expect(last.bottom, lessThanOrEqualTo(preview.bottom + .1));
        expect(last.top, greaterThanOrEqualTo(preview.top));
        expect(
          find
              .byKey(ValueKey('memory-preview-card-${pairs * 2 - 1}'))
              .hitTestable(),
          findsOneWidget,
        );
        final reward = tester.getRect(
          find.byKey(const ValueKey('memory-setup-rewards')),
        );
        final start = tester.getRect(find.text('开始游戏'));
        expect(reward.bottom, lessThan(start.top));
        expect(find.text('计分说明').hitTestable(), findsOneWidget);
        expect(find.text('开始游戏').hitTestable(), findsOneWidget);
      }
    });
  }
  for (final pairs in [6, 12]) {
    testWidgets('memory $pairs pairs fit without clipped last row', (
      tester,
    ) async {
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
      final session = Session(
        id: 'pairs$pairs',
        seed: 4,
        createdAt: DateTime.utc(2026),
        state: Rules.create(GameConfig(game: Game.memory, pairs: pairs), 4),
      );
      await tester.runAsync(() => store.save(session));
      await tester.pumpWidget(
        MaterialApp(
          theme: islandTheme(),
          home: PlayPage(model: model, session: session),
        ),
      );
      await tester.pump();
      final scroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scroll.position.maxScrollExtent, closeTo(0, .01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
      await tester.runAsync(store.close);
    });
  }
}
