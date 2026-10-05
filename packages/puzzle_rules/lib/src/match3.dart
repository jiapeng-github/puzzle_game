part of '../puzzle_rules.dart';

List<Set<int>> matchLines(List<int> b) {
  final lines = <Set<int>>[];
  for (var direction = 0; direction < 2; direction++) {
    for (var row = 0; row < 8; row++) {
      var start = 0;
      while (start < 8) {
        var end = start + 1;
        int at(int x) => direction == 0 ? row * 8 + x : x * 8 + row;
        while (end < 8 &&
            b[at(start)] >= 0 &&
            b[at(start)] % 6 == b[at(end)] % 6) {
          end++;
        }
        if (end - start >= 3) {
          lines.add({for (var i = start; i < end; i++) at(i)});
        }
        start = end;
      }
    }
  }
  return lines;
}

List<int>? matchHint(List<int> board) {
  final b = List<int>.from(board);
  for (var i = 0; i < 64; i++) {
    for (final j in [if (i % 8 < 7) i + 1, if (i < 56) i + 8]) {
      final temp = b[i];
      b[i] = b[j];
      b[j] = temp;
      final valid = matchLines(
        b,
      ).any((line) => line.contains(i) || line.contains(j));
      b[j] = b[i];
      b[i] = temp;
      if (valid) return [i, j];
    }
  }
  return null;
}

List<int> _freshMatch(SeededRandom rng) {
  for (var attempt = 0; attempt < 100; attempt++) {
    final b = <int>[];
    for (var i = 0; i < 64; i++) {
      final allowed = [
        for (var c = 0; c < 6; c++)
          if (!(i % 8 >= 2 && b[i - 1] == c && b[i - 2] == c) &&
              !(i >= 16 && b[i - 8] == c && b[i - 16] == c))
            c,
      ];
      b.add(allowed[rng.next(allowed.length)]);
    }
    if (matchHint(b) != null) return b;
  }
  // No initial matches; swapping (0,1) makes the first column 1,1,1.
  final b = List.generate(64, (i) => (i ~/ 8 + i % 8) % 6);
  b[0] = 2;
  b[1] = 1;
  b[8] = 1;
  b[16] = 1;
  if (matchLines(b).isNotEmpty || matchHint(b) == null) {
    throw StateError('保底盘面校验失败');
  }
  return b;
}

bool _stepMatch(Json d, String cmd, Json a, SeededRandom rng) {
  final b = ints(d['board']);
  if (cmd == 'hint' && d['hints'] < 3) {
    final hint = matchHint(b);
    if (hint == null) return false;
    d['hints']++;
    d['assisted'] = true;
    d['hint'] = hint;
    return true;
  }
  final i = a['from'] as int? ?? -1, j = a['to'] as int? ?? -1;
  if (cmd != 'swap' ||
      i < 0 ||
      j < 0 ||
      i >= 64 ||
      j >= 64 ||
      ((i ~/ 8 - j ~/ 8).abs() + (i % 8 - j % 8).abs() != 1)) {
    return false;
  }
  final v = b[i];
  b[i] = b[j];
  b[j] = v;
  var lines = matchLines(b);
  if (!lines.any((line) => line.contains(i) || line.contains(j))) return false;
  d['left']--;
  d['moves']++;
  d['hint'] = <int>[];
  var round = 0;
  while (lines.isNotEmpty) {
    if (++round > 100) throw StateError('连锁校验未完成，请重试或恢复存档');
    final components = <Set<int>>[];
    for (final line in lines) {
      final merged = Set<int>.from(line);
      for (var k = components.length - 1; k >= 0; k--) {
        if (components[k].intersection(merged).isNotEmpty) {
          merged.addAll(components.removeAt(k));
        }
      }
      components.add(merged);
    }
    final spawn = <int>{};
    for (final group in components) {
      if (!lines.any(
            (l) => l.intersection(group).isNotEmpty && l.length >= 4,
          ) &&
          group.length < 5) {
        continue;
      }
      final candidates = [j, i, ...(group.toList()..sort())];
      for (final at in candidates) {
        if (group.contains(at) && b[at] < 6) {
          spawn.add(at);
          break;
        }
      }
    }
    final clear = lines.expand((e) => e).toSet(),
        blast = <int>{},
        queue = <int>[
          for (final k in lines.expand((e) => e).toSet())
            if (b[k] >= 6) k,
        ],
        exploded = <int>{};
    while (queue.isNotEmpty) {
      final at = queue.removeLast();
      if (!exploded.add(at)) continue;
      for (var dr = -1; dr <= 1; dr++) {
        for (var dc = -1; dc <= 1; dc++) {
          final r = at ~/ 8 + dr, c = at % 8 + dc;
          if (r < 0 || r >= 8 || c < 0 || c >= 8) continue;
          final k = r * 8 + c;
          blast.add(k);
          clear.add(k);
          if (b[k] >= 6 && !exploded.contains(k)) queue.add(k);
        }
      }
    }
    spawn.removeWhere(blast.contains);
    clear.removeAll(spawn);
    final multiplier = round == 1
        ? 10
        : round == 2
        ? 12
        : round == 3
        ? 15
        : 20;
    d['score'] +=
        ((clear.length * 10 + exploded.length * 20) * multiplier + 5) ~/ 10;
    for (final k in clear) {
      b[k] = -1;
    }
    for (final k in spawn) {
      b[k] = b[k] % 6 + 6;
    }
    for (var c = 0; c < 8; c++) {
      final col = [
        for (var r = 7; r >= 0; r--)
          if (b[r * 8 + c] >= 0) b[r * 8 + c],
      ];
      while (col.length < 8) {
        col.add(rng.next(6));
      }
      for (var r = 7; r >= 0; r--) {
        b[r * 8 + c] = col[7 - r];
      }
    }
    lines = matchLines(b);
  }
  d['chain'] = round;
  d['maxChain'] = math.max(d['maxChain'] as int, round);
  d['event'] = 'eliminate';
  if (d['score'] >= 2000) {
    d['outcome'] = 'won';
    d['reason'] = 'target';
  } else if (d['left'] == 0) {
    d['outcome'] = 'lost';
    d['reason'] = 'noMoves';
  } else if (matchHint(b) == null) {
    var done = false;
    for (var attempt = 0; attempt < 100; attempt++) {
      rng.shuffle(b);
      if (matchLines(b).isEmpty && matchHint(b) != null) {
        done = true;
        break;
      }
    }
    if (!done) {
      final fresh = _freshMatch(rng);
      b.setAll(0, fresh);
    }
    d['event'] = 'shuffle';
  }
  d['board'] = b;
  return true;
}
