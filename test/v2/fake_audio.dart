import 'dart:async';
import 'package:puzzle_game/v2/sound.dart';

class FakeChannel implements SoundChannel {
  final String name;
  final List<String> log;
  String? playing;
  Completer<void>? gate;
  FakeChannel(this.name, this.log);
  @override
  Future<void> play(String asset, double volume, {required bool loop}) async {
    log.add('$name:start:$asset');
    await gate?.future;
    playing = asset;
    log.add('$name:play:$asset');
  }

  @override
  Future<void> pause() async {
    playing = null;
    log.add('$name:pause');
  }

  @override
  Future<void> stop() async {
    playing = null;
    log.add('$name:stop');
  }

  @override
  Future<void> dispose() async {
    playing = null;
    log.add('$name:dispose');
  }
}
