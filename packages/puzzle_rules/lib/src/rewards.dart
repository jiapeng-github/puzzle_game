part of '../puzzle_rules.dart';

String shanghaiWeek(DateTime utc) {
  final local = utc.toUtc().add(const Duration(hours: 8));
  final monday = DateTime.utc(
    local.year,
    local.month,
    local.day,
  ).subtract(Duration(days: local.weekday - 1));
  return monday.toIso8601String().substring(0, 10);
}

class Settlement {
  final RuleState state;
  final int durationMs;
  final DateTime endedAt;
  Settlement(this.state, this.durationMs, DateTime endedAt)
    : endedAt = endedAt.toUtc() {
    if (!state.terminal || durationMs < 0) throw StateError('尚未形成有效终局');
    if (!['won', 'lost', 'draw', 'abandoned'].contains(state.outcome)) {
      throw StateError('终局类型无效');
    }
    final d = state.data;
    for (final key in [
      'moves',
      'hints',
      'score',
      'highest',
      'left',
      'maxChain',
      'errors',
      'pairsFound',
      'rolls',
    ]) {
      if (d.containsKey(key) && (d[key] is! int || (d[key] as int) < 0)) {
        throw StateError('终局指标无效：$key');
      }
    }
    if (d['hints'] > 3) throw StateError('提示次数无效');
    if (state.config.game == Game.match3 &&
        (d['left'] > 50 || d['moves'] > 50)) {
      throw StateError('步数无效');
    }
    if (state.config.game == Game.memory &&
        d['pairsFound'] > state.config.pairs) {
      throw StateError('配对数无效');
    }
    if (state.config.game == Game.gobang && d['moves'] > 225) {
      throw StateError('落子数无效');
    }
  }
  List<Json> get results {
    final c = state.config, d = state.data;
    final metrics = <String, dynamic>{'moves': d['moves'], 'hints': d['hints']};
    for (final key in [
      'score',
      'highest',
      'left',
      'maxChain',
      'errors',
      'pairsFound',
      'rolls',
      'actions',
      'collisions',
      'boosts',
      'blocks',
      'meteors',
    ]) {
      if (d.containsKey(key)) metrics[key] = d[key];
    }
    if (c.game == Game.sudoku) {
      metrics['independentCells'] = List.generate(
        81,
        (i) =>
            d['puzzle'][i] == 0 &&
            d['board'][i] == d['solution'][i] &&
            !(d['hinted'] as List).contains(i),
      ).where((v) => v).length;
    }
    final results = <Json>[];
    for (var seat = 0; seat < c.players.length; seat++) {
      var outcome = state.outcome!;
      if (outcome == 'won' &&
          (c.game == Game.gobang || c.game == Game.flying)) {
        final winner = d['winner'] as int;
        outcome = (c.game == Game.gobang ? seat == winner - 1 : seat == winner)
            ? 'won'
            : 'lost';
      }
      final breakdown = <String, int>{};
      void add(String label, int points) {
        breakdown[label] = points;
      }

      if (c.players[seat] != null && outcome != 'abandoned') {
        switch (c.game) {
          case Game.gobang:
            if (outcome == 'won') {
              add('对弈获胜', c.mode == 'local' ? 20 : [10, 20, 30][c.difficulty]);
            }
            if (outcome == 'draw') add('势均力敌', 5);
          case Game.game2048:
            final highest = d['highest'] as int;
            if (highest >= 128) {
              final tier = highest >= 2048
                  ? 2048
                  : highest >= 1024
                  ? 1024
                  : highest >= 512
                  ? 512
                  : 128;
              add('达到$tier档', {128: 10, 512: 20, 1024: 35, 2048: 50}[tier]!);
            }
          case Game.match3:
            if (outcome == 'won') {
              add('完成挑战', 20);
              if (d['left'] >= 10) add('剩余步数奖励', 5);
              if (d['maxChain'] >= 3) add('连锁奖励', 5);
            }
          case Game.flying:
            if (outcome == 'won') add('率先全部到达', 40);
          case Game.sudoku:
            if (outcome == 'won') {
              add('完成题目', [20, 30, 40][c.difficulty]);
              if (!state.assisted) {
                add('未使用提示', 10);
                if (d['errors'] == 0) add('无提示且零错误', 10);
              }
            }
          case Game.memory:
            if (outcome == 'won') {
              add('完成配对', {6: 10, 8: 15, 12: 20}[c.pairs]!);
              if (d['moves'] <= c.pairs + 2) add('细心配对奖励', 5);
            }
        }
      }
      final eligible =
          state.started &&
          outcome != 'abandoned' &&
          ([Game.gobang, Game.flying, Game.game2048].contains(c.game) ||
              outcome == 'won');
      results.add({
        'seat': seat,
        'player': c.players[seat],
        'outcome': outcome,
        'reason': d['reason'],
        'metrics': {
          ...metrics,
          if (c.game == Game.gobang) 'color': seat + 1,
          if (c.game == Game.flying)
            'finished': ints(d['planes'][seat]).where((p) => p == 54).length,
        },
        'rawScore': d['score'],
        'assisted': state.assisted,
        'eligible': eligible,
        'reward': breakdown.values.fold(0, (a, b) => a + b),
        'breakdown': breakdown,
      });
    }
    return results;
  }

