import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_rules/puzzle_rules.dart';
import 'package:puzzle_game/v2/storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Session finished(String id, {String role = 'boy', DateTime? end}) {
  final config = GameConfig(game: Game.game2048, players: [role]);
  final initial = Rules.create(config, 12), d = copyJson(initial.data);
  d.addAll({
    'started': true,
    'outcome': 'lost',
    'reason': 'noMoves',
    'highest': 128,
    'score': 1024,
  });
  return Session(
    id: id,
    seed: 12,
    createdAt: DateTime.utc(2026, 10, 4),
    state: RuleState(config, d, initial.rng, 10),
    durationMs: 12000,
    endedAt: end ?? DateTime.parse('2026-10-04T15:59:59Z'),
  );
}

void main() {
  sqfliteFfiInit();
  late GameStore store;
  setUp(() async {
    store = await GameStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });
  tearDown(() async {
    await store.close();
  });
  test(
    'atomic settlement is idempotent and deletes only active snapshot',
    () async {
      final s = finished('one');
      await store.save(s);
      final a = await store.settle(s), b = await store.settle(s);
      expect(a, b);
      expect(await store.active(), isEmpty);
      final ledger = await store.db.query('reward_entries_v2');
      expect(ledger.length, 1);
      expect(ledger.single['points'], 10);
      expect((await store.familyRanking()).first['points'], 10);
      expect((await store.records()).single['metrics']['score'], 1024);
    },
  );
  test(
    'settled session cannot be overwritten with a different result',
    () async {
      final s = finished('one');
      await store.save(s);
      await store.settle(s);
      s.durationMs++;
      await expectLater(store.settle(s), throwsStateError);
      await expectLater(store.save(s), throwsStateError);
    },
  );
  test(
    'failure after participant write rolls whole transaction back, retry works',
    () async {
      final s = finished('rollback');
      await store.save(s);
      await store.db.execute(
        "CREATE TRIGGER reject_reward BEFORE INSERT ON reward_entries_v2 BEGIN SELECT RAISE(ABORT,'test disk failure'); END",
      );
      await expectLater(store.settle(s), throwsA(isA<DatabaseException>()));
      expect(await store.db.query('participant_results_v2'), isEmpty);
      expect(await store.db.query('reward_entries_v2'), isEmpty);
      expect((await store.active()).length, 1);
      await store.db.execute('DROP TRIGGER reject_reward');
      await store.settle(s);
      expect((await store.familyRanking()).first['points'], 10);
    },
  );
  test(
    'snapshots retain exact random, revision, role and pending terminal time',
    () async {
      final s = finished('restore', role: 'mom');
      await store.save(s);
      final copy = (await store.active()).values.single;
      expect(jsonEncode(copy.toJson()), jsonEncode(s.toJson()));
      await store.settle(copy);
      final week = await store.familyRanking(week: '2026-09-28');
      expect(week.first['player'], 'mom');
      expect(week.first['points'], 10);
      expect(
        (await store.familyRanking(
          week: '2026-10-05',
        )).every((r) => r['points'] == 0),
        true,
      );
    },
  );
  test('all six roles visible and competition ties skip places', () async {
    for (final role in ['boy', 'girl']) {
      final s = finished(role, role: role);
      await store.save(s);
      await store.settle(s);
    }
    final rows = await store.familyRanking();
    expect(rows.length, 6);
    expect(rows.map((r) => r['rank']), [1, 1, 3, 3, 3, 3]);
  });
  test('only one active save per game and stale revision rejected', () async {
    final a = finished('a');
    await store.save(a);
    await expectLater(
      store.save(finished('b')),
      throwsA(isA<DatabaseException>()),
    );
    a.state = RuleState(a.state.config, copyJson(a.state.data), a.state.rng, 9);
    await expectLater(store.save(a), throwsStateError);
  });
  test('legacy upgrade preserves old rows and isolates dad/mom totals', () async {
    final dir = await Directory.systemTemp.createTemp('puzzle-migration-');
    final path = '${dir.path}/legacy.db';
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE players(avatar TEXT PRIMARY KEY,name TEXT,total_score INTEGER)',
          );
          await db.execute(
            'CREATE TABLE game_records(id INTEGER PRIMARY KEY,avatar TEXT,game_type TEXT,score INTEGER,duration INTEGER,is_win INTEGER,played_at TEXT)',
          );
          await db.insert('players', {
            'avatar': 'dad',
            'name': '爸爸',
            'total_score': 999,
          });
          await db.insert('players', {
            'avatar': 'mom',
            'name': '妈妈',
            'total_score': 123,
          });
          await db.insert('game_records', {
            'id': 1,
            'avatar': 'dad',
            'game_type': 'sudoku',
            'score': 88,
            'duration': 88,
            'is_win': 1,
            'played_at': '2026-01-01',
          });
        },
      ),
    );
    await legacy.close();
    final migrated = await GameStore.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    expect(await migrated.legacyScores(), {'dad': 999, 'mom': 123});
    expect(
      (await migrated.familyRanking()).every((r) => r['points'] == 0),
      true,
    );
    expect((await migrated.legacyRecords('dad')).single['score'], 88);
    expect(await File('$path.pre-v4').exists(), true);
    await migrated.close();
    final reopened = await GameStore.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    expect(await reopened.legacyScores(), {'dad': 999, 'mom': 123});
    await reopened.close();
    await dir.delete(recursive: true);
  });
}
