import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/constants.dart';
import '../../../core/theme/responsive.dart';
import '../../../shared/widgets/add_to_playlist_modal.dart';
import 'providers/songs_provider.dart';
import 'song_edit_page.dart';
import 'widgets/song_filter_bar.dart';
import 'widgets/song_list_tile.dart';

/// 歌曲库页面
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 初始加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(songsListProvider.notifier).loadSongs();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(songsListProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(songsListProvider.notifier).search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(songsListProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: _buildAppBar(context, state),
      body: Column(
        children: [
          // 搜索栏
          _buildSearchBar(context),
          // 类型筛选栏
          SongFilterBar(
            currentType: state.type,
            onTypeChanged: (type) {
              ref.read(songsListProvider.notifier).setTypeFilter(type);
            },
          ),
          // 错误提示
          if (state.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(Icons.error, color: colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colorScheme.onErrorContainer),
                    onPressed: () {
                      ref.read(songsListProvider.notifier).clearError();
                    },
                  ),
                ],
              ),
            ),
          // 歌曲列表
          Expanded(
            child: _buildSongList(context, state),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, SongsListState state) {
    if (state.isSelectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(songsListProvider.notifier).toggleSelectMode();
          },
        ),
        title: Text('已选择 ${state.selectedSongIds.length} 首'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.playlist_add),
            label: const Text('添加到歌单'),
            onPressed: state.selectedSongIds.isEmpty
                ? null
                : () => _showAddToPlaylistDialog(context, state.selectedSongIds.toList()),
          ),
          TextButton(
            onPressed: () {
              ref.read(songsListProvider.notifier).selectAll();
            },
            child: const Text('全选'),
          ),
        ],
      );
    }

    return AppBar(
      title: const Text('歌曲库'),
      actions: [
        // 多选按钮
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: '多选',
          onPressed: () {
            ref.read(songsListProvider.notifier).toggleSelectMode();
          },
        ),
        // 添加歌曲
        PopupMenuButton<String>(
          icon: const Icon(Icons.add),
          tooltip: '添加歌曲',
          onSelected: (value) {
            if (value == 'remote') {
              _navigateToAddSong(context, AppConstants.songTypeRemote);
            } else if (value == 'radio') {
              _navigateToAddSong(context, AppConstants.songTypeRadio);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'remote',
              child: ListTile(
                leading: Icon(Icons.cloud),
                title: Text('添加网络歌曲'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'radio',
              child: ListTile(
                leading: Icon(Icons.radio),
                title: Text('添加电台'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        // 清理按钮
        IconButton(
          icon: const Icon(Icons.cleaning_services),
          tooltip: '清理无效歌曲',
          onPressed: () => _showCleanConfirmDialog(context),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索歌曲...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(songsListProvider.notifier).search('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildSongList(BuildContext context, SongsListState state) {
    if (state.isLoading && state.songs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.songs.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(songsListProvider.notifier).refresh(),
      child: context.isMobile
          ? _buildMobileList(context, state)
          : _buildDesktopList(context, state),
    );
  }

  Widget _buildMobileList(BuildContext context, SongsListState state) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: state.songs.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.songs.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final song = state.songs[index];
        return SongListTile(
          song: song,
          index: index,
          isSelected: state.selectedSongIds.contains(song.id),
          isSelectionMode: state.isSelectionMode,
          onTap: () => _onSongTap(song),
          onSelect: () {
            ref.read(songsListProvider.notifier).toggleSongSelection(song.id);
          },
          onDelete: () => _showDeleteConfirmDialog(context, song.id),
          onEdit: song.type != AppConstants.songTypeLocal
              ? () => _navigateToEditSong(context, song)
              : null,
          onAddToPlaylist: () => _showAddToPlaylistDialog(context, [song.id]),
        );
      },
    );
  }

  Widget _buildDesktopList(BuildContext context, SongsListState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        // 表头
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              if (state.isSelectionMode)
                const SizedBox(width: 48)
              else
                SizedBox(
                  width: 40,
                  child: Text(
                    '#',
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(width: 52), // 封面空间
              Expanded(
                flex: 3,
                child: Text(
                  '标题',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Text(
                  '艺术家',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Text(
                  '专辑',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 60,
                child: Text(
                  '类型',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 60,
                child: Text(
                  '时长',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(width: 120), // 操作按钮空间
            ],
          ),
        ),
        // 列表
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: state.songs.length + (state.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= state.songs.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final song = state.songs[index];
              return SongListTile(
                song: song,
                index: index,
                isSelected: state.selectedSongIds.contains(song.id),
                isSelectionMode: state.isSelectionMode,
                onTap: () => _onSongTap(song),
                onSelect: () {
                  ref.read(songsListProvider.notifier).toggleSongSelection(song.id);
                },
                onDelete: () => _showDeleteConfirmDialog(context, song.id),
                onEdit: song.type != AppConstants.songTypeLocal
                    ? () => _navigateToEditSong(context, song)
                    : null,
                onAddToPlaylist: () => _showAddToPlaylistDialog(context, [song.id]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(songsListProvider);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_music,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            state.keyword.isNotEmpty ? '未找到匹配的歌曲' : '歌曲库为空',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            state.keyword.isNotEmpty ? '尝试其他关键词' : '添加一些歌曲开始吧',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  void _onSongTap(dynamic song) {
    // TODO: 实现播放功能
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('播放: ${song.title}')),
    );
  }

  void _navigateToAddSong(BuildContext context, String songType) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SongEditPage(songType: songType),
      ),
    );
    if (result == true) {
      ref.read(songsListProvider.notifier).refresh();
    }
  }

  void _navigateToEditSong(BuildContext context, dynamic song) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SongEditPage(song: song, songType: song.type),
      ),
    );
    if (result == true) {
      ref.read(songsListProvider.notifier).refresh();
    }
  }

  void _showDeleteConfirmDialog(BuildContext context, int songId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这首歌曲吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(songsListProvider.notifier).deleteSong(songId);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showCleanConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理歌曲'),
        content: const Text('将清理无效的歌曲记录（如文件已删除的本地歌曲）。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final cleaned = await ref.read(songsListProvider.notifier).cleanSongs();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已清理 $cleaned 首无效歌曲')),
                );
              }
            },
            child: const Text('清理'),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, List<int> songIds) {
    AddToPlaylistModal.show(context, songIds: songIds);
  }
}
