import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_rules/puzzle_rules.dart';

Json record(
  String role,
  GameConfig c,
  Json metrics,
  int duration, {
  bool assisted = false,
  String outcome = 'won',
}) => {
  'player': role,
  'config': c.toJson(),
  'metrics': metrics,
  'durationMs': duration,
  'eligible': true,
  'rules': rulesVersion,
  'assisted': assisted,
  'outcome': outcome,
};
void main() {
  test('sudoku groups assistance/difficulty, ties, and missing records', () {
    final c = GameConfig(game: Game.sudoku, difficulty: 1);
    final rows = gameRanking([
      record('boy', c, {'errors': 0}, 1234),
      record('girl', c, {'errors': 0}, 1234),
      record('dad', c, {'errors': 1}, 1234),
      record('mom', c, {'errors': 0}, 1, assisted: true),
      record('grandpa', GameConfig(game: Game.sudoku, difficulty: 0), {
        'errors': 0,
      }, 1),
    ], c);
    expect(rows.take(3).map((r) => r['rank']), [1, 1, 3]);
    expect(
      rows.skip(3).every((r) => r['missing'] == true && r['rank'] == null),
      true,
    );
  });
  test('2048 best metrics come from the same actual session', () {
    final c = GameConfig(game: Game.game2048);
    final rows = gameRanking([
      record('boy', c, {'score': 2000, 'highest': 128}, 20000),
      record('boy', c, {'score': 1000, 'highest': 512}, 10000),
      record('girl', c, {'score': 2000, 'highest': 256}, 30000),
    ], c);
    expect(rows.first['player'], 'girl');
    expect(rows[1]['metrics'], {'score': 2000, 'highest': 128});
    expect(rows[1]['durationMs'], 20000);
  });
  test(
    'wins tie regardless of win rate, zero wins differs from never played',
    () {
      final c = GameConfig(
        game: Game.gobang,
        mode: 'local',
        players: ['boy', 'girl'],
      );
      final rows = gameRanking([
        record('boy', c, {}, 1),
        record('boy', c, {}, 1, outcome: 'lost'),
        record('girl', c, {}, 1),
        record('dad', c, {}, 1, outcome: 'lost'),
      ], c);
      expect(rows.take(3).map((r) => r['rank']), [1, 1, 3]);
      expect(rows[2]['wins'], 0);
      expect(rows[3]['missing'], true);
    },
  );
}
