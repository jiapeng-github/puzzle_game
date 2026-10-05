part of '../puzzle_rules.dart';

final sudokuUnits = <List<int>>[
  for (var r = 0; r < 9; r++) [for (var c = 0; c < 9; c++) r * 9 + c],
  for (var c = 0; c < 9; c++) [for (var r = 0; r < 9; r++) r * 9 + c],
  for (var br = 0; br < 3; br++)
    for (var bc = 0; bc < 3; bc++)
      [
        for (var r = 0; r < 3; r++)
          for (var c = 0; c < 3; c++) (br * 3 + r) * 9 + bc * 3 + c,
      ],
];
final sudokuPeers = List.generate(
  81,
  (i) => sudokuUnits
      .where((u) => u.contains(i))
      .expand((u) => u)
      .where((j) => j != i)
      .toSet(),
);
Set<int> _candidates(List<int> b, int i) => {
  for (var n = 1; n <= 9; n++)
    if (!sudokuPeers[i].any((j) => b[j] == n)) n,
};
int sudokuSolutionCount(List<int> puzzle, {int limit = 2}) {
  final b = List<int>.from(puzzle);
  if (b.length != 81 || b.any((n) => n < 0 || n > 9)) return 0;
  for (var i = 0; i < 81; i++) {
    if (b[i] != 0 && sudokuPeers[i].any((j) => b[j] == b[i])) return 0;
  }
  var count = 0;
  void solve() {
    if (count >= limit) return;
    var best = -1;
    Set<int> options = {};
    for (var i = 0; i < 81; i++) {
      if (b[i] != 0) continue;
      final cs = _candidates(b, i);
      if (cs.isEmpty) return;
      if (best == -1 || cs.length < options.length) {
        best = i;
        options = cs;
      }
      if (cs.length == 1) break;
    }
    if (best == -1) {
      count++;
      return;
    }
    for (final n in options) {
      b[best] = n;
      solve();
      if (count >= limit) break;
    }
    b[best] = 0;
  }

  solve();
  return count;
}

/// Returns the strongest required strategy: 0 singles; 1 locked/naked pairs;
/// 2 hidden pairs/X-Wing; null means guessing or an invalid puzzle is required.
int? sudokuGrade(List<int> puzzle) {
  final b = List<int>.from(puzzle);
  final cs = List.generate(81, (i) => b[i] == 0 ? _candidates(b, i) : <int>{});
  var grade = 0;
  void put(int i, int n) {
    b[i] = n;
    cs[i].clear();
    for (final j in sudokuPeers[i]) {
      cs[j].remove(n);
    }
  }

  bool singles() {
    for (var i = 0; i < 81; i++) {
      if (b[i] == 0 && cs[i].length == 1) {
        put(i, cs[i].first);
        return true;
      }
    }
    for (final u in sudokuUnits) {
      for (var n = 1; n <= 9; n++) {
        final cells = u.where((i) => b[i] == 0 && cs[i].contains(n)).toList();
        if (cells.length == 1) {
          put(cells.first, n);
          return true;
        }
      }
    }
    return false;
  }

  bool locked() {
    var changed = false;
    for (final u in sudokuUnits) {
      for (var n = 1; n <= 9; n++) {
        final cells = u.where((i) => cs[i].contains(n)).toList();
        if (cells.length < 2) continue;
        for (final v in sudokuUnits) {
          if (identical(u, v) || !cells.every(v.contains)) continue;
          for (final i in v) {
            if (!u.contains(i)) changed = cs[i].remove(n) || changed;
          }
        }
      }
    }
    return changed;
  }

  bool pairs(bool hidden) {
    var changed = false;
    for (final u in sudokuUnits) {
      if (!hidden) {
        for (final i in u) {
          if (cs[i].length != 2) continue;
          final same = u
              .where((j) => cs[j].length == 2 && cs[j].containsAll(cs[i]))
              .toList();
          if (same.length != 2) continue;
          final pair = Set<int>.from(cs[i]);
          for (final j in u) {
            if (same.contains(j)) continue;
            for (final n in pair) {
              changed = cs[j].remove(n) || changed;
            }
          }
        }
      } else {
        for (var a = 1; a <= 9; a++) {
          for (var z = a + 1; z <= 9; z++) {
            final aa = u.where((i) => cs[i].contains(a)).toSet(),
                bb = u.where((i) => cs[i].contains(z)).toSet();
            if (aa.length == 2 &&
                aa.length == bb.length &&
                aa.containsAll(bb)) {
              for (final i in aa) {
                final before = cs[i].length;
                cs[i].retainAll([a, z]);
                changed = changed || cs[i].length != before;
              }
            }
          }
        }
      }
    }
    return changed;
  }

  bool xwing() {
    var changed = false;
    for (var direction = 0; direction < 2; direction++) {
      for (var n = 1; n <= 9; n++) {
        final rows = List.generate(
          9,
          (r) => [
            for (var c = 0; c < 9; c++)
              if (cs[direction == 0 ? r * 9 + c : c * 9 + r].contains(n)) c,
          ],
        );
        for (var r = 0; r < 9; r++) {
          if (rows[r].length != 2) continue;
          for (var s = r + 1; s < 9; s++) {
            if (rows[s].length != 2 ||
                rows[r][0] != rows[s][0] ||
                rows[r][1] != rows[s][1]) {
              continue;
            }
            for (var other = 0; other < 9; other++) {
              if (other == r || other == s) continue;
              for (final c in rows[r]) {
                changed =
                    cs[direction == 0 ? other * 9 + c : c * 9 + other].remove(
                      n,
                    ) ||
                    changed;
              }
            }
          }
        }
      }
    }
    return changed;
  }

  for (var step = 0; step < 1000; step++) {
    if (!b.contains(0)) return grade;
    if (List.generate(81, (i) => b[i] == 0 && cs[i].isEmpty).any((v) => v)) {
      return null;
    }
    if (singles()) continue;
    if (locked() || pairs(false)) {
      grade = math.max(grade, 1);
      continue;
    }
    if (pairs(true) || xwing()) {
      grade = 2;
      continue;
    }
    return null;
  }
  return null;
}

