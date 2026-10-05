import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:puzzle_rules/puzzle_rules.dart';

/// Small transport boundary so asynchronous audio ordering can be tested.
abstract interface class SoundChannel {
  Future<void> play(String asset, double volume, {required bool loop});
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
}

class _PlayerChannel implements SoundChannel {
  final bool effect;
  _PlayerChannel({this.effect = false});
  AudioPlayer? _player;
  String? _asset;
  @override
  Future<void> play(String asset, double volume, {required bool loop}) async {
    final player = _player ??= AudioPlayer();
    if (effect) {
      await player.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
    }
    await player.setVolume(volume);
    await player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    if (loop && _asset == asset && player.state == PlayerState.paused) {
      await player.resume();
    } else if (!loop ||
        _asset != asset ||
        player.state != PlayerState.playing) {
      await player.play(AssetSource(asset));
      _asset = asset;
    }
  }

  @override
  Future<void> pause() async => await _player?.pause();
  @override
  Future<void> stop() async => await _player?.stop();
  @override
  Future<void> dispose() async => await _player?.dispose();
}

/// One music channel and one interruptible effect channel. All native commands
/// are serialized, including stop/dispose, so an old play cannot outlive a stop.
class Sound {
  final bool enabled;
  final SoundChannel _music, _effect;
  Sound({this.enabled = true, SoundChannel? music, SoundChannel? effect})
    : _music = music ?? _PlayerChannel(),
      _effect = effect ?? _PlayerChannel(effect: true);
  Json _settings = {};
  String? _track;
  bool _suspended = false, _background = false, _disposed = false;
  bool _settled = false, _resultPlayed = false;
  Future<void> _queue = Future.value();
  int _generation = 0, _effectGeneration = 0;
  static const effects = {
    'piece',
    'move',
    'eliminate',
    'plane',
    'dice',
    'fixed',
    'right',
    'turn',
    'winning',
  };
  Future<void> get idle => _queue;
  bool get _audible => enabled && !_disposed && !_suspended && !_background;
  double _volume(String key, double fallback) =>
      (_settings[key] as num? ?? fallback).toDouble().clamp(0, 1);

  void _enqueue(Future<void> Function() action) {
    _queue = _queue.then((_) async {
      try {
        await action();
      } catch (e) {
        debugPrint('Optional audio unavailable: $e');
      }
    });
  }

  void configure(Json values) {
    _settings = Map.from(values);
    // Applying preferences must never leave pause or settlement mode.
    _effectGeneration++;
    _enqueue(() => _effect.stop());
    _syncMusic();
  }

  void home() => _scene('audio/music/home_music.mp3');
  void game(Game game) => _scene('audio/music/game${game.index + 1}_music.mp3');
  void _scene(String track) {
    if (_disposed) return;
    _track = track;
    _settled = false;
    _resultPlayed = false;
    _suspended = false;
    _effectGeneration++;
    _enqueue(() => _effect.stop());
    _syncMusic();
  }

  void _syncMusic() {
    final generation = ++_generation;
    _enqueue(() async {
      if (generation != _generation || _disposed) return;
      if (_settled || _track == null) {
        await _music.stop();
      } else if (!_audible || _settings['music'] == false) {
        await _music.pause();
      } else {
        await _music.play(_track!, _volume('musicVolume', .5), loop: true);
        // A lifecycle change may have arrived while the native play awaited.
        if (generation != _generation) await _music.pause();
      }
    });
  }

  void effect(String? name) {
    if (_settled) return;
    _playEffect(name);
  }

  void _playEffect(String? name) {
    if (!_audible ||
        name == null ||
        !effects.contains(name) ||
        _settings['sound'] == false) {
      return;
    }
    final generation = _generation, effectGeneration = ++_effectGeneration;
    bool current() =>
        _audible &&
        generation == _generation &&
        effectGeneration == _effectGeneration &&
        _settings['sound'] != false;
    _enqueue(() async {
      if (!current()) return;
      await _effect.stop();
      if (!current()) return;
      await _effect.play(
        'audio/sfx/$name.mp3',
        _volume('soundVolume', .7),
        loop: false,
      );
      if (!current()) await _effect.stop();
    });
  }

  /// Freeze audio immediately on terminal rules, before persistence completes.
  void finish() {
    if (_settled || _disposed) return;
    _settled = true;
    _effectGeneration++;
    _enqueue(() => _effect.stop());
    _syncMusic();
  }

  /// Only the successful settlement may emit its result cue, once per scene.
  /// Loss/draw assets are intentionally absent, so those results stay silent.
  void settlement({required bool won}) {
    finish();
    if (_resultPlayed || _disposed) return;
    _resultPlayed = true;
    if (won) _playEffect('winning');
  }

  void suspend() {
    if (_disposed) return;
    _suspended = true;
    _effectGeneration++;
    _enqueue(() => _effect.stop());
    _syncMusic();
  }

  void background(bool value) {
    _background = value;
    if (value) {
      _effectGeneration++;
      _enqueue(() => _effect.stop());
    }
    _syncMusic();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _effectGeneration++;
    _enqueue(() => _music.dispose());
    _enqueue(() => _effect.dispose());
  }
}
