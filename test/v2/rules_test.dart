import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_rules/puzzle_rules.dart';

RuleState alter(RuleState s, void Function(Json) change) {
  final d = copyJson(s.data);
  change(d);
  return RuleState(s.config, d, s.rng, s.revision);
}

RuleState step(RuleState s, String cmd, [Json a = const {}]) =>
    Rules.apply(s, cmd, a, revision: s.revision).state;
RuleState fresh(Game g) => Rules.create(
  GameConfig(
    game: g,
    mode: g == Game.gobang ? 'ai' : 'standard',
    players: g == Game.gobang
        ? ['boy', null]
        : g == Game.flying
        ? ['boy', 'girl', null, null]
        : ['boy'],
  ),
  42,
);
void main() {
  test('2048 merge is single pass in movement order', () {
    expect(mergeLine([2, 2, 2, 2]).line, [4, 4, 0, 0]);
    expect(mergeLine([2, 2, 2, 2]).score, 8);
    expect(mergeLine([4, 4, 8, 0]).line, [8, 8, 0, 0]);
  });
  test('2048 no-op does not consume random or revision', () {
    final s = alter(
      fresh(Game.game2048),
      (d) => d['board'] = [2, 4, 8, 16, ...List.filled(12, 0)],
    );
    final t = Rules.apply(s, 'move', {
      'direction': 'left',
    }, revision: s.revision);
    expect(t.accepted, false);
    expect(t.state.rng, s.rng);
  });
  test('2048 all directions preserve sum plus exactly one 2/4', () {
    for (final dir in ['left', 'right', 'up', 'down']) {
      final s = alter(
        fresh(Game.game2048),
        (d) => d['board'] = [2, 2, 4, 4, 0, 8, 8, 0, 2, 0, 2, 0, 0, 0, 0, 0],
      );
      final t = step(s, 'move', {'direction': dir});
      final delta =
          ints(t.data['board']).reduce((a, b) => a + b) -
          ints(s.data['board']).reduce((a, b) => a + b);
      expect([2, 4], contains(delta));
    }
  });
  test('2048 milestone persists through round trip and emits once', () {
    var s = alter(
      fresh(Game.game2048),
      (d) => d['board'] = [1024, 1024, ...List.filled(14, 0)],
    );
    s = step(s, 'move', {'direction': 'left'});
    expect(s.data['milestonePending'], true);
    s = RuleState.fromJson(jsonDecode(jsonEncode(s.toJson())));
    s = step(s, 'dismissMilestone');
    expect(s.data['milestonePending'], false);
    s = step(s, 'finish');
    expect(s.outcome, 'won');
    expect(Settlement(s, 100, DateTime.utc(2026)).results.first['reward'], 50);
  });
  test('snapshot random stream reproduces future board', () {
    var a = fresh(Game.game2048);
    var b = RuleState.fromJson(jsonDecode(jsonEncode(a.toJson())));
    for (final dir in ['left', 'down', 'right', 'up', 'left']) {
      a = step(a, 'move', {'direction': dir});
      b = step(b, 'move', {'direction': dir});
      expect(a.toJson(), b.toJson());
    }
  });
  test('stale revisions and terminal commands are rejected', () {
    final s = fresh(Game.memory);
    expect(Rules.apply(s, 'flip', {'index': 0}, revision: 10).accepted, false);
    final terminal = step(s, 'abandon');
    expect(
      Rules.apply(terminal, 'flip', {
        'index': 0,
      }, revision: terminal.revision).accepted,
      false,
    );
  });
  test('snapshots cannot be mutated by presentation layer', () {
    final s = fresh(Game.memory);
    expect(() => s.data['board'][0] = 99, throwsUnsupportedError);
    expect(() => s.data['moves'] = 9, throwsUnsupportedError);
  });
  test('gobang wins every direction including overline', () {
    for (final delta in [1, 15, 16, 14]) {
      final b = List.filled(225, 0);
      final start = delta == 14 ? 20 : 16;
      for (var k = 0; k < 6; k++) {
        b[start + k * delta] = 1;
      }
      expect(gobangWins(b, start + 3 * delta, 1), true);
    }
  });
  test('gobang human white undo cannot remove AI opening', () {
    var s = Rules.create(
      GameConfig(
        game: Game.gobang,
        mode: 'ai',
        humanColor: 2,
        players: [null, 'boy'],
      ),
      4,
    );
    s = step(s, 'place', {'index': 112, 'color': 1});
    expect(step(s, 'undo').revision, s.revision);
    s = step(s, 'place', {'index': 113, 'color': 2});
    s = step(s, 'place', {'index': 114, 'color': 1});
    s = step(s, 'undo');
    expect(s.data['history'], [112]);
    expect(s.data['turn'], 2);
    expect(s.assisted, true);
    expect(s.data['undos'], [0, 1]);
  });
  test('local undo belongs to last mover and consumes only on approval', () {
    var s = Rules.create(
      GameConfig(game: Game.gobang, mode: 'local', players: ['boy', 'girl']),
      8,
    );
    s = step(s, 'place', {'index': 112, 'color': 1});
    expect(
      step(s, 'undo', {'approved': false, 'requester': 0}).revision,
      s.revision,
    );
    s = step(s, 'undo', {'approved': true, 'requester': 0});
    expect(s.data['undos'], [1, 0]);
    expect(s.data['turn'], 1);
  });
  test('AI takes win before blocking across every difficulty', () {
    for (var difficulty = 0; difficulty < 3; difficulty++) {
      var s = Rules.create(
        GameConfig(
          game: Game.gobang,
          mode: 'ai',
          difficulty: difficulty,
          players: ['boy', null],
        ),
        4,
      );
      s = alter(s, (d) {
        for (var i = 0; i < 4; i++) {
          d['board'][i] = 1;
          d['board'][30 + i] = 2;
        }
        d['turn'] = 2;
      });
      expect(chooseGobangMove(s), 34);
    }
  });
  test(
    'memory has pairs, ignores duplicate and third cards; wait survives pause',
    () {
      var s = fresh(Game.memory);
      for (var n = 0; n < 8; n++) {
        expect(ints(s.data['board']).where((v) => v == n).length, 2);
      }
      final b = ints(s.data['board']), j = b.indexWhere((v) => v != b[0]);
      s = step(s, 'flip', {'index': 0});
      expect(step(s, 'flip', {'index': 0}).revision, s.revision);
      s = step(s, 'flip', {'index': j});
      expect(s.data['moves'], 1);
      expect(step(s, 'flip', {'index': (j + 1) % 16}).revision, s.revision);
      s = step(s, 'tick', {'ms': 300});
      s = RuleState.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(s.data['remainingMs'], 500);
      s = step(s, 'tick', {'ms': 499});
      expect(s.data['open'].length, 2);
      s = step(s, 'tick', {'ms': 1});
      expect(s.data['open'], isEmpty);
    },
  );
  test('memory finishes once and ranks attempts before time', () {
    var s = fresh(Game.memory);
    for (var n = 0; n < 8; n++) {
      final ids = [
        for (var i = 0; i < 16; i++)
          if (s.data['board'][i] == n) i,
      ];
      s = step(s, 'flip', {'index': ids[0]});
      s = step(s, 'flip', {'index': ids[1]});
    }
    expect(s.outcome, 'won');
    expect(Settlement(s, 9999, DateTime.utc(2026)).results.first['reward'], 20);
    expect(
      comparePerformance(
        Game.memory,
        {
          'metrics': {'moves': 8},
          'durationMs': 50000,
        },
        {
          'metrics': {'moves': 9},
          'durationMs': 10000,
        },
      ),
      lessThan(0),
    );
  });
  test('sudoku generation is unique and correctly graded', () {
    for (var difficulty = 0; difficulty < 3; difficulty++) {
      for (var seed = 0; seed < 4; seed++) {
        final s = Rules.create(
          GameConfig(game: Game.sudoku, difficulty: difficulty),
          seed + 410,
        );
        expect(sudokuSolutionCount(ints(s.data['puzzle'])), 1);
        expect(sudokuGrade(ints(s.data['puzzle'])), difficulty);
      }
    }
  });
  test('sudoku notes no error, wrong edits recover, hints lock and cap', () {
    var s = fresh(Game.sudoku);
    final blanks = [
      for (var i = 0; i < 81; i++)
        if (s.data['puzzle'][i] == 0) i,
    ];
    final i = blanks.first,
        correct = s.data['solution'][i] as int,
        wrong = correct % 9 + 1;
    s = step(s, 'note', {'index': i, 'number': wrong});
    expect(s.data['errors'], 0);
    s = step(s, 'number', {'index': i, 'number': wrong});
    expect(s.data['errors'], 1);
    expect(
      step(s, 'number', {'index': i, 'number': wrong}).revision,
      s.revision,
    );
    s = step(s, 'number', {'index': i, 'number': correct});
    for (final j in blanks.skip(1).take(3)) {
      s = step(s, 'hint', {'index': j});
    }
    expect(s.data['hints'], 3);
    expect(step(s, 'hint', {'index': blanks[4]}).revision, s.revision);
    expect(step(s, 'erase', {'index': blanks[1]}).revision, s.revision);
  });
  test(
    'match3 initial and all stable rounds have no matches and a legal move',
    () {
      for (var seed = 0; seed < 20; seed++) {
        var s = Rules.create(GameConfig(game: Game.match3), seed);
        for (var move = 0; move < 50 && !s.terminal; move++) {
          final b = ints(s.data['board']);
          expect(matchLines(b), isEmpty);
          final hint = matchHint(b);
          expect(hint, isNotNull);
          s = step(s, 'swap', {'from': hint![0], 'to': hint[1]});
          expect(matchLines(ints(s.data['board'])), isEmpty);
        }
      }
    },
  );
  test('match3 invalid swaps leave steps and random state unchanged', () {
    final s = fresh(Game.match3);
    expect(step(s, 'swap', {'from': 0, 'to': 63}).toJson(), s.toJson());
  });
  test('flight preserves dice and enforces roll ownership/id', () {
    var s = alter(fresh(Game.flying), (d) {
      d['turn'] = 0;
      d['misses'] = [3, 0, 0, 0];
    });
    s = step(s, 'roll');
    expect(s.data['dice'], 6);
    s = RuleState.fromJson(jsonDecode(jsonEncode(s.toJson())));
    expect(step(s, 'roll').revision, s.revision);
    expect(
      step(s, 'fly', {
        'seat': 1,
        'plane': 0,
        'rollId': s.data['rollId'],
      }).revision,
      s.revision,
    );
    final id = s.data['rollId'];
    s = step(s, 'fly', {'seat': 0, 'plane': 0, 'rollId': id});
    expect(s.data['planes'][0][0], 0);
    expect(s.data['turn'], 0);
    expect(
      step(s, 'fly', {'seat': 0, 'plane': 1, 'rollId': id}).revision,
      s.revision,
    );
  });
  test('flight crosses entry 47+2=49 and requires exact finish', () {
    var s = alter(fresh(Game.flying), (d) {
      d['turn'] = 0;
      d['dice'] = 2;
      d['rollId'] = 4;
      d['planes'][0] = [47, 53, 54, -1];
    });
    expect(legalPlanes(s.data), [0]);
    s = step(s, 'fly', {'seat': 0, 'plane': 0, 'rollId': 4});
    expect(s.data['planes'][0][0], 49);
  });
  test('flight accelerator +3 stops at relative48', () {
    var s = alter(fresh(Game.flying), (d) {
      d['turn'] = 0;
      d['dice'] = 2;
      d['rollId'] = 2;
      d['planes'][0][0] = 43;
    });
    s = step(s, 'fly', {'seat': 0, 'plane': 0, 'rollId': 2});
    expect(s.data['planes'][0][0], 48);
  });
  test('flight first full team ends all seats, no invented places', () {
    var s = alter(fresh(Game.flying), (d) {
      d['turn'] = 1;
      d['dice'] = 1;
      d['rollId'] = 2;
      d['planes'][1] = [54, 54, 54, 53];
    });
    s = step(s, 'fly', {'seat': 1, 'plane': 3, 'rollId': 2});
    final r = Settlement(s, 100, DateTime.utc(2026)).results;
    expect(r.map((x) => x['outcome']), ['lost', 'won', 'lost', 'lost']);
    expect(r.map((x) => x['reward']), [0, 40, 0, 0]);
  });
  test('reward tiers, assisted sudoku, zero abandonment', () {
    var s = alter(fresh(Game.game2048), (d) {
      d['outcome'] = 'lost';
      d['highest'] = 128;
      d['started'] = true;
    });
    expect(Settlement(s, 100, DateTime.utc(2026)).results.first['reward'], 10);
    s = alter(fresh(Game.sudoku), (d) {
      d['outcome'] = 'won';
      d['assisted'] = true;
      d['errors'] = 0;
      d['started'] = true;
    });
    expect(Settlement(s, 100, DateTime.utc(2026)).results.first['reward'], 30);
    s = step(fresh(Game.game2048), 'abandon');
    expect(Settlement(s, 0, DateTime.utc(2026)).results.first['reward'], 0);
  });
  test('Shanghai Monday boundary uses ended UTC time', () {
    expect(shanghaiWeek(DateTime.parse('2026-10-04T15:59:59Z')), '2026-09-28');
    expect(shanghaiWeek(DateTime.parse('2026-10-04T16:00:00Z')), '2026-10-05');
  });
}
