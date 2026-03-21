import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../config/app_config.dart';
import '../../shared/models/song.dart';
import '../utils/encode.dart';

/// 音频播放服务 - 封装 just_audio
class AudioPlayerService {
  late final AudioPlayer _player;

  AudioPlayerService() {
    _player = AudioPlayer();
  }

  /// 播放歌曲
  /// - 本地歌曲：使用服务器 URL + query parameter (access_token)
  /// - 网络歌曲/电台：直接使用 url
  Future<void> playSong(Song song, String? accessToken) async {
    debugPrint('[Player] AudioService.playSong: ${song.title} (type: ${song.type})');
    try {
      AudioSource source;

      if (song.type == 'local' && song.filePath != null) {
        // 本地歌曲，通过服务器 API 获取
        // iOS AVPlayer 不支持自定义 Header 认证，改用 URL query parameter
        final filePath = song.filePath!;
        final pathWithoutExt = getPathWithoutExtension(filePath);
        final ext = getExtension(filePath);
        final encodedPath = encodeBase62(pathWithoutExt);
        final token = accessToken ?? '';
        // 格式: /music/{base62编码的路径}{扩展名}?access_token=xxx
        final uri = Uri.parse('${AppConfig.baseUrl}/music/$encodedPath$ext?access_token=$token');
        debugPrint('[Player] AudioService: local song, uri: $uri');
        source = AudioSource.uri(uri);
      } else if (song.url != null && song.url!.isNotEmpty) {
        // 网络歌曲或电台
        debugPrint('[Player] AudioService: network song, url: ${song.url}');
        source = AudioSource.uri(Uri.parse(song.url!));
      } else {
        debugPrint('[Player] AudioService: no valid source for song');
        throw Exception('无法播放：歌曲没有有效的播放源');
      }

      debugPrint('[Player] AudioService: setting audio source');
      await _player.setAudioSource(source);
      debugPrint('[Player] AudioService: starting playback');
      await _player.play();
      debugPrint('[Player] AudioService: playback started');
    } catch (e) {
      debugPrint('[Player] AudioService.playSong error: $e');
      rethrow;
    }
  }

  /// 播放
  Future<void> play() => _player.play();

  /// 暂停
  Future<void> pause() => _player.pause();

  /// 停止
  Future<void> stop() => _player.stop();

  /// 跳转到指定位置
  Future<void> seek(Duration position) => _player.seek(position);

  /// 设置音量 (0.0 - 1.0)
  Future<void> setVolume(double volume) => _player.setVolume(volume.clamp(0.0, 1.0));

  /// 播放位置流
  Stream<Duration> get positionStream => _player.positionStream;

  /// 总时长流
  Stream<Duration?> get durationStream => _player.durationStream;

  /// 播放状态流
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// 是否正在播放流
  Stream<bool> get playingStream => _player.playingStream;

  /// 缓冲位置流
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  /// 当前是否正在播放
  bool get isPlaying => _player.playing;

  /// 当前播放位置
  Duration get position => _player.position;

  /// 当前总时长
  Duration? get duration => _player.duration;

  /// 当前音量
  double get volume => _player.volume;

  /// 获取处理状态流（用于检测歌曲结束）
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  /// 当前处理状态
  ProcessingState get processingState => _player.processingState;

  /// 释放资源
  Future<void> dispose() => _player.dispose();
}
