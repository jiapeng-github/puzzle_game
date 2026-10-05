import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/v2/controller.dart';
import 'package:puzzle_game/v2/storage.dart';
import 'package:puzzle_game/v2/sound.dart';
import 'fake_audio.dart';
import 'package:puzzle_rules/puzzle_rules.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ManualClock implements ActiveClock {
  int elapsed = 0;
  bool running = false;
  void advance(int ms) {
    if (running) elapsed += ms;
  }

  @override
  int get elapsedMilliseconds => elapsed;
  @override
  bool get isRunning => running;
  @override
  void start() => running = true;
  @override
  void stop() => running = false;
}

void main() {
  sqfliteFfiInit();
  late GameStore store;
  late IslandModel model;
  late FakeChannel music, effect;
  late List<String> audioLog;
  setUp(() async {
    store = await GameStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    audioLog = [];
    music = FakeChannel('music', audioLog);
    effect = FakeChannel('effect', audioLog);
    model = IslandModel(
      store: store,
      sound: Sound(music: music, effect: effect),
    );
    await model.load();
  });
  tearDown(() async {
    model.dispose();
    await model.sound.idle;
    await store.close();
  });
  test(
    'ready time excluded; pause saves exact remaining observation; restore stays paused',
    () async {
      final session = Session(
        id: 'memory',
        seed: 17,
        createdAt: DateTime.utc(2026),
        state: Rules.create(GameConfig(game: Game.memory), 17),
      );
      await store.save(session);
      final clock = ManualClock();
      final play = PlayController(model, session, clock: clock);
      clock.advance(5000);
      expect(clock.elapsedMilliseconds, 0);
      final b = ints(session.state.data['board']),
          other = b.indexWhere((v) => v != b[0]);
      await play.command('flip', {'index': 0});
      clock.advance(1200);
      await play.command('flip', {'index': other});
      clock.advance(350);
      await play.pause();
      expect(session.durationMs, 1550);
      expect(session.state.data['remainingMs'], 450);
      clock.advance(99999);
      expect(session.durationMs, 1550);
      final restored = (await store.active()).values.single;
      play.dispose();
      final nextClock = ManualClock();
      final continuing = PlayController(
        model,
        restored,
        resumed: true,
        clock: nextClock,
      );
      await continuing.resume();
      nextClock.advance(449);
      await continuing.pause();
      expect(restored.state.data['remainingMs'], 1);
      await continuing.resume();
      nextClock.advance(1);
      await continuing.pause();
      expect(restored.state.data['open'], isEmpty);
      expect(restored.durationMs, 2000);
      continuing.dispose();
    },
  );
  test(
    'terminal persistence failure retries frozen result and role only once',
    () async {
      var state = Rules.create(
        GameConfig(game: Game.memory, pairs: 6, players: ['mom']),
        9,
      );
      // Play all except the last pair through rules to obtain a real terminal edge.
      final board = ints(state.data['board']);
      for (var value = 0; value < 5; value++) {
        for (var i = 0; i < 12; i++) {
          if (board[i] == value) {
            state = Rules.apply(state, 'flip', {
              'index': i,
            }, revision: state.revision).state;
          }
        }
      }
      final last = [
        for (var i = 0; i < 12; i++)
          if (board[i] == 5) i,
      ];
      final session = Session(
        id: 'end',
        seed: 9,
        createdAt: DateTime.utc(2026),
        state: state,
      );
      await store.save(session);
      final c = PlayController(model, session, clock: ManualClock());
      model.sound.game(Game.memory);
      await model.sound.idle;
      await c.command('flip', {'index': last[0]});
      await store.db.execute(
        "CREATE TRIGGER fail_final BEFORE INSERT ON reward_entries_v2 BEGIN SELECT RAISE(ABORT,'full'); END",
      );
      await c.command('flip', {'index': last[1]});
      await model.sound.idle;
      expect(music.playing, isNull);
      expect(effect.playing, isNull);
      expect(c.saved, false);
      expect(c.error, isNotNull);
      final ended = session.endedAt;
      model.role = 'boy';
      await store.db.execute('DROP TRIGGER fail_final');
      await c.retry();
      await model.sound.idle;
      expect(music.playing, isNull);
      expect(effect.playing, 'audio/sfx/winning.mp3');
      expect(c.saved, true);
      expect(session.endedAt, ended);
      await c.retry();
      await model.sound.idle;
      expect(
        audioLog.where((x) => x == 'effect:play:audio/sfx/winning.mp3').length,
        1,
      );
      final entries = await store.db.query('reward_entries_v2');
      expect(entries.length, 1);
      expect(entries.single['player_id'], 'mom');
      expect(entries.single['points'], 15);
      c.dispose();
    },
  );
  test('restored computer win stops music without human victory cue', () async {
    var state = Rules.create(
      GameConfig(game: Game.gobang, mode: 'ai', players: ['boy', null]),
      2,
    );
    for (final index in [0, 15, 1, 16, 2, 17, 3, 18, 30, 19]) {
      state = Rules.apply(state, 'place', {
        'index': index,
        'color': state.data['turn'],
      }, revision: state.revision).state;
    }
    expect(state.terminal, isTrue);
    expect(state.data['winner'], 2);
    final session = Session(
      id: 'computer-win',
      endedAt: DateTime.utc(2026, 1, 1, 0, 1),
      seed: 2,
      createdAt: DateTime.utc(2026),
      state: state,
    );
    await store.save(session);
    model.sound.game(Game.gobang);
    await model.sound.idle;
    final c = PlayController(model, session);
    await c.settle();
    await model.sound.idle;
    expect(c.saved, isTrue);
    expect(music.playing, isNull);
    expect(effect.playing, isNull);
    c.dispose();
  });
  test('disposed controller rejects stale callbacks', () async {
    final session = Session(
      id: 'stale',
      seed: 2,
      createdAt: DateTime.utc(2026),
      state: Rules.create(GameConfig(game: Game.memory), 2),
    );
    await store.save(session);
    final c = PlayController(model, session);
    c.dispose();
    await c.command('flip', {'index': 0});
    expect(session.state.started, false);
  });
  test(
    'AI starts as black after rematch; paused hint reply is discarded',
    () async {
      final state = Rules.create(
        GameConfig(
          game: Game.gobang,
          mode: 'ai',
          humanColor: 2,
          players: [null, 'boy'],
        ),
        7,
      );
      final session = Session(
        id: 'ai',
        seed: 7,
        createdAt: DateTime.utc(2026),
        state: state,
      );
      await store.save(session);
      final c = PlayController(model, session);
      for (var i = 0; i < 100 && c.state.revision == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(c.state.data['board'][112], 1);
      expect(c.state.data['turn'], 2);
      while (c.busy) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final pending = c.hintGobang();
      await c.pause();
      await pending;
      expect(c.state.assisted, false);
      expect(c.paused, true);
      c.dispose();
    },
  );
}
