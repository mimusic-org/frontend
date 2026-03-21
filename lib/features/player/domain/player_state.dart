import '../../../shared/models/song.dart';

/// 播放模式
enum PlayMode {
  /// 顺序播放
  order,
  /// 列表循环
  loop,
  /// 单曲循环
  single,
  /// 随机播放
  random,
}

/// 播放器状态
class PlayerState {
  final Song? currentSong;
  final List<Song> playlist;
  final int currentIndex;
  final bool isPlaying;
  final double volume; // 0-100
  final Duration currentTime;
  final Duration duration;
  final PlayMode playMode;
  final bool isBuffering;
  final bool showFullPlayer; // 移动端全屏播放器
  final bool showPlaylistDrawer; // 播放列表抽屉
  final Duration? sleepTimerRemaining; // 睡眠定时器剩余时间
  final double? previousVolume; // 静音前的音量（用于恢复）

  const PlayerState({
    this.currentSong,
    this.playlist = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.volume = 50,
    this.currentTime = Duration.zero,
    this.duration = Duration.zero,
    this.playMode = PlayMode.order,
    this.isBuffering = false,
    this.showFullPlayer = false,
    this.showPlaylistDrawer = false,
    this.sleepTimerRemaining,
    this.previousVolume,
  });

  /// 初始状态
  static const PlayerState initial = PlayerState();

  /// 是否有下一首
  bool get hasNext {
    if (playlist.isEmpty) return false;
    if (playMode == PlayMode.loop || playMode == PlayMode.random) return true;
    return currentIndex < playlist.length - 1;
  }

  /// 是否有上一首
  bool get hasPrev {
    if (playlist.isEmpty) return false;
    if (playMode == PlayMode.loop || playMode == PlayMode.random) return true;
    return currentIndex > 0;
  }

  /// 是否有当前歌曲
  bool get hasSong => currentSong != null;

  /// 下一首歌曲（仅顺序模式下）
  Song? get nextSong {
    if (!hasNext || playlist.isEmpty) return null;
    final nextIndex = (currentIndex + 1) % playlist.length;
    return playlist[nextIndex];
  }

  /// 播放进度 (0.0 - 1.0)
  double get progress {
    if (duration.inMilliseconds <= 0) return 0;
    return (currentTime.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// 是否静音
  bool get isMuted => volume == 0;

  /// 复制并修改
  PlayerState copyWith({
    Song? currentSong,
    List<Song>? playlist,
    int? currentIndex,
    bool? isPlaying,
    double? volume,
    Duration? currentTime,
    Duration? duration,
    PlayMode? playMode,
    bool? isBuffering,
    bool? showFullPlayer,
    bool? showPlaylistDrawer,
    Duration? sleepTimerRemaining,
    double? previousVolume,
    bool clearCurrentSong = false,
    bool clearSleepTimer = false,
    bool clearPreviousVolume = false,
  }) {
    return PlayerState(
      currentSong: clearCurrentSong ? null : (currentSong ?? this.currentSong),
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      volume: volume ?? this.volume,
      currentTime: currentTime ?? this.currentTime,
      duration: duration ?? this.duration,
      playMode: playMode ?? this.playMode,
      isBuffering: isBuffering ?? this.isBuffering,
      showFullPlayer: showFullPlayer ?? this.showFullPlayer,
      showPlaylistDrawer: showPlaylistDrawer ?? this.showPlaylistDrawer,
      sleepTimerRemaining: clearSleepTimer ? null : (sleepTimerRemaining ?? this.sleepTimerRemaining),
      previousVolume: clearPreviousVolume ? null : (previousVolume ?? this.previousVolume),
    );
  }

  @override
  String toString() {
    return 'PlayerState(song: ${currentSong?.title}, index: $currentIndex, playing: $isPlaying, mode: $playMode)';
  }
}
