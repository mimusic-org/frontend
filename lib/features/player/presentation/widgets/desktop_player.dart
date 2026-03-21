import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/cover_url.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/player_state.dart';
import '../providers/player_provider.dart';
import 'play_controls.dart';
import 'progress_bar.dart';
import 'volume_control.dart';

/// 桌面端底部播放器栏
class DesktopPlayer extends ConsumerWidget {
  const DesktopPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // 顶部进度条（可点击）
          ClickableProgressBar(
            position: state.currentTime,
            duration: state.duration,
            onSeek: notifier.seek,
            height: 4,
          ),
          // 主内容
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // 左侧：歌曲信息
                  Expanded(
                    flex: 3,
                    child: _buildSongInfo(context, state),
                  ),
                  // 中间：播放控制
                  Expanded(
                    flex: 4,
                    child: _buildPlayControls(context, state, notifier),
                  ),
                  // 右侧：工具栏
                  Expanded(
                    flex: 3,
                    child: _buildToolbar(context, state, notifier),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongInfo(BuildContext context, PlayerState state) {
    final theme = Theme.of(context);

    if (!state.hasSong) {
      return Row(
        children: [
          // 空封面
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: Icon(
              Icons.music_note_rounded,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '无播放内容',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      );
    }

    final song = state.currentSong!;
    final coverUrl = CoverUrl.buildCoverUrl(
      coverUrl: song.coverUrl,
      coverPath: song.coverPath,
    );

    return Row(
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
              ? Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.music_note_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : Icon(
                  Icons.music_note_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
        ),
        const SizedBox(width: 12),
        // 标题和艺术家
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                song.artist ?? '未知艺术家',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // 收藏按钮
        IconButton(
          onPressed: () {
            // TODO: 收藏功能
          },
          icon: const Icon(Icons.favorite_border_rounded),
          iconSize: 20,
          tooltip: '收藏',
        ),
      ],
    );
  }

  Widget _buildPlayControls(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 控制按钮
        PlayControls(
          isPlaying: state.isPlaying,
          hasPrev: state.hasPrev,
          hasNext: state.hasNext,
          isBuffering: state.isBuffering,
          onPlay: notifier.togglePlay,
          onPause: notifier.togglePlay,
          onPrev: notifier.playPrev,
          onNext: notifier.playNext,
          size: 40,
        ),
        const SizedBox(height: 4),
        // 时间显示
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              Formatters.formatDuration(state.currentTime.inSeconds.toDouble()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              ' / ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              Formatters.formatDuration(state.duration.inSeconds.toDouble()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 播放模式
        IconButton(
          onPressed: () => _cyclePlayMode(notifier, state.playMode),
          icon: Icon(
            _getPlayModeIcon(state.playMode),
            size: 20,
            color: state.playMode != PlayMode.order
                ? theme.colorScheme.primary
                : null,
          ),
          tooltip: _getPlayModeTooltip(state.playMode),
          visualDensity: VisualDensity.compact,
        ),
        // 音量控制
        Flexible(
          child: VolumeControl(
            volume: state.volume,
            onVolumeChanged: notifier.setVolume,
            showSlider: true,
            sliderWidth: 80,
          ),
        ),
        // 睡眠定时
        IconButton(
          onPressed: () => _showSleepTimerMenu(context, notifier, state),
          icon: Icon(
            state.sleepTimerRemaining != null
                ? Icons.alarm_on_rounded
                : Icons.alarm_rounded,
            size: 20,
            color: state.sleepTimerRemaining != null
                ? theme.colorScheme.primary
                : null,
          ),
          tooltip: state.sleepTimerRemaining != null
              ? '睡眠定时：${_formatDuration(state.sleepTimerRemaining!)}'
              : '睡眠定时',
          visualDensity: VisualDensity.compact,
        ),
        // 播放列表
        IconButton(
          onPressed: notifier.togglePlaylistDrawer,
          icon: Icon(
            Icons.queue_music_rounded,
            size: 20,
            color: state.showPlaylistDrawer ? theme.colorScheme.primary : null,
          ),
          tooltip: '播放列表',
          visualDensity: VisualDensity.compact,
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

  void _showSleepTimerMenu(
    BuildContext context,
    PlayerNotifier notifier,
    PlayerState state,
  ) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<Duration?>(
      context: context,
      position: position,
      items: [
        if (state.sleepTimerRemaining != null) ...[
          PopupMenuItem(
            enabled: false,
            child: Text('剩余：${_formatDuration(state.sleepTimerRemaining!)}'),
          ),
          const PopupMenuItem(
            value: Duration.zero,
            child: Text('取消定时'),
          ),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(
          value: Duration(minutes: 15),
          child: Text('15 分钟'),
        ),
        const PopupMenuItem(
          value: Duration(minutes: 30),
          child: Text('30 分钟'),
        ),
        const PopupMenuItem(
          value: Duration(minutes: 45),
          child: Text('45 分钟'),
        ),
        const PopupMenuItem(
          value: Duration(hours: 1),
          child: Text('1 小时'),
        ),
        const PopupMenuItem(
          value: Duration(hours: 2),
          child: Text('2 小时'),
        ),
      ],
    ).then((duration) {
      if (duration == null) return;
      if (duration == Duration.zero) {
        notifier.cancelSleepTimer();
      } else {
        notifier.setSleepTimer(duration);
      }
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
