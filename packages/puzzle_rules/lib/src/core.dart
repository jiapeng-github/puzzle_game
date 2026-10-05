part of '../puzzle_rules.dart';

typedef Json = Map<String, dynamic>;
const rulesVersion = 'rules-v2.0';
const rewardVersion = 'rewards-v2.0';
const roles = ['boy', 'girl', 'dad', 'mom', 'grandpa', 'grandma'];
const roleNames = ['男孩', '女孩', '爸爸', '妈妈', '爷爷', '奶奶'];

enum Game { gobang, game2048, match3, flying, sudoku, memory }

const gameNames = ['五子棋', '2048', '消消乐', '飞行棋', '数独', '记忆翻牌'];

/// A reproducible PRNG. Its entire state is included in every snapshot.
class SeededRandom {
  int state;
  SeededRandom(int seed) : state = seed & 0xffffffff;
  int next(int max) {
    if (max <= 0) throw ArgumentError.value(max);
    state = (1664525 * state + 1013904223) & 0xffffffff;
    return (state >> 8) % max;
  }

  void shuffle<T>(List<T> values) {
    for (var i = values.length - 1; i > 0; i--) {
      final j = next(i + 1), value = values[i];
      values[i] = values[j];
      values[j] = value;
    }
  }
}

dynamic _freeze(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      value.map((k, v) => MapEntry(k.toString(), _freeze(v))),
    );
  }
  if (value is List) return List<dynamic>.unmodifiable(value.map(_freeze));
  return value;
}

Json copyJson(Json value) => jsonDecode(jsonEncode(value)) as Json;
List<int> ints(dynamic value) => List<int>.from(value as List);

class GameConfig {
  final Game game;
  final int difficulty, pairs, humanColor;
  final String mode, theme;
  final List<String?> players;
  GameConfig({
    required this.game,
    this.difficulty = 1,
    this.pairs = 8,
    this.humanColor = 1,
    this.mode = 'standard',
    this.theme = 'animals',
    List<String?> players = const ['boy'],
  }) : players = List.unmodifiable(players) {
    final humans = players.whereType<String>().toList();
    if (humans.isEmpty ||
        humans.toSet().length != humans.length ||
        humans.any((p) => !roles.contains(p))) {
      throw ArgumentError('角色配置无效');
    }
    if (difficulty < 0 ||
        difficulty > 2 ||
        ![6, 8, 12].contains(pairs) ||
        ![1, 2].contains(humanColor)) {
      throw ArgumentError('难度配置无效');
    }
    if (game == Game.flying && !['standard', 'adventure'].contains(mode)) {
      throw ArgumentError('飞行棋模式无效');
    }
    if (game == Game.flying && players.length != 4) {
      throw ArgumentError('航线需要四个座位');
    }
    if (game == Game.gobang &&
        (players.length != 2 ||
            !['ai', 'local'].contains(mode) ||
            (mode == 'local' && humans.length != 2) ||
            (mode == 'ai' && humans.length != 1))) {
      throw ArgumentError('五子棋座位配置无效');
    }
    if (game != Game.gobang && game != Game.flying && players.length != 1) {
      throw ArgumentError('单人游戏');
    }
  }
  Json toJson() => {
    'game': game.name,
    'difficulty': difficulty,
    'pairs': pairs,
    'humanColor': humanColor,
    'mode': mode,
    'theme': theme,
    'players': players,
  };
  factory GameConfig.fromJson(Json j) => GameConfig(
    game: Game.values.byName(j['game']),
    difficulty: j['difficulty'],
    pairs: j['pairs'],
    humanColor: j['humanColor'],
    mode: j['mode'],
    theme: j['theme'],
    players: List<String?>.from(j['players']),
  );
}

