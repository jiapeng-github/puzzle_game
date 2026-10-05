part of '../puzzle_rules.dart';

void _spawn2048(Json d, SeededRandom rng) {
  final b = d['board'] as List;
  final empty = [
    for (var i = 0; i < 16; i++)
      if (b[i] == 0) i,
  ];
  if (empty.isEmpty) return;
  b[empty[rng.next(empty.length)]] = rng.next(10) == 0 ? 4 : 2;
  d['highest'] = ints(b).reduce(math.max);
}

/// Pure line merge used by all four directions. New tiles cannot merge twice.
({List<int> line, int score}) mergeLine(List<int> line) {
  final nonzero = line.where((v) => v != 0).toList(), out = <int>[];
  var score = 0;
  for (var i = 0; i < nonzero.length; i++) {
    if (i + 1 < nonzero.length && nonzero[i] == nonzero[i + 1]) {
      out.add(nonzero[i] * 2);
      score += nonzero[i] * 2;
      i++;
    } else {
      out.add(nonzero[i]);
    }
  }
  while (out.length < line.length) {
    out.add(0);
  }
  return (line: out, score: score);
}

bool _step2048(Json d, String cmd, Json a, SeededRandom rng) {
  if (cmd == 'dismissMilestone' && d['milestonePending'] == true) {
    d['milestonePending'] = false;
    return true;
  }
  if (cmd == 'finish' && d['milestone'] == true) {
    d['outcome'] = 'won';
    d['reason'] = 'target';
    return true;
  }
  if (cmd != 'move' ||
      d['milestonePending'] == true ||
      !['left', 'right', 'up', 'down'].contains(a['direction'])) {
    return false;
  }
  final b = ints(d['board']), old = b.join(',');
  var score = 0;
  final dir = a['direction'];
  for (var r = 0; r < 4; r++) {
    final ids = List.generate(
      4,
      (i) => switch (dir) {
        'left' => r * 4 + i,
        'right' => r * 4 + 3 - i,
        'up' => i * 4 + r,
        _ => (3 - i) * 4 + r,
      },
    );
    final merged = mergeLine(ids.map((i) => b[i]).toList());
    score += merged.score;
    for (var i = 0; i < 4; i++) {
      b[ids[i]] = merged.line[i];
    }
  }
  if (b.join(',') == old) return false;
  d['board'] = b;
  d['score'] += score;
  d['moves']++;
  _spawn2048(d, rng);
  if (d['highest'] >= 2048 && d['milestone'] == false) {
    d['milestone'] = true;
    d['milestonePending'] = true;
  }
  final live =
      b.contains(0) ||
      List.generate(
        16,
        (i) => (i % 4 < 3 && b[i] == b[i + 1]) || (i < 12 && b[i] == b[i + 4]),
      ).any((v) => v);
  if (!live) {
    d['outcome'] = d['milestone'] == true ? 'won' : 'lost';
    d['reason'] = 'noMoves';
    d['milestonePending'] = false;
  }
  d['event'] = 'move';
  return true;
}

bool gobangWins(List<int> b, int at, int color) {
  final r = at ~/ 15, c = at % 15;
  for (final (dr, dc) in [(1, 0), (0, 1), (1, 1), (1, -1)]) {
    var count = 1;
    for (final sign in [-1, 1]) {
      var nr = r + dr * sign, nc = c + dc * sign;
      while (nr >= 0 &&
          nr < 15 &&
          nc >= 0 &&
          nc < 15 &&
          b[nr * 15 + nc] == color) {
        count++;
        nr += dr * sign;
        nc += dc * sign;
      }
    }
    if (count >= 5) return true;
  }
  return false;
}