Json createSudoku(int difficulty, SeededRandom rng) {
  for (var attempt = 0; attempt < 120; attempt++) {
    final digits = List.generate(9, (i) => i + 1);
    rng.shuffle(digits);
    final bands = [0, 1, 2], stacks = [0, 1, 2];
    rng.shuffle(bands);
    rng.shuffle(stacks);
    List<int> shuffledRows(List<int> groups) {
      final out = <int>[];
      for (final g in groups) {
        final sub = [0, 1, 2];
        rng.shuffle(sub);
        out.addAll(sub.map((i) => g * 3 + i));
      }
      return out;
    }

    final rows = shuffledRows(bands), cols = shuffledRows(stacks);
    final solution = [
      for (final r in rows)
        for (final c in cols) digits[(r * 3 + r ~/ 3 + c) % 9],
    ];
    final puzzle = List<int>.from(solution),
        positions = List.generate(81, (i) => i);
    rng.shuffle(positions);
    Json result() => {
      'board': List<int>.from(puzzle),
      'puzzle': puzzle,
      'solution': solution,
      'notes': List.generate(81, (_) => <int>[]),
      'hinted': <int>[],
      'errors': 0,
      'grade': difficulty,
    };
    for (final i in positions) {
      final old = puzzle[i];
      puzzle[i] = 0;
      if (sudokuSolutionCount(puzzle) != 1) {
        puzzle[i] = old;
        continue;
      }
      final grade = sudokuGrade(puzzle);
      if (grade == difficulty &&
          puzzle.where((x) => x == 0).length >= 40 + difficulty * 4) {
        return result();
      }
      if (grade == null || grade > difficulty) puzzle[i] = old;
    }
  }
  final fixtures = [
    [
      '769000000501960082000035007600210950390706000412093076003628041800000039004079200',
      '769842315531967482248135697687214953395786124412593876973628541826451739154379268',
    ],
    [
      '070060039000000000052010800060000250200630070010005090000096700030400060000000584',
      '874562139193784625652913847369147258285639471417825396548296713731458962926371584',
    ],
    [
      '270001000000000009090034800083072000040000070000090358439000010020017003000000000',
      '278961435354728169691534827583172694946853271712496358439285716825617943167349582',
    ],
  ];
  final puzzle = fixtures[difficulty][0].split('').map(int.parse).toList();
  final solution = fixtures[difficulty][1].split('').map(int.parse).toList();
  if (sudokuSolutionCount(puzzle) != 1 || sudokuGrade(puzzle) != difficulty) {
    throw StateError('预验证题库校验失败');
  }
  return {
    'board': List<int>.from(puzzle),
    'puzzle': puzzle,
    'solution': solution,
    'notes': List.generate(81, (_) => <int>[]),
    'hinted': <int>[],
    'errors': 0,
    'grade': difficulty,
  };
}

bool _stepSudoku(Json d, String cmd, Json a) {
  final i = a['index'] as int? ?? -1;
  if (i < 0 ||
      i >= 81 ||
      d['puzzle'][i] != 0 ||
      (d['hinted'] as List).contains(i)) {
    return false;
  }
  if (cmd == 'note') {
    if (d['board'][i] != 0) return false;
    final n = a['number'] as int? ?? 0;
    if (n < 1 || n > 9) return false;
    final notes = ints(d['notes'][i]);
    if (!notes.remove(n)) notes.add(n);
    d['notes'][i] = notes..sort();
    return true;
  }
  if (cmd == 'erase') {
    if (d['board'][i] == 0 && (d['notes'][i] as List).isEmpty) return false;
    d['board'][i] = 0;
    d['notes'][i] = <int>[];
    return true;
  }
  if (cmd == 'hint') {
    if (d['hints'] >= 3 || d['board'][i] == d['solution'][i]) return false;
    d['board'][i] = d['solution'][i];
    (d['hinted'] as List).add(i);
    d['hints']++;
    d['assisted'] = true;
    d['started'] = true;
  } else if (cmd == 'number') {
    final n = a['number'] as int? ?? 0;
    if (n < 1 || n > 9 || n == d['board'][i]) return false;
    d['board'][i] = n;
    d['moves']++;
    if (n != d['solution'][i]) d['errors']++;
  } else {
    return false;
  }
  d['notes'][i] = <int>[];
  d['event'] = d['board'][i] == d['solution'][i] ? 'fixed' : null;
  if (List.generate(
    81,
    (j) => d['board'][j] == d['solution'][j],
  ).every((v) => v)) {
    d['outcome'] = 'won';
    d['reason'] = 'solved';
  }
  return true;
}
