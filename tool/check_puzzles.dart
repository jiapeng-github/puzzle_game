import 'dart:io';
import 'package:puzzle_rules/puzzle_rules.dart';

void main() {
  for (var difficulty = 0; difficulty < 3; difficulty++) {
    final watch = Stopwatch()..start();
    final s = Rules.create(
      GameConfig(game: Game.sudoku, difficulty: difficulty),
      470 + difficulty,
    );
    stdout.writeln(
      '$difficulty ${watch.elapsedMilliseconds}ms grade=${sudokuGrade(ints(s.data['puzzle']))} unique=${sudokuSolutionCount(ints(s.data['puzzle']))}',
    );
    stdout.writeln(ints(s.data['puzzle']).join());
    stdout.writeln(ints(s.data['solution']).join());
  }
}