bool _stepGobang(Json d, GameConfig c, String cmd, Json a) {
  final b = ints(d['board']), history = ints(d['history']);
  if (cmd == 'resign' && d['started'] == true && a['color'] == d['turn']) {
    d['winner'] = 3 - (a['color'] as int);
    d['outcome'] = 'won';
    d['reason'] = 'resigned';
    return true;
  }
  if (cmd == 'hint' &&
      c.mode == 'ai' &&
      d['turn'] == c.humanColor &&
      d['hints'] < 3) {
    final i = a['index'] as int? ?? -1;
    if (i < 0 || i >= 225 || b[i] != 0) return false;
    d['hints']++;
    d['hint'] = i;
    d['assisted'] = true;
    return true;
  }
  if (cmd == 'undo') {
    if (history.isEmpty) return false;
    final undos = ints(d['undos']);
    int owner, count;
    if (c.mode == 'ai') {
      owner = c.humanColor - 1;
      count = 2;
      if (d['turn'] != c.humanColor ||
          history.length < 2 ||
          b[history[history.length - 2]] != c.humanColor) {
        return false;
      }
    } else {
      owner = b[history.last] - 1;
      count = 1;
      if (a['approved'] != true || a['requester'] != owner) return false;
    }
    if (undos[owner] >= 1) return false;
    for (var k = 0; k < count; k++) {
      b[history.removeLast()] = 0;
    }
    undos[owner]++;
    d.addAll({
      'board': b,
      'history': history,
      'turn': owner + 1,
      'undos': undos,
      'hint': -1,
      'assisted': true,
      'moves': history.length,
    });
    return true;
  }
  final i = a['index'] as int? ?? -1;
  if (cmd != 'place' ||
      i < 0 ||
      i >= 225 ||
      b[i] != 0 ||
      a['color'] != d['turn']) {
    return false;
  }
  final color = d['turn'] as int;
  b[i] = color;
  history.add(i);
  d.addAll({
    'board': b,
    'history': history,
    'hint': -1,
    'moves': history.length,
    'event': 'piece',
  });
  if (gobangWins(b, i, color)) {
    d['winner'] = color;
    d['outcome'] = 'won';
    d['reason'] = 'five';
  } else if (!b.contains(0)) {
    d['outcome'] = 'draw';
    d['reason'] = 'full';
  } else {
    d['turn'] = 3 - color;
  }
  return true;
}

/// Work-budgeted iterative alpha-beta; run by an application isolate. No clock or
/// framework dependency. The budget bounds computation even on slow devices.
int chooseGobangMove(
  RuleState state, {
  int budget = 18000,
  bool Function()? shouldStop,
}) {
  final b = ints(state.data['board']), color = state.data['turn'] as int;
  List<int> candidates() {
    final all = [
      for (var i = 0; i < 225; i++)
        if (b[i] == 0) i,
    ];
    if (all.length == 225) return [112];
    return all.where((i) {
      for (var dr = -2; dr <= 2; dr++) {
        for (var dc = -2; dc <= 2; dc++) {
          final r = i ~/ 15 + dr, c = i % 15 + dc;
          if (r >= 0 && r < 15 && c >= 0 && c < 15 && b[r * 15 + c] != 0) {
            return true;
          }
        }
      }
      return false;
    }).toList();
  }

  final cs = candidates();
  if (cs.isEmpty) return -1;
  for (final who in [color, 3 - color]) {
    for (final i in cs) {
      b[i] = who;
      final win = gobangWins(b, i, who);
      b[i] = 0;
      if (win) return i;
    }
  }
  if (state.config.difficulty == 0) {
    return cs[SeededRandom(state.rng + state.revision).next(cs.length)];
  }
  int value(int at, int who) {
    var total = 0;
    for (final (dr, dc) in [(1, 0), (0, 1), (1, 1), (1, -1)]) {
      var count = 1, open = 0;
      for (final sign in [-1, 1]) {
        var r = at ~/ 15 + dr * sign, c = at % 15 + dc * sign;
        while (r >= 0 && r < 15 && c >= 0 && c < 15 && b[r * 15 + c] == who) {
          count++;
          r += dr * sign;
          c += dc * sign;
        }
        if (r >= 0 && r < 15 && c >= 0 && c < 15 && b[r * 15 + c] == 0) open++;
      }
      total += count >= 5
          ? 100000
          : (open == 0 ? 0 : ([0, 2, 20, 200, 4000][count] * open));
    }
    return total;
  }

  int score(int i, int who) => value(i, who) * 11 + value(i, 3 - who) * 10;
  cs.sort((a, b) => score(b, color).compareTo(score(a, color)));
  if (state.config.difficulty == 1) return cs.first;
  var visited = 0;
  int search(int depth, int who, int alpha, int beta) {
    if (++visited > budget || (shouldStop?.call() ?? false)) {
      throw const _SearchBudget();
    }
    final nodes = candidates()
      ..sort((a, b) => score(b, who).compareTo(score(a, who)));
    if (nodes.isEmpty) return 0;
    if (depth == 0) {
      return score(nodes.first, who) - score(nodes.first, 3 - who);
    }
    var best = -10000000;
    for (final i in nodes.take(8)) {
      b[i] = who;
      int result;
      try {
        result = gobangWins(b, i, who)
            ? 1000000 + depth
            : -search(depth - 1, 3 - who, -beta, -alpha);
      } finally {
        b[i] = 0;
      }
      best = math.max(best, result);
      alpha = math.max(alpha, best);
      if (alpha >= beta) break;
    }
    return best;
  }

  var best = cs.first;
  for (var depth = 1; depth <= 5; depth++) {
    var next = best, top = -10000000;
    try {
      for (final i in cs.take(10)) {
        b[i] = color;
        int result;
        try {
          result = -search(depth - 1, 3 - color, -10000000, 10000000);
        } finally {
          b[i] = 0;
        }
        if (result > top) {
          top = result;
          next = i;
        }
      }
    } on _SearchBudget {
      break;
    }
    best = next;
  }
  return best;
}

