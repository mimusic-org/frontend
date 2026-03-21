import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/cover_url.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/player_provider.dart';

/// 播放列表抽屉/侧边栏
class PlaylistDrawer extends ConsumerWidget {
  final double width;
  final VoidCallback? onClose;

  const PlaylistDrawer({
    super.key,
    this.width = 320,
    this.onClose,
  });

  /// 显示为 BottomSheet（移动端）
  static Future<void> showAsBottomSheet(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => PlaylistDrawer(
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // 顶部标题栏
          _buildHeader(context, state, notifier),
          const Divider(height: 1),
          // 播放列表
          Expanded(
            child: state.playlist.isEmpty
                ? _buildEmptyState(context)
                : _buildPlaylist(context, state, notifier),
          ),
          // 底部工具栏
          const Divider(height: 1),
          _buildFooter(context, notifier),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    dynamic state,
    PlayerNotifier notifier,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            '播放列表',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${state.playlist.length}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const Spacer(),
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
              iconSize: 20,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '播放列表为空',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '添加歌曲到播放列表开始播放',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylist(
    BuildContext context,
    dynamic state,
    PlayerNotifier notifier,
  ) {
    return ReorderableListView.builder(
      itemCount: state.playlist.length,
      onReorder: notifier.reorderPlaylist,
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) {
        final song = state.playlist[index];
        final isCurrentSong = index == state.currentIndex;

        return _PlaylistItem(
          key: ValueKey('${song.id}_${song.type}_$index'),
          song: song,
          index: index,
          isCurrentSong: isCurrentSong,
          isPlaying: isCurrentSong && state.isPlaying,
          onTap: () => notifier.playPlaylist(state.playlist, startIndex: index),
          onRemove: () => notifier.removeFromPlaylist(index),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context, PlayerNotifier notifier) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: () {
            _showClearConfirmation(context, notifier);
          },
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('清空播放列表'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }

  void _showClearConfirmation(BuildContext context, PlayerNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空播放列表'),
        content: const Text('确定要清空播放列表吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              notifier.clearPlaylist();
              Navigator.pop(context);
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

/// 播放列表项
class _PlaylistItem extends StatelessWidget {
  final dynamic song;
  final int index;
  final bool isCurrentSong;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PlaylistItem({
    super.key,
    required this.song,
    required this.index,
    required this.isCurrentSong,
    required this.isPlaying,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverUrl = CoverUrl.buildCoverUrl(
      coverUrl: song.coverUrl,
      coverPath: song.coverPath,
    );

    return Material(
      color: isCurrentSong
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // 拖拽手柄
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              // 封面
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    if (coverUrl != null)
                      Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.music_note_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Center(
                        child: Icon(
                          Icons.music_note_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    // 正在播放指示器
                    if (isPlaying)
                      Container(
                        color: Colors.black54,
                        child: Center(
                          child: Icon(
                            Icons.equalizer_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 歌曲信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            isCurrentSong ? FontWeight.w600 : FontWeight.normal,
                        color: isCurrentSong
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            song.artist ?? '未知艺术家',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (song.duration > 0)
                          Text(
                            Formatters.formatDuration(song.duration),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // 删除按钮
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
                iconSize: 18,
                style: IconButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
