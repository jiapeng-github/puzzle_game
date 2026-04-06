import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 音乐类型
enum BgmType {
  home,     // 首页/排行榜
  gobang,   // 五子棋
  game2048, // 2048
  match3,   // 消消乐
  flyingChess, // 飞行棋
  sudoku,   // 数独
  memory,   // 记忆翻牌
}

/// 背景音乐服务 - 单例模式
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  bool _contextInitialized = false;

  AudioService._internal();

  void _ensureAudioContext() {
    if (_contextInitialized) return;
    _contextInitialized = true;

    // 配置音频上下文，允许多个播放器同时播放
    // 注意：Windows 平台会忽略大部分配置，但创建独立播放器仍然有效
    AudioPlayer.global.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {
          AVAudioSessionOptions.mixWithOthers,
          AVAudioSessionOptions.duckOthers,
        },
      ),
    ));

    debugPrint('AudioService: Audio context initialized');
  }

  AudioPlayer? _bgmPlayer;
  // 使用独立的音效播放器，复用以避免干扰背景音乐
  AudioPlayer? _sfxPlayer;
  BgmType? _currentBgm;
  bool _isPlaying = false;

  /// 当前播放的音乐类型
  BgmType? get currentBgm => _currentBgm;

  /// 是否正在播放
  bool get isPlaying => _isPlaying;

  /// 音乐文件映射
  static const Map<BgmType, String> _bgmFiles = {
    BgmType.home: 'audio/music/home_music.mp3',
    BgmType.gobang: 'audio/music/game1_music.mp3',
    BgmType.game2048: 'audio/music/game2_music.mp3',
    BgmType.match3: 'audio/music/game3_music.mp3',
    BgmType.flyingChess: 'audio/music/game4_music.mp3',
    BgmType.sudoku: 'audio/music/game5_music.mp3',
    BgmType.memory: 'audio/music/game6_music.mp3',
  };

  /// 播放指定类型的背景音乐
  Future<void> playBgm(BgmType type) async {
    // 确保音频上下文已初始化
    _ensureAudioContext();

    // 如果正在播放相同类型的音乐，跳过
    if (_isPlaying && _currentBgm == type) return;

    debugPrint('AudioService playBgm: type=$type, currentBgm=$_currentBgm, isPlaying=$_isPlaying');

    try {
      // 先停止并释放旧的播放器
      if (_bgmPlayer != null) {
        try {
          await _bgmPlayer!.stop();
          await _bgmPlayer!.dispose();
          debugPrint('AudioService: disposed old player');
        } catch (e) {
          debugPrint('AudioService dispose error: $e');
        }
        _bgmPlayer = null;
      }

      // 创建新播放器
      _bgmPlayer = AudioPlayer();

      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer!.setVolume(0.8);

      debugPrint('AudioService: starting play for ${_bgmFiles[type]}');
      await _bgmPlayer!.play(AssetSource(_bgmFiles[type]!));
      debugPrint('AudioService: play called successfully');

      _currentBgm = type;
      _isPlaying = true;
    } catch (e) {
      _isPlaying = false;
      debugPrint('AudioService playBgm error: $e');
    }
  }

  /// 播放首页背景音乐
  Future<void> playHomeBgm() => playBgm(BgmType.home);

  /// 播放音效
  Future<void> playSfx(String assetPath) async {
    // 确保音频上下文已初始化
    _ensureAudioContext();

    debugPrint('AudioService playSfx: $assetPath, bgmPlaying=$_isPlaying');

    try {
      // 每次创建新的独立播放器播放音效
      // 关键：不等待播放完成，使用 fire-and-forget 模式
      final sfxPlayer = AudioPlayer();

      // 使用 then() 链式调用，不阻塞
      sfxPlayer.setReleaseMode(ReleaseMode.release).then((_) {
        return sfxPlayer.setVolume(1.0);
      }).then((_) {
        return sfxPlayer.play(AssetSource(assetPath));
      }).then((_) {
        // 播放完成后释放
        sfxPlayer.onPlayerComplete.listen((_) {
          sfxPlayer.dispose();
          debugPrint('AudioService: sfx player disposed');
        });
      }).catchError((e) {
        debugPrint('AudioService playSfx error: $e');
        sfxPlayer.dispose();
      });
    } catch (e) {
      debugPrint('AudioService playSfx error: $e');
    }
  }

  /// 播放落子音效
  Future<void> playPieceSfx() => playSfx('audio/sfx/piece.mp3');

  /// 播放结算音效（同时停止背景音乐）
  Future<void> playWinningSfx() async {
    await stopBgm();
    await playSfx('audio/sfx/winning.mp3');
  }

  /// 播放移动音效
  Future<void> playMoveSfx() => playSfx('audio/sfx/move.mp3');

  /// 播放填写音效
  Future<void> playFixedSfx() => playSfx('audio/sfx/fixed.mp3');

  /// 播放飞机移动音效
  Future<void> playPlaneSfx() => playSfx('audio/sfx/plane.mp3');

  /// 播放骰子音效
  Future<void> playDiceSfx() => playSfx('audio/sfx/dice.mp3');

  /// 停止背景音乐
  Future<void> stopBgm() async {
    if (_bgmPlayer == null) return;

    try {
      await _bgmPlayer!.stop();
      await _bgmPlayer!.dispose();
      _bgmPlayer = null;
    } catch (e) {
      debugPrint('AudioService stopBgm error: $e');
    }
    _isPlaying = false;
    _currentBgm = null;
  }

  /// 暂停背景音乐
  Future<void> pauseBgm() async {
    if (!_isPlaying || _bgmPlayer == null) return;
    try {
      await _bgmPlayer!.pause();
    } catch (e) {
      // ignore
    }
  }

  /// 恢复背景音乐
  Future<void> resumeBgm() async {
    if (!_isPlaying || _bgmPlayer == null) return;
    try {
      await _bgmPlayer!.resume();
    } catch (e) {
      // ignore
    }
  }

  /// 设置音量 (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    if (_bgmPlayer == null) return;
    await _bgmPlayer!.setVolume(volume.clamp(0.0, 1.0));
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_bgmPlayer != null) {
      await _bgmPlayer!.dispose();
      _bgmPlayer = null;
    }
    if (_sfxPlayer != null) {
      await _sfxPlayer!.dispose();
      _sfxPlayer = null;
    }
    _isPlaying = false;
    _currentBgm = null;
  }
}
