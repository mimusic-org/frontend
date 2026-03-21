import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../../../core/audio/audio_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../shared/models/song.dart';
import '../../domain/player_state.dart';

/// AudioPlayerService Provider (单例)
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// 播放器状态 Provider
final playerStateProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  return PlayerNotifier(audioService, secureStorage);
});

/// 播放器状态管理 Notifier
class PlayerNotifier extends StateNotifier<PlayerState> {
  final AudioPlayerService _audioService;
  final SecureStorageService _secureStorage;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<ja.PlayerState>? _playerStateSubscription;
  StreamSubscription<ja.ProcessingState>? _processingStateSubscription;

  Timer? _sleepTimer;
  Timer? _sleepTimerCountdown;

  final Random _random = Random();
  final Set<int> _playedIndices = {}; // 随机模式下已播放的索引

  PlayerNotifier(this._audioService, this._secureStorage)
      : super(PlayerState.initial) {
    _initListeners();
  }

  /// 初始化监听器
  void _initListeners() {
    // 监听播放位置
    _positionSubscription = _audioService.positionStream.listen((position) {
      if (mounted) {
        state = state.copyWith(currentTime: position);
      }
    });

    // 监听总时长
    _durationSubscription = _audioService.durationStream.listen((duration) {
      if (mounted && duration != null) {
        state = state.copyWith(duration: duration);
      }
    });

    // 监听播放状态
    _audioService.playerStateStream.listen((playerState) {
      if (mounted) {
        state = state.copyWith(
          isPlaying: playerState.playing,
          isBuffering: playerState.processingState == ja.ProcessingState.buffering ||
              playerState.processingState == ja.ProcessingState.loading,
        );
      }
    });

    // 监听处理状态（检测歌曲结束）
    _processingStateSubscription =
        _audioService.processingStateStream.listen((processingState) {
      if (mounted && processingState == ja.ProcessingState.completed) {
        _onSongCompleted();
      }
    });
  }

  /// 歌曲播放完成处理
  void _onSongCompleted() {
    debugPrint('[Player] Song completed, playMode: ${state.playMode}');
    switch (state.playMode) {
      case PlayMode.single:
        // 单曲循环
        debugPrint('[Player] Single loop: restarting current song');
        _audioService.seek(Duration.zero);
        _audioService.play();
        break;
      case PlayMode.order:
      case PlayMode.loop:
      case PlayMode.random:
        // 播放下一首
        debugPrint('[Player] Playing next song');
        playNext();
        break;
    }
  }

  /// 播放单曲（添加到播放列表并播放）
  Future<void> playSong(Song song) async {
    debugPrint('[Player] playSong: ${song.title} (id: ${song.id}, type: ${song.type})');
    // 检查是否已在播放列表中
    final existingIndex = state.playlist.indexWhere(
        (s) => s.id == song.id && s.type == song.type);
    
    if (existingIndex >= 0) {
      // 已存在，直接跳转播放
      debugPrint('[Player] Song already in playlist at index $existingIndex');
      await _playAtIndex(existingIndex);
    } else {
      // 添加到播放列表末尾并播放
      final newPlaylist = [...state.playlist, song];
      final newIndex = newPlaylist.length - 1;
      debugPrint('[Player] Adding song to playlist at index $newIndex');
      state = state.copyWith(
        playlist: newPlaylist,
        currentIndex: newIndex,
        currentSong: song,
      );
      await _playCurrent();
    }
  }

  /// 播放歌单
  Future<void> playPlaylist(List<Song> songs, {int startIndex = 0}) async {
    debugPrint('[Player] playPlaylist: ${songs.length} songs, startIndex: $startIndex');
    if (songs.isEmpty) {
      debugPrint('[Player] playPlaylist: empty songs list, returning');
      return;
    }

    final safeIndex = startIndex.clamp(0, songs.length - 1);
    debugPrint('[Player] playPlaylist: starting with song: ${songs[safeIndex].title}');
    _playedIndices.clear();

    state = state.copyWith(
      playlist: List.from(songs),
      currentIndex: safeIndex,
      currentSong: songs[safeIndex],
    );

    await _playCurrent();
  }

  /// 添加到当前播放列表
  void addToPlaylist(List<Song> songs) {
    if (songs.isEmpty) return;

    final newPlaylist = [...state.playlist];
    for (final song in songs) {
      final exists = newPlaylist.any(
          (s) => s.id == song.id && s.type == song.type);
      if (!exists) {
        newPlaylist.add(song);
      }
    }

    state = state.copyWith(playlist: newPlaylist);
  }

  /// 暂停/播放切换
  Future<void> togglePlay() async {
    if (!state.hasSong) {
      debugPrint('[Player] togglePlay: no song to play');
      return;
    }

    if (state.isPlaying) {
      debugPrint('[Player] togglePlay: pausing');
      await _audioService.pause();
    } else {
      debugPrint('[Player] togglePlay: resuming');
      await _audioService.play();
    }
  }