class RuleState {
  final GameConfig config;
  final Json data;
  final int rng, revision;
  RuleState(this.config, Json data, this.rng, [this.revision = 0])
    : data = _freeze(data) as Json;
  bool get terminal => data['outcome'] != null;
  bool get started => data['started'] == true;
  bool get assisted => data['assisted'] == true;
  String? get outcome => data['outcome'] as String?;
  Json toJson() => {
    'version': rulesVersion,
    'config': config.toJson(),
    'data': data,
    'rng': rng,
    'revision': revision,
  };
  factory RuleState.fromJson(Json j) {
    if (j['version'] != rulesVersion) throw StateError('此存档的规则版本不受支持');
    return RuleState(
      GameConfig.fromJson(j['config']),
      j['data'],
      j['rng'],
      j['revision'],
    );
  }
}

class Transition {
  final RuleState state;
  final bool accepted;
  final String? event;
  const Transition(this.state, this.accepted, [this.event]);
}

class Rules {
  static RuleState create(GameConfig c, int seed) {
    final rng = SeededRandom(seed);
    final d = <String, dynamic>{
      'started': false,
      'assisted': false,
      'moves': 0,
      'hints': 0,
    };
    switch (c.game) {
      case Game.game2048:
        d.addAll({
          'board': List.filled(16, 0),
          'score': 0,
          'highest': 2,
          'milestone': false,
          'milestonePending': false,
        });
        _spawn2048(d, rng);
        _spawn2048(d, rng);
      case Game.gobang:
        d.addAll({
          'board': List.filled(225, 0),
          'turn': 1,
          'history': <int>[],
          'undos': [0, 0],
          'hint': -1,
        });
      case Game.memory:
        final cards = [
          for (var i = 0; i < c.pairs; i++) ...[i, i],
        ];
        rng.shuffle(cards);
        d.addAll({
          'board': cards,
          'matched': <int>[],
          'open': <int>[],
          'remainingMs': 0,
          'pairsFound': 0,
        });
      case Game.flying:
        d.addAll({
          'planes': List.generate(4, (_) => List.filled(4, -1)),
          'turn': rng.next(4),
          'dice': 0,
          'misses': [0, 0, 0, 0],
          'rolls': 0,
          'rollId': 0,
          'actions': [0, 0, 0, 0],
          'collisions': [0, 0, 0, 0],
          'shields': List.generate(4, (_) => List.filled(4, 0)),
          'boosts': [0, 0, 0, 0],
          'blocks': [0, 0, 0, 0],
          'meteors': [0, 0, 0, 0],
          'flightEvents': <Json>[],
        });
      case Game.match3:
        d.addAll({
          'board': _freshMatch(rng),
          'score': 0,
          'left': 50,
          'chain': 0,
          'maxChain': 0,
          'hint': <int>[],
        });
      case Game.sudoku:
        d.addAll(createSudoku(c.difficulty, rng));
    }
    return RuleState(c, d, rng.state);
  }

  /// Commands use revision to reject stale taps, AI replies and delayed callbacks.
  static Transition apply(
    RuleState s,
    String command,
    Json args, {
    required int revision,
  }) {
    if (s.terminal || revision != s.revision) return Transition(s, false);
    final d = copyJson(s.data), rng = SeededRandom(s.rng);
    // Events belong to this transition, never to a previous move or save.
    d.remove('event');
    if (command == 'abandon') {
      d['outcome'] = 'abandoned';
      d['reason'] = 'abandoned';
      return Transition(
        RuleState(s.config, d, rng.state, s.revision + 1),
        true,
      );
    }
    bool accepted;
    switch (s.config.game) {
      case Game.game2048:
        accepted = _step2048(d, command, args, rng);
      case Game.gobang:
        accepted = _stepGobang(d, s.config, command, args);
      case Game.memory:
        accepted = _stepMemory(d, s.config, command, args);
      case Game.flying:
        accepted = _stepFlying(d, s.config, command, args, rng);
      case Game.match3:
        accepted = _stepMatch(d, command, args, rng);
      case Game.sudoku:
        accepted = _stepSudoku(d, command, args);
    }
    if (!accepted) return Transition(s, false);
    if (!['tick', 'dismissMilestone'].contains(command)) d['started'] = true;
    return Transition(
      RuleState(s.config, d, rng.state, s.revision + 1),
      true,
      d['event'] as String?,
    );
  }
}
