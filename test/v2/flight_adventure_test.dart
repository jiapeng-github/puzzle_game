import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_rules/puzzle_rules.dart';

RuleState flight({
  String mode = 'adventure',
  int from = 0,
  int dice = 1,
  void Function(Json)? edit,
}) {
  final s = Rules.create(
    GameConfig(
      game: Game.flying,
      mode: mode,
      players: ['boy', 'girl', null, null],
    ),
    42,
  );
  final d = copyJson(s.data);
  d['turn'] = 0;
  d['dice'] = dice;
  d['rollId'] = 1;
  d['planes'][0][0] = from;
  edit?.call(d);
  return RuleState(s.config, d, s.rng, s.revision);
}

RuleState fly(RuleState s) => Rules.apply(s, 'fly', {
  'seat': 0,
  'plane': 0,
  'rollId': 1,
}, revision: s.revision).state;

void main() {
  test('special cells are disjoint from one another and safe starts', () {
    final all = [
      ...accelerators,
      ...shieldCells,
      ...meteorCells,
      ...flightStarts,
    ];
    expect(all.toSet().length, all.length);
  });
  test('shield pickup persists and never stacks', () {
    for (final initial in [0, 1]) {
      final s = fly(flight(from: 6, edit: (d) => d['shields'][0][0] = initial));
      expect(s.data['planes'][0][0], 7); // absolute 36
      expect(s.data['shields'][0][0], 1);
      expect(RuleState.fromJson(s.toJson()).data, s.data);
    }
  });
  test('meteor retreat does not trigger accelerator at its destination', () {
    final s = fly(flight(from: 0)); // absolute30 -> retreat to own0
    expect(s.data['planes'][0][0], 0);
    expect(s.data['meteors'][0], 1);
    final t = fly(flight(from: 12)); // abs42, relative13 ->10
    expect(t.data['planes'][0][0], 10);
    expect(t.data['boosts'][0], 0);
  });
  test('one shield absorbs a meteor exactly once', () {
    final s = fly(flight(from: 0, edit: (d) => d['shields'][0][0] = 1));
    expect(s.data['planes'][0][0], 1);
    expect(s.data['shields'][0][0], 0);
    expect(s.data['blocks'][0], 1);
  });
  test('acceleration advances three once without adding a shield', () {
    final s = fly(flight(from: 2)); // abs32 boosts once to abs35
    expect(s.data['planes'][0][0], 6);
    expect(s.data['shields'][0][0], 0);
    expect(s.data['boosts'][0], 1);
  });
  test('collision checks each stacked plane shield independently', () {
    final s = fly(
      flight(
        from: 3,
        edit: (d) {
          // Red lands abs33. Yellow relative40 also abs33.
          d['planes'][1][0] = 40;
          d['planes'][1][1] = 40;
          d['shields'][1][0] = 1;
        },
      ),
    );
    expect(s.data['planes'][1][0], 40);
    expect(s.data['shields'][1][0], 0);
    expect(s.data['planes'][1][1], -1);
    expect(s.data['collisions'][0], 1);
    expect(s.data['blocks'][1], 1);
  });
  test('safe landing never consumes defender shield', () {
    final s = fly(
      flight(
        from: 11,
        edit: (d) {
          d['planes'][1][0] = 0;
          d['shields'][1][0] = 1;
        },
      ),
    );
    expect(s.data['planes'][1][0], 0);
    expect(s.data['shields'][1][0], 1);
  });
  test(
    'classic and old snapshots ignore adventure tiles and tolerate absent fields',
    () {
      final s = fly(
        flight(
          mode: 'standard',
          from: 0,
          edit: (d) {
            for (final key in [
              'shields',
              'boosts',
              'blocks',
              'meteors',
              'flightEvents',
            ]) {
              d.remove(key);
            }
          },
        ),
      );
      expect(s.data['planes'][0][0], 1);
      expect(s.data['meteors'][0], 0);
    },
  );
  test('invalid commands cannot consume a shield or a stored roll', () {
    final s = flight(edit: (d) => d['shields'][0][0] = 1);
    final result = Rules.apply(s, 'fly', {
      'seat': 1,
      'plane': 0,
      'rollId': 1,
    }, revision: s.revision);
    expect(result.accepted, false);
    expect(result.state.toJson(), s.toJson());
  });
  test(
    'home path is event free and AI returns a legal plane deterministically',
    () {
      final s = flight(from: 53);
      expect(fly(s).data['planes'][0][0], 54);
      expect(legalPlanes(s.data), contains(choosePlane(s)));
      expect(choosePlane(RuleState.fromJson(s.toJson())), choosePlane(s));
    },
  );
  test('adventure and classic records never share a ranking', () {
    final completed = fly(
      flight(
        from: 53,
        edit: (d) {
          d['planes'][0] = [53, 54, 54, 54];
        },
      ),
    );
    final result = Settlement(
      completed,
      1000,
      DateTime.utc(2026),
    ).results.first;
    final rows = [
      {
        'id': 'a',
        ...result,
        'config': completed.config.toJson(),
        'rules': rulesVersion,
        'durationMs': 1000,
      },
    ];
    final classic = gameRanking(
      rows,
      GameConfig(game: Game.flying, players: ['boy', 'girl', null, null]),
    );
    final adventure = gameRanking(rows, completed.config);
    expect(classic.firstWhere((r) => r['player'] == 'boy')['missing'], true);
    expect(adventure.firstWhere((r) => r['player'] == 'boy')['wins'], 1);
    expect(result['reward'], 40);
  });
  test('seeded AI simulations finish and remain identical after restore', () {
    for (var seed = 0; seed < 10; seed++) {
      var state = Rules.create(
        GameConfig(
          game: Game.flying,
          mode: 'adventure',
          players: ['boy', 'girl', null, null],
        ),
        seed,
      );
      var actions = 0;
      while (!state.terminal && actions++ < 6000) {
        final command = state.data['dice'] == 0 ? 'roll' : 'fly';
        final args = command == 'roll'
            ? <String, dynamic>{}
            : <String, dynamic>{
                'seat': state.data['turn'],
                'plane': choosePlane(state),
                'rollId': state.data['rollId'],
              };
        final result = Rules.apply(
          state,
          command,
          args,
          revision: state.revision,
        );
        expect(result.accepted, true);
        if (actions % 25 == 0) {
          final restored = RuleState.fromJson(state.toJson());
          expect(
            Rules.apply(
              restored,
              command,
              args,
              revision: restored.revision,
            ).state.toJson(),
            result.state.toJson(),
          );
        }
        state = result.state;
        expect(
          (state.data['planes'] as List)
              .expand((r) => ints(r))
              .every((p) => p >= -1 && p <= 54),
          true,
        );
        expect(
          (state.data['shields'] as List)
              .expand((r) => ints(r))
              .every((p) => p == 0 || p == 1),
          true,
        );
      }
      expect(state.terminal, true, reason: 'seed $seed must complete');
      expect(
        Settlement(
          state,
          actions * 1000,
          DateTime.utc(2026),
        ).results.where((r) => r['outcome'] == 'won').length,
        1,
      );
    }
  });
}
