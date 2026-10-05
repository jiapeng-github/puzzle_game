import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:puzzle_rules/puzzle_rules.dart';

import 'storage.dart';
import 'sound.dart';

class IslandModel extends ChangeNotifier {
  GameStore? store;
  String? error;
  bool loading = true;
  String role = 'boy';
  String? visibleSession;
  Json preferences = {};
  Map<Game, Session> saves = {};
  List<Json> records = [], weekly = [], total = [];
  Map<String, int> legacy = {};
  final Sound sound;
  IslandModel({this.store, bool audioEnabled = true, Sound? sound})
    : sound = sound ?? Sound(enabled: audioEnabled);
  bool get reducedMotion => preferences['reducedMotion'] == true;
  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      store ??= await GameStore.open();
      preferences = await store!.settings();
      role = preferences['role'] as String? ?? 'boy';
      if (!roles.contains(role)) role = 'boy';
      sound.configure(preferences);
      await refresh();
    } catch (e) {
      error = '无法打开本地数据：$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    saves = await store!.active();
    records = await store!.records();
    weekly = await store!.familyRanking(week: shanghaiWeek(DateTime.now()));
    total = await store!.familyRanking();
    legacy = await store!.legacyScores();
    notifyListeners();
  }

  Future<void> setting(String key, dynamic value) async {
    await store!.setSetting(key, value);
    preferences[key] = value;
    if (key == 'role') role = value as String;
    sound.configure(preferences);
    notifyListeners();
  }

  Future<Session> create(GameConfig config) async {
    final now = DateTime.now().toUtc(),
        seed = Random.secure().nextInt(0x7fffffff);
    final state = await compute(_create, {
      'config': config.toJson(),
      'seed': seed,
    });
    final session = Session(
      id: '${now.microsecondsSinceEpoch}-$seed',
      seed: seed,
      createdAt: now,
      state: RuleState.fromJson(state),
    );
    await store!.save(session);
    await refresh();
    return session;
  }

  Future<void> abandon(Session session) async {
    if (session.state.terminal) {
      await store!.settle(session);
      await refresh();
      return;
    }
    session.state = Rules.apply(
      session.state,
      'abandon',
      {},
      revision: session.state.revision,
    ).state;
    session.endedAt = DateTime.now().toUtc();
    await store!.save(session);
    await store!.settle(session);
    await refresh();
  }

  @override
  void dispose() {
    sound.dispose();
    super.dispose();
  }
}

Json _create(Json args) =>
    Rules.create(GameConfig.fromJson(args['config']), args['seed']).toJson();
int _gobang(Json state) {
  final watch = Stopwatch()..start();
  return chooseGobangMove(
    RuleState.fromJson(state),
    shouldStop: () => watch.elapsedMilliseconds >= 300,
  );
}

/// Owns time and async work; the rules package never imports Flutter or reads a
/// wall clock. Every delayed result is checked against revision and lifetime.
abstract interface class ActiveClock {
  int get elapsedMilliseconds;
  bool get isRunning;
  void start();
  void stop();
}

class MonotonicClock implements ActiveClock {
  final Stopwatch _watch = Stopwatch();
  @override
  int get elapsedMilliseconds => _watch.elapsedMilliseconds;
  @override
  bool get isRunning => _watch.isRunning;
  @override
  void start() => _watch.start();
  @override
  void stop() => _watch.stop();
}

class PlayController extends ChangeNotifier {
  final IslandModel model;
  final Session session;
  final ActiveClock clock;
  Timer? timer;
  bool paused = false,
      busy = false,
      thinking = false,
      disposed = false,
      saved = false;
  bool _awaitingSave = false;
  String? error;
  Json? receipt;
  int _last = 0, _checkpoint = 0, _memoryAt = 0, _generation = 0;
  PlayController(
    this.model,
    this.session, {
    bool resumed = false,
    ActiveClock? clock,
  }) : clock = clock ?? MonotonicClock() {
    paused = resumed && !session.state.terminal;
    _checkpoint = session.durationMs;
    _memoryAt = session.durationMs;
    if (session.state.started && !paused && !session.state.terminal) {
      this.clock.start();
    }
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    if (session.state.terminal) {
      Future.microtask(settle);
    } else {
      Future.microtask(_automate);
    }
  }
  RuleState get state => session.state;
  bool get canInput =>
      !paused && !busy && !thinking && !state.terminal && error == null;
  void _consume() {
    final now = clock.elapsedMilliseconds;
    session.durationMs += now - _last;
    _last = now;
  }

  void _notify() {
    if (!disposed) notifyListeners();
  }

  Future<void> command(String cmd, [Json args = const {}]) async {
    if (disposed || paused || busy || state.terminal || error != null) return;
    _consume();
    final before = state;
    try {
      final result = Rules.apply(before, cmd, args, revision: before.revision);
      if (!result.accepted) return;
      session.state = result.state;
      if (state.config.game == Game.memory) {
        if (cmd == 'flip' && state.data['remainingMs'] > 0) {
          _memoryAt = session.durationMs;
        }
        if (cmd == 'tick') _memoryAt += args['ms'] as int;
      }
      if (state.started && !clock.isRunning) clock.start();
      if (state.terminal) {
        model.sound.finish();
        clock.stop();
        _consume();
        session.endedAt ??= DateTime.now().toUtc();
      }
      if (state.data['milestonePending'] == true) {
        clock.stop();
        _consume();
      }
      if (cmd == 'dismissMilestone' && state.started) clock.start();
      busy = true;
      _awaitingSave = true;
      _notify();
      await model.store!.save(session);
      _awaitingSave = false;
      if (disposed) return;
      if (!paused && !state.terminal) model.sound.effect(result.event);
      if (state.terminal) {
        await _settleSaved();
      } else {
        _checkpoint = session.durationMs;
      }
    } catch (e) {
      clock.stop();
      _consume();
      error = '$e';
      paused = !state.terminal;
      if (paused) model.sound.suspend();
    } finally {
      busy = false;
      _notify();
    }
    if (!disposed && !state.terminal) unawaited(_automate());
  }

