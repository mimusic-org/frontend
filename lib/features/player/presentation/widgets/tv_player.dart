import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tv_theme.dart';
import '../../../../core/utils/cover_url.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/tv_focusable.dart';
import '../../domain/player_state.dart';
import '../providers/player_provider.dart';

/// TV 全屏播放器界面
/// 
/// 专为 TV 端设计的播放器，特性：
/// - 大尺寸封面图（300x300）
/// - 大号字体（标题 24sp，艺术家 20sp）
/// - 加粗进度条
/// - 大按钮（最小 80x80），支持 D-Pad 焦点导航
/// - 渐变背景
class TvPlayer extends ConsumerWidget {
  const TvPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 获取封面 URL
    String? coverUrl;
    if (state.hasSong) {
      coverUrl = CoverUrl.buildCoverUrl(
        coverUrl: state.currentSong!.coverUrl,
        coverPath: state.currentSong!.coverPath,
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // 渐变背景
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.3),
              colorScheme.surface,
              colorScheme.surface,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FocusTraversalGroup(
            child: Column(
              children: [
                // 顶部工具栏
                _buildTopBar(context, notifier),
                // 主内容区域
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: TvTheme.contentPaddingAll,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 封面图
                            _buildCoverArt(context, coverUrl),
                            const SizedBox(height: TvTheme.spacingLarge),
                            // 歌曲信息
                            _buildSongInfo(context, state),
                            const SizedBox(height: TvTheme.spacingXLarge),
                            // 进度条
                            _buildProgressBar(context, state, notifier),
                            const SizedBox(height: TvTheme.spacingXLarge),
                            // 播放控制按钮
                            _buildPlayControls(context, state, notifier),
                            const SizedBox(height: TvTheme.spacingLarge),
                            // 附加控制
                            _buildExtraControls(context, state, notifier),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 顶部工具栏
  Widget _buildTopBar(BuildContext context, PlayerNotifier notifier) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TvTheme.contentPadding,
        vertical: TvTheme.spacingMedium,
      ),
      child: Row(
        children: [
          // 返回按钮
          TvIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () {
              notifier.closeFullPlayer();
              Navigator.of(context).maybePop();
            },
            size: 56,
            iconSize: 28,
            autofocus: false,
          ),
          const Spacer(),
          // 正在播放标题
          Text(
            '正在播放',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: TvTheme.fontSizeBody,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // 占位，保持居中
          const SizedBox(width: 56),
        ],
      ),
    );
  }

  /// 封面图
  Widget _buildCoverArt(BuildContext context, String? coverUrl) {
    final theme = Theme.of(context);
    
    return Container(
      width: TvTheme.largeCoverSize,
      height: TvTheme.largeCoverSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TvTheme.cardRadius),
        color: theme.colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: coverUrl != null
          ? Image.network(
              coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholderIcon(context),
            )
          : _buildPlaceholderIcon(context),
    );
  }