class _SearchBudget {
  const _SearchBudget();
}

bool _stepMemory(Json d, GameConfig c, String cmd, Json a) {
  final open = ints(d['open']), matched = ints(d['matched']);
  if (cmd == 'tick' && d['remainingMs'] > 0) {
    final ms = a['ms'] as int? ?? 0;
    if (ms <= 0) return false;
    d['remainingMs'] = math.max(0, (d['remainingMs'] as int) - ms);
    if (d['remainingMs'] == 0) d['open'] = <int>[];
    return true;
  }
  final i = a['index'] as int? ?? -1;
  if (cmd != 'flip' ||
      i < 0 ||
      i >= c.pairs * 2 ||
      open.length >= 2 ||
      matched.contains(i) ||
      open.contains(i)) {
    return false;
  }
  open.add(i);
  d['open'] = open;
  d['event'] = 'turn';
  if (open.length == 2) {
    d['moves']++;
    if (d['board'][open[0]] == d['board'][open[1]]) {
      matched.addAll(open);
      d['matched'] = matched;
      d['open'] = <int>[];
      d['pairsFound']++;
      d['event'] = 'right';
      if (d['pairsFound'] == c.pairs) {
        d['outcome'] = 'won';
        d['reason'] = 'allPairs';
      }
    } else {
      d['remainingMs'] = 800;
    }
  }
  return true;
}

const flightStarts = [29, 41, 17, 5];
const accelerators = [2, 8, 14, 20, 26, 32, 38, 44];
const shieldCells = [0, 12, 24, 36];
const meteorCells = [6, 18, 30, 42];
List<int> legalPlanes(Json d) {
  final dice = d['dice'] as int, row = ints(d['planes'][d['turn']]);
  if (dice == 0) return [];
  return [
    for (var i = 0; i < 4; i++)
      if (row[i] == -1 ? dice == 6 : row[i] < 54 && row[i] + dice <= 54) i,
  ];
}

void _nextFlight(Json d) {
  d['turn'] = ((d['turn'] as int) + 1) % 4;
  d['dice'] = 0;
}

