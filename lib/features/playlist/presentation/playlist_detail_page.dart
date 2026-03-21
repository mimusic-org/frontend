import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/responsive.dart';
import '../../../core/utils/cover_url.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/song.dart';
import '../../../shared/widgets/song_picker_modal.dart';
import '../../player/presentation/providers/player_provider.dart';
import '../domain/playlist.dart';
import 'providers/playlist_provider.dart';

/// 歌单详情页面
class PlaylistDetailPage extends ConsumerStatefulWidget {
  final String playlistId;

  const PlaylistDetailPage({
    super.key,
    required this.playlistId,
  });

  @override
  ConsumerState<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends ConsumerState<PlaylistDetailPage> {
  int get _playlistIdInt => int.tryParse(widget.playlistId) ?? 0;

  /// 排序模式
  bool _isSortMode = false;

  /// 多选模式
  bool _isSelectMode = false;

  /// 多选模式下选中的歌曲 ID
  final Set<int> _selectedSongIds = {};

  /// 排序模式下的可排序歌曲列表（本地副本）
  List<Song> _sortableSongs = [];

  /// 进入排序模式
  void _enterSortMode(List<Song> songs) {
    setState(() {
      _isSortMode = true;
      _isSelectMode = false;
      _selectedSongIds.clear();
      _sortableSongs = List.from(songs);
    });
  }

  /// 退出排序模式并保存
  Future<void> _exitSortMode() async {
    final songIds = _sortableSongs.map((s) => s.id).toList();
    setState(() => _isSortMode = false);

    final notifier = ref.read(playlistNotifierProvider.notifier);
    final success = await notifier.reorderPlaylistSongs(_playlistIdInt, songIds);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('排序已保存')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('排序保存失败'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 取消排序模式（不保存）
  void _cancelSortMode() {
    setState(() {
      _isSortMode = false;
      _sortableSongs = [];
    });
  }

  /// 进入多选模式
  void _enterSelectMode() {
    setState(() {
      _isSelectMode = true;
      _isSortMode = false;
      _selectedSongIds.clear();
      _sortableSongs = [];
    });
  }

  /// 退出多选模式
  void _exitSelectMode() {
    setState(() {
      _isSelectMode = false;
      _selectedSongIds.clear();
    });
  }

  /// 切换歌曲选中状态
  void _toggleSongSelection(int songId) {
    setState(() {
      if (_selectedSongIds.contains(songId)) {
        _selectedSongIds.remove(songId);
      } else {
        _selectedSongIds.add(songId);
      }
    });
  }

  /// 全选/取消全选
  void _toggleSelectAll(List<Song> songs) {
    setState(() {
      if (_selectedSongIds.length == songs.length) {
        _selectedSongIds.clear();
      } else {
        _selectedSongIds.addAll(songs.map((s) => s.id));
      }
    });
  }

  /// 批量删除选中的歌曲
  Future<void> _batchRemoveSelectedSongs() async {
    if (_selectedSongIds.isEmpty) return;

    final count = _selectedSongIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量移除'),
        content: Text('确定要从歌单中移除 $count 首歌曲吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('移除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final notifier = ref.read(playlistNotifierProvider.notifier);
    final success = await notifier.batchRemoveSongs(
      _playlistIdInt,
      _selectedSongIds,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已移除 $count 首歌曲')),
        );
        _exitSelectMode();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('移除失败'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 拖拽排序回调
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _sortableSongs.removeAt(oldIndex);
      _sortableSongs.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final playlistAsync = ref.watch(playlistDetailProvider(_playlistIdInt));
    final songsAsync = ref.watch(playlistSongsProvider(_playlistIdInt));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(playlistDetailProvider(_playlistIdInt));
          ref.invalidate(playlistSongsProvider(_playlistIdInt));
        },
        child: playlistAsync.when(
          data: (playlist) => _buildContent(context, playlist, songsAsync),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildError(error.toString()),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Playlist playlist,
    AsyncValue<SongListResponse> songsAsync,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = context.isWideScreen;

    return CustomScrollView(
      slivers: [
        // 顶部大图
        SliverAppBar(
          expandedHeight: isWide ? 300 : 250,
          pinned: true,
          // 返回按钮
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: '返回',
            onPressed: () {
              // 安全返回：检查是否有可弹出的路由
              if (context.canPop()) {
                context.pop();
              } else {
                // 没有返回栈时，跳转到歌单列表页
                context.go('/playlists');
              }
            },
          ),
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              playlist.name,
              style: const TextStyle(
                shadows: [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
            background: _buildHeaderBackground(context, playlist),
          ),
          actions: _buildAppBarActions(context, playlist, songsAsync, colorScheme),
        ),

        // 歌单信息
        SliverToBoxAdapter(
          child: _buildPlaylistInfo(context, playlist, songsAsync),
        ),

        // 操作按钮
        SliverToBoxAdapter(
          child: _buildActionButtons(context, playlist, songsAsync),
        ),

        // 歌曲列表
        songsAsync.when(
          data: (response) => _buildSongList(context, playlist, response.songs),
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, stack) => SliverToBoxAdapter(
            child: _buildError(error.toString()),
          ),
        ),

        // 底部安全区域
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.of(context).padding.bottom + 80,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderBackground(BuildContext context, Playlist playlist) {
    final coverUrl = CoverUrl.buildCoverUrl(
      coverUrl: playlist.coverUrl,
      coverPath: playlist.coverPath,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景图
        if (coverUrl != null)
          CachedNetworkImage(
            imageUrl: coverUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: colorScheme.surfaceContainerHighest,
            ),
            errorWidget: (context, url, error) => Container(
              color: colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.queue_music,
                size: 64,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          )
        else
          Container(
            color: colorScheme.surfaceContainerHighest,
            child: Center(
              child: Icon(
                playlist.type == 'radio' ? Icons.radio : Icons.queue_music,
                size: 64,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
        // 渐变遮罩
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.7),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistInfo(
    BuildContext context,
    Playlist playlist,
    AsyncValue<SongListResponse> songsAsync,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final songCount = songsAsync.valueOrNull?.total ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 描述
          if (playlist.description?.isNotEmpty == true)
            Text(
              playlist.description!,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 8),
          // 统计信息
          Row(
            children: [
              Icon(
                Icons.music_note,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '$songCount 首歌曲',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              if (playlist.type == 'radio') ...[
                Icon(
                  Icons.radio,
                  size: 16,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '电台',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.secondary,
                  ),
                ),
              ],
            ],
          ),
          // 标签
          if (playlist.labels.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: playlist.labels.map((label) {
                return Chip(
                  label: Text(_getLabelName(label)),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建 AppBar 操作按钮
  List<Widget> _buildAppBarActions(
    BuildContext context,
    Playlist playlist,
    AsyncValue<SongListResponse> songsAsync,
    ColorScheme colorScheme,
  ) {
    final songs = songsAsync.valueOrNull?.songs ?? [];

    // 排序模式
    if (_isSortMode) {
      return [
        TextButton(
          onPressed: _cancelSortMode,
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _exitSortMode,
          child: const Text('完成'),
        ),
      ];
    }

    // 多选模式
    if (_isSelectMode) {
      return [
        TextButton(
          onPressed: () => _toggleSelectAll(songs),
          child: Text(
            _selectedSongIds.length == songs.length ? '取消全选' : '全选',
          ),
        ),
        TextButton(
          onPressed: _selectedSongIds.isEmpty
              ? null
              : _batchRemoveSelectedSongs,
          child: Text(
            '删除(${_selectedSongIds.length})',
            style: TextStyle(
              color: _selectedSongIds.isEmpty
                  ? null
                  : colorScheme.error,
            ),
          ),
        ),
        TextButton(
          onPressed: _exitSelectMode,
          child: const Text('取消'),
        ),
      ];
    }

    // 正常模式
    return [
      // 排序按钮（歌曲数 > 1 时显示）
      if (songs.length > 1)
        IconButton(
          icon: const Icon(Icons.sort),
          tooltip: '排序',
          onPressed: () => _enterSortMode(songs),
        ),
      // 多选按钮（有歌曲时显示）
      if (songs.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: '多选',
          onPressed: _enterSelectMode,
        ),
      // 编辑按钮
      IconButton(
        icon: const Icon(Icons.edit),
        tooltip: '编辑歌单',
        onPressed: () => _showEditDialog(playlist),
      ),
      // 更多操作
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          switch (value) {
            case 'add_songs':
              _addSongs();
              break;
            case 'delete':
              _confirmDelete(playlist);
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'add_songs',
            child: ListTile(
              leading: Icon(Icons.add),
              title: Text('添加歌曲'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (!playlist.isBuiltIn)
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(
                  Icons.delete,
                  color: colorScheme.error,
                ),
                title: Text(
                  '删除歌单',
                  style: TextStyle(color: colorScheme.error),
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    ];
  }

  Widget _buildActionButtons(
    BuildContext context,
    Playlist playlist,
    AsyncValue<SongListResponse> songsAsync,
  ) {
    final songs = songsAsync.valueOrNull?.songs ?? [];

    // 排序模式和多选模式下隐藏操作按钮
    if (_isSortMode || _isSelectMode) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: songs.isEmpty ? null : () => _playAll(playlist, songs),
              icon: const Icon(Icons.play_arrow),
              label: const Text('播放全部'),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _addSongs,
            icon: const Icon(Icons.add),
            label: const Text('添加歌曲'),
          ),
        ],
      ),
    );
  }

  Widget _buildSongList(
    BuildContext context,
    Playlist playlist,
    List<Song> songs,
  ) {
    if (songs.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmptySongs(context),
      );
    }

    // 排序模式：使用 ReorderableListView
    if (_isSortMode) {
      return SliverToBoxAdapter(
        child: ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _sortableSongs.length,
          onReorder: _onReorder,
          itemBuilder: (context, index) {
            final song = _sortableSongs[index];
            return _SongListTile(
              key: ValueKey(song.id),
              song: song,
              index: index + 1,
              onTap: () {},
              onRemove: () {},
              showDragHandle: true,
              showTrailing: false,
            );
          },
        ),
      );
    }

    // 多选模式：显示 Checkbox
    if (_isSelectMode) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final song = songs[index];
            final isSelected = _selectedSongIds.contains(song.id);
            return _SongListTile(
              song: song,
              index: index + 1,
              onTap: () => _toggleSongSelection(song.id),
              onRemove: () {},
              showCheckbox: true,
              isChecked: isSelected,
              onCheckChanged: (checked) => _toggleSongSelection(song.id),
              showTrailing: false,
            );
          },
          childCount: songs.length,
        ),
      );
    }

    // 正常模式
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final song = songs[index];
          return _SongListTile(
            song: song,
            index: index + 1,
            onTap: () => _playSong(song, songs, index),
            onRemove: () => _removeSong(playlist.id, song),
          );
        },
        childCount: songs.length,
      ),
    );
  }

  Widget _buildEmptySongs(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(64),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_off_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '歌单暂无歌曲',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _addSongs,
              icon: const Icon(Icons.add),
              label: const Text('添加歌曲'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                ref.invalidate(playlistDetailProvider(_playlistIdInt));
                ref.invalidate(playlistSongsProvider(_playlistIdInt));
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  String _getLabelName(String label) {
    switch (label) {
      case 'built_in':
        return '内置';
      case 'auto_created':
        return '自动创建';
      default:
        return label;
    }
  }

  /// 显示编辑对话框
  Future<void> _showEditDialog(Playlist playlist) async {
    final nameController = TextEditingController(text: playlist.name);
    final descController = TextEditingController(text: playlist.description);

    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑歌单'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '歌单名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: '歌单描述',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop({
              'name': nameController.text.trim(),
              'description': descController.text.trim().isEmpty
                  ? null
                  : descController.text.trim(),
            }),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && result['name']?.isNotEmpty == true && mounted) {
      final notifier = ref.read(playlistNotifierProvider.notifier);
      await notifier.updatePlaylist(
        playlist.id,
        name: result['name'],
        description: result['description'],
      );
    }
  }

  /// 添加歌曲
  Future<void> _addSongs() async {
    // 获取当前歌单中已有的歌曲 ID，用于排除
    final currentSongs = ref.read(playlistSongsProvider(_playlistIdInt));
    final excludeIds = currentSongs.valueOrNull?.songs
            .map((s) => s.id)
            .toSet() ??
        <int>{};

    // 打开歌曲选择器
    final selectedIds = await SongPickerModal.show(
      context,
      excludeIds: excludeIds,
    );

    if (selectedIds == null || selectedIds.isEmpty || !mounted) return;

    // 添加歌曲到歌单
    final notifier = ref.read(playlistNotifierProvider.notifier);
    final success = await notifier.addSongsToPlaylist(
      _playlistIdInt,
      selectedIds,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 ${selectedIds.length} 首歌曲')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('添加歌曲失败'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// 确认删除歌单
  Future<void> _confirmDelete(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除歌单「${playlist.name}」吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final notifier = ref.read(playlistNotifierProvider.notifier);
      final success = await notifier.deletePlaylist(playlist.id);

      if (success && mounted) {
        // 安全返回：检查是否有可弹出的路由
        if (context.canPop()) {
          context.pop();
        } else {
          // 没有返回栈时，跳转到歌单列表页
          context.go('/playlists');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('歌单已删除')),
        );
      }
    }
  }

  /// 播放全部
  void _playAll(Playlist playlist, List<Song> songs) {
    debugPrint('[Player] Play all ${songs.length} songs in playlist: ${playlist.name}');
    ref.read(playerStateProvider.notifier).playPlaylist(songs);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('播放全部 ${songs.length} 首歌曲')),
    );
  }

  /// 播放单曲
  void _playSong(Song song, List<Song> songs, int index) {
    debugPrint('[Player] Play song: ${song.title} at index $index');
    ref.read(playerStateProvider.notifier).playPlaylist(songs, startIndex: index);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('播放：${song.title}')),
    );
  }

  /// 从歌单移除歌曲
  Future<void> _removeSong(int playlistId, Song song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除歌曲'),
        content: Text('确定要从歌单中移除「${song.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final notifier = ref.read(playlistNotifierProvider.notifier);
      final success = await notifier.removeSongFromPlaylist(playlistId, song.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('歌曲已移除')),
        );
      }
    }
  }
}

/// 歌曲列表项组件
class _SongListTile extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  /// 是否显示拖拽手柄（排序模式）
  final bool showDragHandle;

  /// 是否显示复选框（多选模式）
  final bool showCheckbox;

  /// 复选框是否选中
  final bool isChecked;

  /// 复选框状态变化回调
  final ValueChanged<bool?>? onCheckChanged;

  /// 是否显示尾部操作按钮（时长 + 更多菜单）
  final bool showTrailing;

  const _SongListTile({
    super.key,
    required this.song,
    required this.index,
    required this.onTap,
    required this.onRemove,
    this.showDragHandle = false,
    this.showCheckbox = false,
    this.isChecked = false,
    this.onCheckChanged,
    this.showTrailing = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final coverUrl = CoverUrl.buildCoverUrl(
      coverUrl: song.coverUrl,
      coverPath: song.coverPath,
    );

    return ListTile(
      onTap: onTap,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽手柄（排序模式）
          if (showDragHandle)
            ReorderableDragStartListener(
              index: index - 1,
              child: Icon(
                Icons.drag_handle,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          // 复选框（多选模式）
          else if (showCheckbox)
            SizedBox(
              width: 32,
              child: Checkbox(
                value: isChecked,
                onChanged: onCheckChanged,
              ),
            )
          // 序号（正常模式）
          else
            SizedBox(
              width: 32,
              child: Text(
                '$index',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(width: 8),
          // 封面
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 48,
              height: 48,
              child: coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildCoverPlaceholder(colorScheme),
                      errorWidget: (context, url, error) =>
                          _buildCoverPlaceholder(colorScheme),
                    )
                  : _buildCoverPlaceholder(colorScheme),
            ),
          ),
        ],
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        song.artist ?? '未知艺术家',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: showTrailing
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 时长
                Text(
                  Formatters.formatDuration(song.duration),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                // 更多按钮
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (value) {
                    if (value == 'remove') {
                      onRemove();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'remove',
                      child: ListTile(
                        leading: Icon(
                          Icons.remove_circle_outline,
                          color: colorScheme.error,
                        ),
                        title: Text(
                          '从歌单移除',
                          style: TextStyle(color: colorScheme.error),
                        ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildCoverPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.music_note,
        size: 24,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}