  Widget _buildPlaceholderIcon(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Icon(
        Icons.music_note_rounded,
        size: 100,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }

  /// 歌曲信息
  Widget _buildSongInfo(BuildContext context, PlayerState state) {
    final theme = Theme.of(context);
    
    if (!state.hasSong) {
      return Text(
        '无播放内容',
        style: TvTheme.titleStyle(context).copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      );
    }

    final song = state.currentSong!;
    
    return Column(
      children: [
        // 标题
        Text(
          song.title,
          style: TvTheme.titleStyle(context),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: TvTheme.spacingSmall),
        // 艺术家
        Text(
          song.artist ?? '未知艺术家',
          style: TvTheme.captionStyle(context),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// 进度条
  Widget _buildProgressBar(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    final theme = Theme.of(context);
    
    return SizedBox(
      width: 600,
      child: Column(
        children: [
          // 进度滑块
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6, // 加粗进度条
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10,
                pressedElevation: 6,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
              thumbColor: theme.colorScheme.primary,
              overlayColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: state.progress,
              onChanged: (value) {
                final newPosition = Duration(
                  milliseconds: (value * state.duration.inMilliseconds).round(),
                );
                notifier.seek(newPosition);
              },
            ),
          ),
          const SizedBox(height: TvTheme.spacingSmall),
          // 时间显示
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Formatters.formatDuration(state.currentTime.inSeconds.toDouble()),
                  style: TvTheme.captionStyle(context),
                ),
                Text(
                  Formatters.formatDuration(state.duration.inSeconds.toDouble()),
                  style: TvTheme.captionStyle(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 播放控制按钮
  Widget _buildPlayControls(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 上一首
        TvIconButton(
          icon: Icons.skip_previous_rounded,
          onPressed: state.hasPrev ? notifier.playPrev : null,
          enabled: state.hasPrev,
          size: TvTheme.minButtonSize,
          iconSize: 40,
        ),
        const SizedBox(width: TvTheme.spacingLarge),
        // 播放/暂停（主按钮，更大）
        _buildPlayPauseButton(context, state, notifier),
        const SizedBox(width: TvTheme.spacingLarge),
        // 下一首
        TvIconButton(
          icon: Icons.skip_next_rounded,
          onPressed: state.hasNext ? notifier.playNext : null,
          enabled: state.hasNext,
          size: TvTheme.minButtonSize,
          iconSize: 40,
        ),
      ],
    );
  }

  /// 播放/暂停按钮
  Widget _buildPlayPauseButton(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    final theme = Theme.of(context);
    
    if (state.isBuffering) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return TvFocusable(
      onSelect: notifier.togglePlay,
      autofocus: true,
      borderRadius: 50,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 56,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }

  /// 附加控制按钮
  Widget _buildExtraControls(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 播放模式
        TvIconButton(
          icon: _getPlayModeIcon(state.playMode),
          onPressed: () => _cyclePlayMode(notifier, state.playMode),
          size: 64,
          iconSize: 28,
          iconColor: state.playMode != PlayMode.order
              ? theme.colorScheme.primary
              : null,
        ),
        const SizedBox(width: TvTheme.spacingMedium),
        // 音量减
        TvIconButton(
          icon: Icons.volume_down_rounded,
          onPressed: () {
            final newVolume = (state.volume - 10).clamp(0.0, 100.0);
            notifier.setVolume(newVolume);
          },
          size: 64,
          iconSize: 28,
        ),
        const SizedBox(width: TvTheme.spacingSmall),
        // 音量显示
        SizedBox(
          width: 60,
          child: Text(
            '${state.volume.round()}%',
            style: TvTheme.bodyStyle(context),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: TvTheme.spacingSmall),
        // 音量加
        TvIconButton(
          icon: Icons.volume_up_rounded,
          onPressed: () {
            final newVolume = (state.volume + 10).clamp(0.0, 100.0);
            notifier.setVolume(newVolume);
          },
          size: 64,
          iconSize: 28,
        ),
        const SizedBox(width: TvTheme.spacingMedium),
        // 播放列表
        TvIconButton(
          icon: Icons.queue_music_rounded,
          onPressed: notifier.togglePlaylistDrawer,
          size: 64,
          iconSize: 28,
          iconColor: state.showPlaylistDrawer
              ? theme.colorScheme.primary
              : null,
        ),
      ],
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

  void _cyclePlayMode(PlayerNotifier notifier, PlayMode currentMode) {
    const modes = PlayMode.values;
    final nextIndex = (modes.indexOf(currentMode) + 1) % modes.length;
    notifier.setPlayMode(modes[nextIndex]);
  }
}

/// TV 迷你播放器（用于底部显示）
/// 
/// 专为 TV 端设计的迷你播放器，显示在底部
class TvMiniPlayer extends ConsumerWidget {
  const TvMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final theme = Theme.of(context);

    if (!state.hasSong) {
      return const SizedBox.shrink();
    }

    final song = state.currentSong!;
    final coverUrl = CoverUrl.buildCoverUrl(
      coverUrl: song.coverUrl,
      coverPath: song.coverPath,
    );

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TvTheme.contentPadding,
          vertical: TvTheme.spacingSmall,
        ),
        child: FocusTraversalGroup(
          child: Row(
            children: [
              // 封面
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                clipBehavior: Clip.antiAlias,
                child: coverUrl != null
                    ? Image.network(coverUrl, fit: BoxFit.cover)
                    : Icon(
                        Icons.music_note_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
              ),
              const SizedBox(width: TvTheme.spacingMedium),
              // 歌曲信息
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: TvTheme.bodyStyle(context).copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist ?? '未知艺术家',
                      style: TvTheme.captionStyle(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 播放控制
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TvIconButton(
                    icon: Icons.skip_previous_rounded,
                    onPressed: state.hasPrev ? notifier.playPrev : null,
                    enabled: state.hasPrev,
                    size: 56,
                    iconSize: 28,
                  ),
                  const SizedBox(width: TvTheme.spacingSmall),
                  TvIconButton(
                    icon: state.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    onPressed: notifier.togglePlay,
                    size: 56,
                    iconSize: 32,
                    backgroundColor: theme.colorScheme.primary,
                    iconColor: theme.colorScheme.onPrimary,
                  ),
                  const SizedBox(width: TvTheme.spacingSmall),
                  TvIconButton(
                    icon: Icons.skip_next_rounded,
                    onPressed: state.hasNext ? notifier.playNext : null,
                    enabled: state.hasNext,
                    size: 56,
                    iconSize: 28,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
