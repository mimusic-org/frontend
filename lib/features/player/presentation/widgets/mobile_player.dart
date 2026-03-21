import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/cover_url.dart';
import '../../domain/player_state.dart';
import '../providers/player_provider.dart';
import '../queue_page.dart';
import 'lyrics_view.dart';
import 'play_controls.dart';
import 'progress_bar.dart';
import 'volume_control.dart';

/// 移动端全屏播放器
class MobilePlayer extends ConsumerStatefulWidget {
  const MobilePlayer({super.key});

  /// 显示全屏播放器
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MobilePlayer(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // 从下往上滑入动画
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
      ),
    );
  }

  @override
  ConsumerState<MobilePlayer> createState() => _MobilePlayerState();
}

class _MobilePlayerState extends ConsumerState<MobilePlayer> {
  /// PageView 控制器
  final PageController _pageController = PageController();

  /// 当前页面索引（0: 封面, 1: 歌词）
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    if (!state.hasSong) {
      debugPrint('[Player] MobilePlayer: no song, hiding');
      return const SizedBox.shrink();
    }

    final song = state.currentSong!;
    final coverUrl = CoverUrl.buildCoverUrl(
      coverUrl: song.coverUrl,
      coverPath: song.coverPath,
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // 背景模糊封面
          if (coverUrl != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ),
          // 背景遮罩
          Positioned.fill(
            child: Container(
              color: theme.colorScheme.surface.withValues(alpha: 0.85),
            ),
          ),
          // 主内容
          SafeArea(
            child: Column(
              children: [
                // 顶部工具栏
                _buildTopBar(context, notifier, state),
                const SizedBox(height: 16),
                // 封面/歌词 PageView
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          children: [
                            // 页面1：封面
                            Center(
                              child: _buildCover(context, coverUrl, size.width * 0.75),
                            ),
                            // 页面2：歌词
                            LyricsView(
                              lyricText: song.lyric,
                              currentPosition: state.currentTime,
                            ),
                          ],
                        ),
                      ),
                      // 页面指示器
                      const SizedBox(height: 12),
                      _buildPageIndicator(theme),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 歌曲信息
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        song.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        song.artist ?? '未知艺术家',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // 进度条
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: PlayerProgressBar(
                    position: state.currentTime,
                    duration: state.duration,
                    onSeek: notifier.seek,
                  ),
                ),
                const SizedBox(height: 16),
                // 主控制按钮
                PlayControls(
                  isPlaying: state.isPlaying,
                  hasPrev: state.hasPrev,
                  hasNext: state.hasNext,
                  isBuffering: state.isBuffering,
                  onPlay: notifier.togglePlay,
                  onPause: notifier.togglePlay,
                  onPrev: notifier.playPrev,
                  onNext: notifier.playNext,
                  size: 64,
                ),
                const SizedBox(height: 24),
                // 底部工具栏
                _buildBottomBar(context, state, notifier),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建页面指示器（小圆点）
  Widget _buildPageIndicator(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final isActive = index == _currentPage;
        return Container(
          width: isActive ? 8 : 6,
          height: isActive ? 8 : 6,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }

  Widget _buildTopBar(BuildContext context, PlayerNotifier notifier, PlayerState state) {
    final theme = Theme.of(context);
    final song = state.currentSong;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 返回按钮
          IconButton(
            onPressed: () {
              notifier.closeFullPlayer();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            iconSize: 32,
          ),
          // 歌曲信息（专辑名）
          if (song?.album != null && song!.album!.isNotEmpty)
            Expanded(
              child: Text(
                song.album!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            const Spacer(),
          // 占位，保持布局对称
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCover(BuildContext context, String? coverUrl, double size) {
    final theme = Theme.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: coverUrl != null
          ? Image.network(
              coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(theme, size),
            )
          : _buildPlaceholder(theme, size),
    );
  }

  Widget _buildPlaceholder(ThemeData theme, double size) {
    return Icon(
      Icons.music_note_rounded,
      size: size * 0.4,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 收藏
          IconButton(
            onPressed: () {
              // 收藏功能暂未实现，显示提示
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('收藏功能即将上线'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.favorite_border_rounded),
            tooltip: '收藏',
          ),
          // 播放模式
          IconButton(
            onPressed: () => _cyclePlayMode(notifier, state.playMode),
            icon: Icon(_getPlayModeIcon(state.playMode)),
            tooltip: _getPlayModeTooltip(state.playMode),
          ),
          // 音量
          PopupVolumeControl(
            volume: state.volume,
            onVolumeChanged: notifier.setVolume,
          ),
          // 睡眠定时（下拉菜单）
          _buildSleepTimerButton(context, state, notifier, theme),
          // 播放列表 - 显示播放队列浮层（直接覆盖在播放器之上）
          IconButton(
            onPressed: () {
              // 直接在播放器之上显示队列浮层，无需先关闭播放器
              QueueBottomSheet.show(context);
            },
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: '播放队列',
          ),
        ],
      ),
    );
  }

  IconData _getPlayModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.order:
        return Icons.repeat_rounded;
      case PlayMode.loop:
        return Icons.repeat_rounded;
      case PlayMode.single:
        return Icons.repeat_one_rounded;
      case PlayMode.random:
        return Icons.shuffle_rounded;
    }
  }

  String _getPlayModeTooltip(PlayMode mode) {
    switch (mode) {
      case PlayMode.order:
        return '顺序播放';
      case PlayMode.loop:
        return '列表循环';
      case PlayMode.single:
        return '单曲循环';
      case PlayMode.random:
        return '随机播放';
    }
  }

  void _cyclePlayMode(PlayerNotifier notifier, PlayMode currentMode) {
    const modes = PlayMode.values;
    final nextIndex = (modes.indexOf(currentMode) + 1) % modes.length;
    notifier.setPlayMode(modes[nextIndex]);
  }

  /// 构建睡眠定时按钮（使用 PopupMenuButton）
  Widget _buildSleepTimerButton(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
    ThemeData theme,
  ) {
    return PopupMenuButton<Duration?>(
      icon: Icon(
        state.sleepTimerRemaining != null
            ? Icons.alarm_on_rounded
            : Icons.alarm_rounded,
        color: state.sleepTimerRemaining != null
            ? theme.colorScheme.primary
            : null,
      ),
      tooltip: state.sleepTimerRemaining != null
          ? '睡眠定时：${_formatDuration(state.sleepTimerRemaining!)}'
          : '睡眠定时',
      onSelected: (duration) {
        if (duration == null) return;
        if (duration == Duration.zero) {
          notifier.cancelSleepTimer();
          debugPrint('[Player] 睡眠定时已取消');
        } else {
          notifier.setSleepTimer(duration);
          debugPrint('[Player] 设置睡眠定时：${duration.inMinutes}分钟');
        }
      },
      itemBuilder: (context) => [
        // 如果已设定定时器，显示剩余时间和取消选项
        if (state.sleepTimerRemaining != null) ...[
          PopupMenuItem<Duration?>(
            enabled: false,
            child: Text(
              '剩余时间：${_formatDuration(state.sleepTimerRemaining!)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const PopupMenuItem<Duration?>(
            value: Duration.zero,
            child: Text('取消定时'),
          ),
          const PopupMenuDivider(),
        ],
        // 定时选项
        const PopupMenuItem<Duration?>(
          value: Duration(minutes: 15),
          child: Text('15 分钟'),
        ),
        const PopupMenuItem<Duration?>(
          value: Duration(minutes: 30),
          child: Text('30 分钟'),
        ),
        const PopupMenuItem<Duration?>(
          value: Duration(minutes: 45),
          child: Text('45 分钟'),
        ),
        const PopupMenuItem<Duration?>(
          value: Duration(hours: 1),
          child: Text('1 小时'),
        ),
        const PopupMenuItem<Duration?>(
          value: Duration(hours: 2),
          child: Text('2 小时'),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