  Json toJson() => {
    'rules': rulesVersion,
    'policy': rewardVersion,
    'config': state.config.toJson(),
    'revision': state.revision,
    'durationMs': durationMs,
    'endedAt': endedAt.toIso8601String(),
    'started': state.started,
    'results': results,
  };
}

/// Comparators return zero for actual competitive ties; stable display ordering
/// is applied afterwards and never changes the assigned rank.
int comparePerformance(Game game, Json a, Json b) {
  final am = a['metrics'] as Map, bm = b['metrics'] as Map;
  int asc(num x, num y) => x.compareTo(y);
  int desc(num x, num y) => y.compareTo(x);
  switch (game) {
    case Game.gobang:
    case Game.flying:
      return desc(a['wins'], b['wins']);
    case Game.game2048:
      final n = desc(am['score'], bm['score']);
      return n != 0 ? n : desc(am['highest'], bm['highest']);
    case Game.match3:
      final n = desc(am['score'], bm['score']);
      return n != 0 ? n : desc(am['left'], bm['left']);
    case Game.sudoku:
      final n = asc(a['durationMs'], b['durationMs']);
      return n != 0 ? n : asc(am['errors'], bm['errors']);
    case Game.memory:
      final n = asc(am['moves'], bm['moves']);
      return n != 0 ? n : asc(a['durationMs'], b['durationMs']);
  }
}

List<Json> gameRanking(
  List<Json> records,
  GameConfig filter, {
  bool assisted = false,
}) {
  bool matches(Json r) {
    final c = GameConfig.fromJson(r['config']);
    if (c.game != filter.game ||
        r['eligible'] != true ||
        r['rules'] != rulesVersion) {
      return false;
    }
    if ([Game.gobang, Game.match3, Game.sudoku].contains(c.game) &&
        r['assisted'] != assisted) {
      return false;
    }
    return switch (c.game) {
      Game.gobang =>
        c.mode == filter.mode &&
            (c.mode == 'local' || c.difficulty == filter.difficulty),
      Game.sudoku => c.difficulty == filter.difficulty,
      Game.memory => c.pairs == filter.pairs,
      Game.flying =>
        c.mode == filter.mode &&
            c.players.whereType<String>().length ==
                filter.players.whereType<String>().length,
      _ => true,
    };
  }

  final rows = <Json>[];
  for (final role in roles) {
    final games = records
        .where((r) => r['player'] == role && matches(r))
        .toList();
    if (games.isEmpty) {
      rows.add({'player': role, 'missing': true});
      continue;
    }
    if ([Game.gobang, Game.flying].contains(filter.game)) {
      rows.add({
        'player': role,
        'wins': games.where((r) => r['outcome'] == 'won').length,
        'completed': games.length,
        'metrics': <String, dynamic>{},
      });
    } else {
      games.sort((a, b) => comparePerformance(filter.game, a, b));
      rows.add({...games.first, 'player': role});
    }
  }
  rows.sort((a, b) {
    if (a['missing'] == true) {
      return b['missing'] == true
          ? roles.indexOf(a['player']).compareTo(roles.indexOf(b['player']))
          : 1;
    }
    if (b['missing'] == true) return -1;
    final n = comparePerformance(filter.game, a, b);
    return n != 0
        ? n
        : roles.indexOf(a['player']).compareTo(roles.indexOf(b['player']));
  });
  var rank = 0;
  for (var i = 0; i < rows.length; i++) {
    if (rows[i]['missing'] == true) {
      rows[i]['rank'] = null;
      continue;
    }
    if (i == 0 || comparePerformance(filter.game, rows[i - 1], rows[i]) != 0) {
      rank = i + 1;
    }
    rows[i]['rank'] = rank;
  }
  return rows;
}