  /// 播放下一首
  Future<void> playNext() async {
    debugPrint('[Player] playNext: currentIndex: ${state.currentIndex}, playlistLength: ${state.playlist.length}');
    if (state.playlist.isEmpty) {
      debugPrint('[Player] playNext: playlist is empty');
      return;
    }

    int nextIndex;
    if (state.playMode == PlayMode.random) {
      nextIndex = _getRandomIndex();
      debugPrint('[Player] playNext: random mode, nextIndex: $nextIndex');
    } else {
      nextIndex = state.currentIndex + 1;
      if (nextIndex >= state.playlist.length) {
        if (state.playMode == PlayMode.loop) {
          nextIndex = 0;
          debugPrint('[Player] playNext: loop mode, wrapping to index 0');
        } else {
          debugPrint('[Player] playNext: order mode, reached end of playlist');
          // 顺序模式，播放完毕
          return;
        }
      }
    }

    await _playAtIndex(nextIndex);
  }

  /// 播放上一首
  Future<void> playPrev() async {
    debugPrint('[Player] playPrev: currentIndex: ${state.currentIndex}, currentTime: ${state.currentTime.inSeconds}s');
    if (state.playlist.isEmpty) {
      debugPrint('[Player] playPrev: playlist is empty');
      return;
    }

    // 如果当前播放超过 3 秒，重新开始当前歌曲
    if (state.currentTime.inSeconds > 3) {
      debugPrint('[Player] playPrev: seeking to start of current song');
      await _audioService.seek(Duration.zero);
      return;
    }

    int prevIndex;
    if (state.playMode == PlayMode.random) {
      prevIndex = _getRandomIndex();
      debugPrint('[Player] playPrev: random mode, prevIndex: $prevIndex');
    } else {
      prevIndex = state.currentIndex - 1;
      if (prevIndex < 0) {
        if (state.playMode == PlayMode.loop) {
          prevIndex = state.playlist.length - 1;
          debugPrint('[Player] playPrev: loop mode, wrapping to last song');
        } else {
          debugPrint('[Player] playPrev: order mode, already at first song');
          // 顺序模式，已是第一首
          await _audioService.seek(Duration.zero);
          return;
        }
      }
    }

    await _playAtIndex(prevIndex);
  }

  /// 跳转进度
  Future<void> seek(Duration position) async {
    await _audioService.seek(position);
  }

  /// 设置音量 (0-100)
  Future<void> setVolume(double volume) async {
    final clampedVolume = volume.clamp(0.0, 100.0);
    state = state.copyWith(volume: clampedVolume, clearPreviousVolume: true);
    await _audioService.setVolume(clampedVolume / 100);
  }

  /// 切换静音
  Future<void> toggleMute() async {
    if (state.isMuted) {
      // 恢复音量
      final restoreVolume = state.previousVolume ?? 50;
      await setVolume(restoreVolume);
    } else {
      // 静音
      state = state.copyWith(previousVolume: state.volume);
      await setVolume(0);
    }
  }

  /// 设置播放模式
  void setPlayMode(PlayMode mode) {
    _playedIndices.clear();
    state = state.copyWith(playMode: mode);
  }

  /// 从播放列表删除
  void removeFromPlaylist(int index) {
    if (index < 0 || index >= state.playlist.length) return;

    final newPlaylist = List<Song>.from(state.playlist);
    newPlaylist.removeAt(index);

    int newIndex = state.currentIndex;
    Song? newSong = state.currentSong;

    if (index == state.currentIndex) {
      // 删除的是当前播放的歌曲
      if (newPlaylist.isEmpty) {
        newIndex = -1;
        newSong = null;
        _audioService.stop();
      } else if (index >= newPlaylist.length) {
        newIndex = newPlaylist.length - 1;
        newSong = newPlaylist[newIndex];
      } else {
        newSong = newPlaylist[newIndex];
      }
    } else if (index < state.currentIndex) {
      // 删除的在当前之前
      newIndex--;
    }

    state = state.copyWith(
      playlist: newPlaylist,
      currentIndex: newIndex,
      currentSong: newSong,
      clearCurrentSong: newSong == null,
    );
  }

  /// 拖拽排序播放列表
  void reorderPlaylist(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;

    final newPlaylist = List<Song>.from(state.playlist);
    final song = newPlaylist.removeAt(oldIndex);
    
    // 如果新位置在旧位置之后，需要调整
    final insertIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    newPlaylist.insert(insertIndex, song);

    // 调整当前索引
    int newCurrentIndex = state.currentIndex;
    if (oldIndex == state.currentIndex) {
      newCurrentIndex = insertIndex;
    } else {
      if (oldIndex < state.currentIndex && insertIndex >= state.currentIndex) {
        newCurrentIndex--;
      } else if (oldIndex > state.currentIndex && insertIndex <= state.currentIndex) {
        newCurrentIndex++;
      }
    }

    state = state.copyWith(
      playlist: newPlaylist,
      currentIndex: newCurrentIndex,
    );
  }

