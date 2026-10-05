import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/v2/sound.dart';
import 'package:puzzle_rules/puzzle_rules.dart';
import 'fake_audio.dart';

void main() {
  late List<String> log;
  late FakeChannel music, effect;
  late Sound sound;
  setUp(() {
    log = [];
    music = FakeChannel('music', log);
    effect = FakeChannel('effect', log);
    sound = Sound(music: music, effect: effect);
  });
  tearDown(() async {
    sound.dispose();
    await sound.idle;
  });

  for (final game in Game.values) {
    test(
      '${game.name}: settlement stops music and move before result, once',
      () async {
        sound.game(game);
        await sound.idle;
        expect(music.playing, 'audio/music/game${game.index + 1}_music.mp3');
        sound.effect('move');
        await sound.idle;
        log.clear();
        sound.finish();
        sound.effect('move');
        sound.settlement(won: true);
        sound.settlement(won: true);
        await sound.idle;
        expect(music.playing, isNull);
        expect(effect.playing, 'audio/sfx/winning.mp3');
        expect(
          log.indexOf('music:stop'),
          lessThan(log.indexOf('effect:start:audio/sfx/winning.mp3')),
        );
        expect(
          log.where((x) => x == 'effect:play:audio/sfx/winning.mp3').length,
          1,
        );
        sound.configure({'musicVolume': .8});
        await sound.idle;
        expect(music.playing, isNull);
        sound.home();
        await sound.idle;
        expect(effect.playing, isNull);
        expect(music.playing, 'audio/music/home_music.mp3');
      },
    );
  }

  test(
    'pause during pending native play wins; settings cannot resume it',
    () async {
      music.gate = Completer<void>();
      sound.game(Game.memory);
      await Future<void>.delayed(Duration.zero);
      sound.suspend();
      sound.effect('turn');
      sound.configure({'musicVolume': .9});
      music.gate!.complete();
      await sound.idle;
      expect(music.playing, isNull);
      expect(effect.playing, isNull);
      sound.game(Game.memory);
      await sound.idle;
      expect(music.playing, isNotNull);
    },
  );

  test('pending effect cannot leak across settlement or disposal', () async {
    sound.game(Game.flying);
    await sound.idle;
    effect.gate = Completer<void>();
    sound.effect('plane');
    await Future<void>.delayed(Duration.zero);
    sound.finish();
    sound.settlement(won: true);
    effect.gate!.complete();
    await sound.idle;
    expect(music.playing, isNull);
    expect(effect.playing, 'audio/sfx/winning.mp3');
    sound.dispose();
    sound.home();
    sound.effect('turn');
    await sound.idle;
    expect(music.playing, isNull);
    expect(effect.playing, isNull);
    expect(log.last, 'effect:dispose');
  });

  test(
    'rapid scene changes choose actual latest track and discard stale effects',
    () async {
      sound.home();
      sound.game(Game.sudoku);
      sound.effect('fixed');
      sound.home();
      await sound.idle;
      expect(music.playing, 'audio/music/home_music.mp3');
      expect(effect.playing, isNull);
      expect(log.where((x) => x.startsWith('music:play:')).length, 1);
    },
  );

  test(
    'background blocks scene/settings/result callbacks and never replays result',
    () async {
      sound.game(Game.match3);
      await sound.idle;
      sound.background(true);
      sound.home();
      sound.configure({});
      await sound.idle;
      expect(music.playing, isNull);
      sound.background(false);
      await sound.idle;
      expect(music.playing, 'audio/music/home_music.mp3');
      sound.game(Game.gobang);
      sound.background(true);
      sound.settlement(won: true);
      sound.background(false);
      await sound.idle;
      expect(music.playing, isNull);
      expect(effect.playing, isNull);
    },
  );

  test(
    'loss and muted victory stop music without result or fallback sounds',
    () async {
      sound.game(Game.game2048);
      await sound.idle;
      sound.settlement(won: false);
      await sound.idle;
      expect(music.playing, isNull);
      expect(effect.playing, isNull);
      sound.game(Game.memory);
      sound.configure({'sound': false});
      sound.settlement(won: true);
      await sound.idle;
      expect(music.playing, isNull);
      expect(effect.playing, isNull);
    },
  );
}