bool _stepFlying(
  Json d,
  GameConfig config,
  String cmd,
  Json a,
  SeededRandom rng,
) {
  final turn = d['turn'] as int;
  if (cmd == 'roll' && d['dice'] == 0) {
    final row = ints(d['planes'][turn]), misses = ints(d['misses']);
    final grounded = !row.any((p) => p >= 0 && p < 54) && row.contains(-1);
    final dice = grounded && misses[turn] >= 3 ? 6 : 1 + rng.next(6);
    misses[turn] = grounded && dice != 6 ? misses[turn] + 1 : 0;
    d.addAll({
      'dice': dice,
      'misses': misses,
      'rolls': d['rolls'] + 1,
      'rollId': d['rollId'] + 1,
      'event': 'dice',
      'lastRoll': dice,
      'flightEvents': <Json>[
        {'kind': 'roll', 'seat': turn, 'value': dice},
      ],
    });
    if (legalPlanes(d).isEmpty) {
      (d['flightEvents'] as List).add({'kind': 'noMove', 'seat': turn});
      _nextFlight(d);
    }
    return true;
  }
  final i = a['plane'] as int? ?? -1;
  if (cmd != 'fly' ||
      a['seat'] != turn ||
      a['rollId'] != d['rollId'] ||
      !legalPlanes(d).contains(i)) {
    return false;
  }
  final planes = (d['planes'] as List).map(ints).toList(),
      old = planes[turn][i],
      dice = d['dice'] as int;
  final adventure = config.mode == 'adventure';
  final shields = d['shields'] == null
      ? List.generate(4, (_) => List.filled(4, 0))
      : (d['shields'] as List).map(ints).toList();
  final boosts = ints(d['boosts'] ?? [0, 0, 0, 0]);
  final blocks = ints(d['blocks'] ?? [0, 0, 0, 0]);
  final meteors = ints(d['meteors'] ?? [0, 0, 0, 0]);
  final events = <Json>[];
  void event(String kind, {int? seat, int? plane}) =>
      events.add({'kind': kind, 'seat': seat ?? turn, 'plane': plane ?? i});
  var p = old == -1 ? 0 : old + dice;
  final landing = (flightStarts[turn] + p) % 48;
  // Trigger exactly one event at the original dice landing; never recurse.
  if (old != -1 && p < 48) {
    if (accelerators.contains(landing)) {
      p = math.min(48, p + 3);
      boosts[turn]++;
      event('boost');
    } else if (adventure && shieldCells.contains(landing)) {
      shields[turn][i] = 1;
      event('shield');
    } else if (adventure && meteorCells.contains(landing)) {
      meteors[turn]++;
      if (shields[turn][i] > 0) {
        shields[turn][i] = 0;
        blocks[turn]++;
        event('meteorBlocked');
      } else {
        p = math.max(0, p - 3);
        event('meteor');
      }
    }
  }
  planes[turn][i] = p;
  final collisions = ints(d['collisions']);
  if (p <= 48) {
    final at = (flightStarts[turn] + p) % 48;
    if (!flightStarts.contains(at)) {
      for (var team = 0; team < 4; team++) {
        if (team == turn) continue;
        for (var j = 0; j < 4; j++) {
          final q = planes[team][j];
          if (q >= 0 && q <= 48 && (flightStarts[team] + q) % 48 == at) {
            if (adventure && shields[team][j] > 0) {
              shields[team][j] = 0;
              blocks[team]++;
              event('collisionBlocked', seat: team, plane: j);
            } else {
              planes[team][j] = -1;
              shields[team][j] = 0;
              collisions[turn]++;
              event('collision', seat: team, plane: j);
            }
          }
        }
      }
    }
  }
  if (events.isEmpty) {
    event(
      p == 54
          ? 'home'
          : old == -1
          ? 'takeoff'
          : 'move',
    );
  }
  d.addAll({
    'shields': shields,
    'boosts': boosts,
    'blocks': blocks,
    'meteors': meteors,
    'flightEvents': events,
  });
  final actions = ints(d['actions']);
  actions[turn]++;
  d.addAll({
    'planes': planes,
    'collisions': collisions,
    'actions': actions,
    'moves': d['moves'] + 1,
    'event': 'plane',
  });
  if (planes[turn].every((p) => p == 54)) {
    d['winner'] = turn;
    d['outcome'] = 'won';
    d['reason'] = 'allHome';
    d['dice'] = 0;
  } else if (dice == 6) {
    d['dice'] = 0;
  } else {
    _nextFlight(d);
  }
  return true;
}

int choosePlane(RuleState s) {
  final d = s.data, options = legalPlanes(d);
  if (options.isEmpty) return -1;
  final turn = d['turn'] as int;
  int score(int i) {
    // Evaluate the same transition as a human move, including shields/meteor.
    final next = copyJson(d);
    _stepFlying(next, s.config, 'fly', {
      'seat': turn,
      'plane': i,
      'rollId': d['rollId'],
    }, SeededRandom(s.rng));
    final p = next['planes'][turn][i] as int;
    final shield = next['shields'][turn][i] as int;
    var score = p == 54 ? 10000 : p * 4 + (d['planes'][turn][i] == -1 ? 30 : 0);
    score +=
        ((next['collisions'][turn] as int) - (d['collisions'][turn] as int)) *
        300;
    score += shield * 45;
    final at = (flightStarts[turn] + p) % 48;
    if (p <= 48 && !flightStarts.contains(at) && shield == 0) {
      for (var t = 0; t < 4; t++) {
        if (t == turn) continue;
        for (final q in ints(next['planes'][t])) {
          if (q < 0 || q > 48) continue;
          final gap = (at - (flightStarts[t] + q) + 48) % 48;
          if (gap > 0 && gap <= 6) score -= 20;
        }
      }
    }
    return score;
  }

  options.sort((a, b) => score(b).compareTo(score(a)));
  final best = score(options.first);
  final ties = options.where((i) => score(i) == best).toList();
  return ties[SeededRandom(s.rng + s.revision).next(ties.length)];
}
