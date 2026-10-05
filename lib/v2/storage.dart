import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:puzzle_rules/puzzle_rules.dart';
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class Session {
  final String id;
  final int seed;
  final DateTime createdAt;
  RuleState state;
  int durationMs;
  DateTime? endedAt;
  Session({
    required this.id,
    required this.seed,
    required this.createdAt,
    required this.state,
    this.durationMs = 0,
    this.endedAt,
  });
  Json toJson() => {
    'id': id,
    'seed': seed,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'state': state.toJson(),
    'durationMs': durationMs,
    'endedAt': endedAt?.toUtc().toIso8601String(),
  };
  factory Session.fromJson(Json j) => Session(
    id: j['id'],
    seed: j['seed'],
    createdAt: DateTime.parse(j['createdAt']),
    state: RuleState.fromJson(j['state']),
    durationMs: j['durationMs'],
    endedAt: j['endedAt'] == null ? null : DateTime.parse(j['endedAt']),
  );
}

class GameStore {
  final Database db;
  GameStore(this.db);
  static Future<GameStore> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    if (factory == null) {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        factory = databaseFactoryFfi;
      } else {
        factory = mobile.databaseFactorySqflitePlugin;
      }
    }
    final file =
        path ?? p.join(await factory.getDatabasesPath(), 'puzzle_game_v2.db');
    if (file != inMemoryDatabasePath &&
        await File(file).exists() &&
        !await File('$file.pre-v4').exists()) {
      // Copy the old database and its WAL before opening/upgrading it.
      for (final suffix in ['', '-wal', '-shm']) {
        final source = File('$file$suffix');
        if (await source.exists()) await source.copy('$file.pre-v4$suffix');
      }
    }
    final db = await factory.openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: 4,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: (db, _) => _migrate(db),
        onUpgrade: (db, old, _) async {
          if (old < 4) await _migrate(db);
        },
      ),
    );
    return GameStore(db);
  }

  static Future<void> _migrate(Database db) async {
    await db.execute(
      'CREATE TABLE family_roles_v2(player_id TEXT PRIMARY KEY,name TEXT NOT NULL)',
    );
    for (var i = 0; i < roles.length; i++) {
      await db.insert('family_roles_v2', {
        'player_id': roles[i],
        'name': roleNames[i],
      });
    }
    await db.execute(
      '''CREATE TABLE game_sessions_v2(
      session_id TEXT PRIMARY KEY,game_type TEXT NOT NULL,config_json TEXT NOT NULL,
      ruleset_id TEXT NOT NULL,reward_policy_id TEXT NOT NULL,rng_seed INTEGER NOT NULL,
      status TEXT NOT NULL CHECK(status IN ('active','settled')),revision INTEGER NOT NULL,
      started_at_utc TEXT NOT NULL,ended_at_utc TEXT,active_duration_ms INTEGER NOT NULL CHECK(active_duration_ms>=0),result_digest TEXT)''',
    );
    await db.execute(
      "CREATE UNIQUE INDEX one_active_game_v2 ON game_sessions_v2(game_type) WHERE status='active'",
    );
    await db.execute(
      '''CREATE TABLE session_participants_v2(
      session_id TEXT NOT NULL REFERENCES game_sessions_v2(session_id),seat INTEGER NOT NULL,
      player_id TEXT REFERENCES family_roles_v2(player_id),is_ai INTEGER NOT NULL CHECK(is_ai IN (0,1)),
      PRIMARY KEY(session_id,seat),UNIQUE(session_id,player_id),
      CHECK((is_ai=1 AND player_id IS NULL) OR (is_ai=0 AND player_id IS NOT NULL)))''',
    );
    await db.execute(
      '''CREATE TABLE game_snapshots_v2(
      session_id TEXT PRIMARY KEY REFERENCES game_sessions_v2(session_id),snapshot_version INTEGER NOT NULL,
      revision INTEGER NOT NULL,payload_json TEXT NOT NULL,saved_at_utc TEXT NOT NULL)''',
    );
    await db.execute(
      '''CREATE TABLE participant_results_v2(
      session_id TEXT NOT NULL,seat INTEGER NOT NULL,player_id TEXT REFERENCES family_roles_v2(player_id),
      outcome TEXT NOT NULL CHECK(outcome IN ('won','lost','draw','abandoned')),
      record_eligible INTEGER NOT NULL CHECK(record_eligible IN (0,1)),result_json TEXT NOT NULL,
      PRIMARY KEY(session_id,seat),FOREIGN KEY(session_id,seat) REFERENCES session_participants_v2(session_id,seat))''',
    );
    await db.execute('''CREATE TABLE reward_entries_v2(
      session_id TEXT NOT NULL REFERENCES game_sessions_v2(session_id),player_id TEXT NOT NULL REFERENCES family_roles_v2(player_id),
      points INTEGER NOT NULL CHECK(points BETWEEN 0 AND 60),policy_id TEXT NOT NULL,
      breakdown_json TEXT NOT NULL,earned_at_utc TEXT NOT NULL,week_key TEXT NOT NULL,
      PRIMARY KEY(session_id,player_id))''');
    await db.execute(
      'CREATE INDEX reward_week_v2 ON reward_entries_v2(week_key,player_id)',
    );
    await db.execute(
      'CREATE TABLE app_settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE legacy_score_baselines(player_id TEXT PRIMARY KEY REFERENCES family_roles_v2(player_id),points INTEGER NOT NULL,imported_at_utc TEXT NOT NULL)',
    );
    final old = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='players'",
    );
    if (old.isNotEmpty) {
      await db.execute(
        '''INSERT INTO legacy_score_baselines(player_id,points,imported_at_utc)
      SELECT p.avatar,COALESCE(p.total_score,0),? FROM players p JOIN family_roles_v2 f ON f.player_id=p.avatar''',
        [DateTime.now().toUtc().toIso8601String()],
      );
    }
  }

  Future<void> save(Session session) async {
    // Serialize before the first await: later UI ticks cannot alter this write.
    final j = session.toJson(),
        s = session.state,
        c = s.config,
        payload = jsonEncode(j),
        config = jsonEncode(c.toJson());
    await db.transaction((tx) async {
      final rows = await tx.query(
        'game_sessions_v2',
        where: 'session_id=?',
        whereArgs: [session.id],
      );
      if (rows.isEmpty) {
        await tx.insert('game_sessions_v2', {
          'session_id': session.id,
          'game_type': c.game.name,
          'config_json': config,
          'ruleset_id': rulesVersion,
          'reward_policy_id': rewardVersion,
          'rng_seed': session.seed,
          'status': 'active',
          'revision': s.revision,
          'started_at_utc': j['createdAt'],
          'active_duration_ms': j['durationMs'],
        });
        for (var i = 0; i < c.players.length; i++) {
          await tx.insert('session_participants_v2', {
            'session_id': session.id,
            'seat': i,
            'player_id': c.players[i],
            'is_ai': c.players[i] == null ? 1 : 0,
          });
        }
      } else {
        final old = rows.single;
        if (old['status'] != 'active') throw StateError('已结算的对局不能再存档');
        if (old['config_json'] != config || old['ruleset_id'] != rulesVersion) {
          throw StateError('不能修改已冻结的开局配置');
        }
        if ((old['revision'] as int) > s.revision ||
            ((old['revision'] as int) == s.revision &&
                (old['active_duration_ms'] as int) >
                    (j['durationMs'] as int))) {
          throw StateError('拒绝过期存档');
        }
        await tx.update(
          'game_sessions_v2',
          {
            'revision': s.revision,
            'active_duration_ms': j['durationMs'],
            'ended_at_utc': j['endedAt'],
          },
          where: 'session_id=?',
          whereArgs: [session.id],
        );
      }
      await tx.insert('game_snapshots_v2', {
        'session_id': session.id,
        'snapshot_version': 1,
        'revision': s.revision,
        'payload_json': payload,
        'saved_at_utc': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<Map<Game, Session>> active() async {
    final rows = await db.query('game_snapshots_v2');
    final out = <Game, Session>{};
    for (final r in rows) {
      final s = Session.fromJson(jsonDecode(r['payload_json'] as String));
      out[s.state.config.game] = s;
    }
    return out;
  }

  Future<Json> settle(Session session) async {
    if (session.endedAt == null) throw StateError('结束时间未冻结');
    final result = Settlement(
          session.state,
          session.durationMs,
          session.endedAt!,
        ).toJson(),
        digest = jsonEncode(result);
    return db.transaction((tx) async {
      final rows = await tx.query(
        'game_sessions_v2',
        where: 'session_id=?',
        whereArgs: [session.id],
      );
      if (rows.isEmpty) throw StateError('对局未存档');
      final row = rows.single;
      if (row['status'] == 'settled') {
        if (row['result_digest'] != digest) throw StateError('同一对局的结算结果冲突');
        return jsonDecode(row['result_digest'] as String) as Json;
      }
      if (row['revision'] != session.state.revision ||
          row['config_json'] != jsonEncode(session.state.config.toJson())) {
        throw StateError('结算版本冲突');
      }
      for (final r in result['results'] as List) {
        await tx.insert('participant_results_v2', {
          'session_id': session.id,
          'seat': r['seat'],
          'player_id': r['player'],
          'outcome': r['outcome'],
          'record_eligible': r['eligible'] == true ? 1 : 0,
          'result_json': jsonEncode(r),
        });
        if (r['player'] != null) {
          await tx.insert('reward_entries_v2', {
            'session_id': session.id,
            'player_id': r['player'],
            'points': r['reward'],
            'policy_id': rewardVersion,
            'breakdown_json': jsonEncode(r['breakdown']),
            'earned_at_utc': result['endedAt'],
            'week_key': shanghaiWeek(session.endedAt!),
          });
        }
      }
      await tx.update(
        'game_sessions_v2',
        {
          'status': 'settled',
          'result_digest': digest,
          'ended_at_utc': result['endedAt'],
          'active_duration_ms': result['durationMs'],
        },
        where: 'session_id=?',
        whereArgs: [session.id],
      );
      await tx.delete(
        'game_snapshots_v2',
        where: 'session_id=?',
        whereArgs: [session.id],
      );
      return result;
    });
  }

  Future<List<Json>> records() async {
    final rows = await db.rawQuery(
      '''SELECT s.session_id,s.config_json,s.ruleset_id,s.ended_at_utc,s.active_duration_ms,r.result_json
      FROM game_sessions_v2 s JOIN participant_results_v2 r USING(session_id)
      WHERE s.status='settled' AND r.player_id IS NOT NULL ORDER BY s.ended_at_utc DESC''',
    );
    return rows
        .map(
          (r) => <String, dynamic>{
            ...jsonDecode(r['result_json'] as String) as Json,
            'id': r['session_id'],
            'config': jsonDecode(r['config_json'] as String),
            'rules': r['ruleset_id'],
            'endedAt': r['ended_at_utc'],
            'durationMs': r['active_duration_ms'],
          },
        )
        .toList();
  }

  Future<List<Json>> familyRanking({String? week}) async {
    final rows = await db.rawQuery(
      '''SELECT f.player_id AS player,COALESCE(SUM(r.points),0) AS points
      FROM family_roles_v2 f LEFT JOIN reward_entries_v2 r ON r.player_id=f.player_id ${week == null ? '' : 'AND r.week_key=?'}
      GROUP BY f.player_id ORDER BY points DESC,f.player_id''',
      week == null ? [] : [week],
    );
    final out = rows.map((r) => Map<String, dynamic>.from(r)).toList();
    var rank = 0;
    for (var i = 0; i < out.length; i++) {
      if (i == 0 || out[i]['points'] != out[i - 1]['points']) rank = i + 1;
      out[i]['rank'] = rank;
    }
    return out;
  }

  Future<Map<String, int>> legacyScores() async => {
    for (final r in await db.query('legacy_score_baselines'))
      r['player_id'] as String: r['points'] as int,
  };
  Future<List<Json>> legacyRecords(String role) async {
    if ((await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE name='game_records'",
    )).isEmpty) {
      return [];
    }
    return (await db.query(
      'game_records',
      where: 'avatar=?',
      whereArgs: [role],
      orderBy: 'played_at DESC',
    )).map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<Json> settings() async => {
    for (final r in await db.query('app_settings'))
      r['key'] as String: jsonDecode(r['value'] as String),
  };
  Future<void> setSetting(String key, dynamic value) async {
    await db.insert('app_settings', {
      'key': key,
      'value': jsonEncode(value),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() => db.close();
}