  /// 清空播放列表
  void clearPlaylist() {
    _audioService.stop();
    _playedIndices.clear();
    state = state.copyWith(
      playlist: [],
      currentIndex: -1,
      clearCurrentSong: true,
      isPlaying: false,
      currentTime: Duration.zero,
      duration: Duration.zero,
    );
  }

  /// 切换全屏播放器
  void toggleFullPlayer() {
    state = state.copyWith(showFullPlayer: !state.showFullPlayer);
  }

  /// 关闭全屏播放器
  void closeFullPlayer() {
    state = state.copyWith(showFullPlayer: false);
  }

  /// 切换播放列表抽屉
  void togglePlaylistDrawer() {
    state = state.copyWith(showPlaylistDrawer: !state.showPlaylistDrawer);
  }

  /// 关闭播放列表抽屉
  void closePlaylistDrawer() {
    state = state.copyWith(showPlaylistDrawer: false);
  }

  /// 设置睡眠定时器
  void setSleepTimer(Duration duration) {
    cancelSleepTimer();

    _sleepTimer = Timer(duration, () {
      _audioService.pause();
      cancelSleepTimer();
    });

    // 启动倒计时更新
    state = state.copyWith(sleepTimerRemaining: duration);
    _sleepTimerCountdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = state.sleepTimerRemaining;
      if (remaining != null && remaining.inSeconds > 0) {
        state = state.copyWith(
          sleepTimerRemaining: Duration(seconds: remaining.inSeconds - 1),
        );
      } else {
        timer.cancel();
        state = state.copyWith(clearSleepTimer: true);
      }
    });
  }

  /// 取消睡眠定时器
  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerCountdown?.cancel();
    _sleepTimerCountdown = null;
    if (mounted) {
      state = state.copyWith(clearSleepTimer: true);
    }
  }

  /// 播放指定索引
  Future<void> _playAtIndex(int index) async {
    if (index < 0 || index >= state.playlist.length) return;

    _playedIndices.add(index);
    state = state.copyWith(
      currentIndex: index,
      currentSong: state.playlist[index],
      currentTime: Duration.zero,
    );

    await _playCurrent();
  }

  /// 播放当前歌曲
  Future<void> _playCurrent() async {
    final song = state.currentSong;
    if (song == null) {
      debugPrint('[Player] _playCurrent: no current song');
      return;
    }

    debugPrint('[Player] _playCurrent: ${song.title} (id: ${song.id}, type: ${song.type})');
    debugPrint('[Player] _playCurrent: filePath: ${song.filePath}, url: ${song.url}');

    try {
      state = state.copyWith(isBuffering: true);
      final token = await _secureStorage.getAccessToken();
      debugPrint('[Player] _playCurrent: calling audioService.playSong');
      await _audioService.playSong(song, token);
      // 设置音量
      await _audioService.setVolume(state.volume / 100);
      debugPrint('[Player] _playCurrent: playback started successfully');
    } catch (e) {
      debugPrint('[Player] _playCurrent: error - $e');
      state = state.copyWith(isBuffering: false);
      rethrow;
    }
  }

  /// 获取随机索引（避免重复）
  int _getRandomIndex() {
    if (state.playlist.length == 1) return 0;

    // 如果所有歌曲都播放过，重置
    if (_playedIndices.length >= state.playlist.length) {
      _playedIndices.clear();
      // 保留当前索引，避免立即重复
      if (state.currentIndex >= 0) {
        _playedIndices.add(state.currentIndex);
      }
    }

    // 获取未播放的索引
    final availableIndices = List<int>.generate(
      state.playlist.length,
      (i) => i,
    ).where((i) => !_playedIndices.contains(i)).toList();

    if (availableIndices.isEmpty) {
      return _random.nextInt(state.playlist.length);
    }

    return availableIndices[_random.nextInt(availableIndices.length)];
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _processingStateSubscription?.cancel();
    _sleepTimer?.cancel();
    _sleepTimerCountdown?.cancel();
    super.dispose();
  }
}

/// 便捷 Provider：当前是否有歌曲
final hasCurrentSongProvider = Provider<bool>((ref) {
  final state = ref.watch(playerStateProvider);
  return state.hasSong;
});

/// 便捷 Provider：当前是否正在播放
final isPlayingProvider = Provider<bool>((ref) {
  final state = ref.watch(playerStateProvider);
  return state.isPlaying;
});

/// 便捷 Provider：当前歌曲
final currentSongProvider = Provider<Song?>((ref) {
  final state = ref.watch(playerStateProvider);
  return state.currentSong;
});

/// 便捷 Provider：播放进度
final playerProgressProvider = Provider<double>((ref) {
  final state = ref.watch(playerStateProvider);
  return state.progress;
});
