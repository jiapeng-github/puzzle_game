import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_rules/puzzle_rules.dart';

Transition apply(RuleState state, String command, [Json args = const {}]) =>
    Rules.apply(state, command, args, revision: state.revision);

void main() {
  test('memory observation ticks never repeat flip sounds', () {
    var state = Rules.create(GameConfig(game: Game.memory), 17);
    final board = ints(state.data['board']);
    state = apply(state, 'flip', {'index': 0}).state;
    final flipped = apply(state, 'flip', {
      'index': board.indexWhere((v) => v != board[0]),
    });
    expect(flipped.event, 'turn');
    state = flipped.state;
    for (var i = 0; i < 8; i++) {
      final tick = apply(state, 'tick', {'ms': 100});
      expect(tick.accepted, isTrue);
      expect(tick.event, isNull);
      state = tick.state;
    }
  });

  test('sudoku erasing and notes do not repeat correct-entry sound', () {
    var state = Rules.create(GameConfig(game: Game.sudoku), 4);
    final index = (state.data['puzzle'] as List).indexOf(0);
    final entered = apply(state, 'number', {
      'index': index,
      'number': state.data['solution'][index],
    });
    expect(entered.event, 'fixed');
    final erased = apply(entered.state, 'erase', {'index': index});
    expect(erased.accepted, isTrue);
    expect(erased.event, isNull);
    expect(
      apply(erased.state, 'note', {'index': index, 'number': 1}).event,
      isNull,
    );
  });

  for (final game in Game.values) {
    test('${game.name}: old saved event never leaks into abandon', () {
      final config = GameConfig(
        game: game,
        mode: game == Game.gobang ? 'local' : 'standard',
        players: game == Game.gobang
            ? ['boy', 'girl']
            : game == Game.flying
            ? ['boy', null, null, null]
            : ['boy'],
      );
      final initial = Rules.create(config, 17);
      final data = Map<String, dynamic>.from(initial.data)
        ..['event'] = 'winning';
      final restored = RuleState(config, data, initial.rng, initial.revision);
      expect(apply(restored, 'abandon').event, isNull);
      expect(
        apply(restored, 'abandon').state.data.containsKey('event'),
        isFalse,
      );
    });
  }
}