  Future<void> _tick() async {
    if (disposed || paused || state.terminal || !clock.isRunning) return;
    _consume();
    _notify();
    if (busy || thinking) return;
    if (state.config.game == Game.memory && state.data['remainingMs'] > 0) {
      // Clock deltas, not animation frames, consume the fixed observation wait.
      final remaining = state.data['remainingMs'] as int;
      final delta = session.durationMs - _memoryAt;
      if (delta > 0) await command('tick', {'ms': min(delta, remaining)});
    } else if (session.durationMs - _checkpoint >= 10000) {
      await checkpoint();
    }
  }

  Future<void> checkpoint() async {
    if (disposed || busy || saved) return;
    _consume();
    busy = true;
    _notify();
    try {
      await model.store!.save(session);
      _checkpoint = session.durationMs;
    } catch (e) {
      error = '存档失败：$e';
      paused = true;
      model.sound.suspend();
      clock.stop();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> pause() async {
    if (disposed) return;
    model.sound.suspend();
    if (saved) return;
    paused = true;
    _generation++;
    thinking = false;
    clock.stop();
    _consume();
    _notify();
    // A command already in progress writes its stable snapshot first.
    while (busy && !disposed) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    if (!disposed && !state.terminal) {
      if (state.config.game == Game.memory && state.data['remainingMs'] > 0) {
        final delta = session.durationMs - _memoryAt;
        if (delta > 0) {
          session.state = Rules.apply(state, 'tick', {
            'ms': delta,
          }, revision: state.revision).state;
        }
        _memoryAt = session.durationMs;
      }
      await checkpoint();
    }
  }

  Future<void> resume() async {
    if (disposed || error != null || busy || state.terminal) return;
    paused = false;
    if (state.started && state.data['milestonePending'] != true) clock.start();
    model.sound.game(state.config.game);
    _notify();
    await _automate();
  }

  Future<void> retry() async {
    error = null;
    if (state.terminal) {
      await settle();
      return;
    }
    _awaitingSave = true;
    await checkpoint();
    if (error == null) _awaitingSave = false;
  }

  Future<void> settle() async {
    if (busy || saved || disposed || !state.terminal) return;
    model.sound.finish();
    busy = true;
    error = null;
    _notify();
    try {
      if (_awaitingSave) {
        await model.store!.save(session);
        _awaitingSave = false;
      }
      await _settleSaved();
    } catch (e) {
      error = '保存失败，积分尚未计入：$e';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _settleSaved() async {
    receipt = await model.store!.settle(session);
    saved = true;
    clock.stop();
    if (!disposed) {
      final winner = state.data['winner'] as int?;
      final seat = state.config.game == Game.gobang
          ? (winner == null ? null : winner - 1)
          : winner;
      final humanWon =
          ![Game.gobang, Game.flying].contains(state.config.game) ||
          (seat != null && state.config.players[seat] != null);
      model.sound.settlement(won: state.outcome == 'won' && humanWon);
    }
    await model.refresh();
  }

  Future<void> _automate() async {
    if (disposed ||
        paused ||
        busy ||
        thinking ||
        state.terminal ||
        error != null) {
      return;
    }
    final c = state.config,
        d = state.data,
        rev = state.revision,
        generation = _generation;
    if (c.game == Game.gobang && c.players[(d['turn'] as int) - 1] == null) {
      thinking = true;
      _notify();
      try {
        final index = await compute(_gobang, state.toJson());
        if (disposed ||
            paused ||
            generation != _generation ||
            state.revision != rev) {
          return;
        }
        thinking = false;
        await command('place', {'index': index, 'color': d['turn']});
      } catch (e) {
        error = '电脑思考失败，可重试：$e';
        clock.stop();
        paused = true;
        model.sound.suspend();
      } finally {
        if (generation == _generation) thinking = false;
        _notify();
      }
    } else if (c.game == Game.flying) {
      final isAi = c.players[d['turn'] as int] == null;
      final options = legalPlanes(d);
      if (!isAi && options.length != 1) return;
      thinking = true;
      _notify();
      await Future<void>.delayed(
        Duration(milliseconds: model.reducedMotion ? 100 : 550),
      );
      if (disposed ||
          paused ||
          generation != _generation ||
          state.revision != rev) {
        return;
      }
      thinking = false;
      if (d['dice'] == 0) {
        await command('roll');
      } else {
        await command('fly', {
          'seat': d['turn'],
          'plane': choosePlane(state),
          'rollId': d['rollId'],
        });
      }
    }
  }

  Future<void> hintGobang() async {
    if (!canInput) return;
    thinking = true;
    _notify();
    final rev = state.revision, gen = _generation;
    try {
      final index = await compute(_gobang, state.toJson());
      if (disposed || paused || rev != state.revision || gen != _generation) {
        return;
      }
      thinking = false;
      await command('hint', {'index': index});
    } finally {
      if (gen == _generation) thinking = false;
      _notify();
    }
  }

  @override
  void dispose() {
    disposed = true;
    _generation++;
    timer?.cancel();
    clock.stop();
    super.dispose();
  }
}
