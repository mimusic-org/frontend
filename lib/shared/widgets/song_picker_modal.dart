import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../../features/library/presentation/providers/songs_provider.dart';
import 'cover_image.dart';

/// 歌曲选择器弹窗组件
/// 用于在歌单详情页中选择要添加的歌曲
class SongPickerModal extends ConsumerStatefulWidget {
  /// 要排除的歌曲 ID（已在歌单中的歌曲）
  final Set<int> excludeIds;

  const SongPickerModal({
    super.key,
    this.excludeIds = const {},
  });

  /// 显示歌曲选择器弹窗
  /// 
  /// [context] 上下文
  /// [excludeIds] 要排除的歌曲 ID
  /// 
  /// 返回选中的歌曲 ID 列表，取消返回 null
  static Future<List<int>?> show(
    BuildContext context, {
    Set<int> excludeIds = const {},
  }) {
    return showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SongPickerModal(excludeIds: excludeIds),
    );
  }

  @override
  ConsumerState<SongPickerModal> createState() => _SongPickerModalState();
}

class _SongPickerModalState extends ConsumerState<SongPickerModal> {
  /// 当前加载的歌曲列表（已过滤 excludeIds）
  List<Song> _songs = [];

  /// 选中的歌曲 ID
  final Set<int> _selectedIds = {};

  /// 搜索控制器
  final TextEditingController _searchController = TextEditingController();

  /// 滚动控制器
  final ScrollController _scrollController = ScrollController();

  /// 是否正在加载
  bool _isLoading = false;

  /// 是否正在加载更多
  bool _isLoadingMore = false;

  /// 是否还有更多数据
  bool _hasMore = true;

  /// 当前页码
  int _currentPage = 0;

  /// 防抖定时器
  Timer? _debounceTimer;

  /// 每页大小
  static const int _pageSize = 20;

  /// 防抖延迟时间（毫秒）
  static const int _debounceDelay = 300;

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// 滚动监听
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      _loadMore();
    }
  }

  /// 加载歌曲列表
  Future<void> _loadSongs({bool reset = true}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (reset) {
        _currentPage = 0;
        _songs = [];
        _hasMore = true;
      }
    });

    try {
      final repository = ref.read(songsRepositoryProvider);
      final keyword = _searchController.text.trim();

      final response = await repository.getSongs(
        keyword: keyword.isNotEmpty ? keyword : null,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );

      // 过滤掉 excludeIds 中的歌曲
      final filteredSongs = response.songs
          .where((song) => !widget.excludeIds.contains(song.id))
          .toList();

      setState(() {
        if (reset) {
          _songs = filteredSongs;
        } else {
          _songs = [..._songs, ...filteredSongs];
        }
        _hasMore = response.songs.length >= _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  /// 加载更多
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    await _loadSongs(reset: false);

    setState(() {
      _isLoadingMore = false;
    });
  }

  /// 搜索（带防抖）
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: _debounceDelay), () {
      _loadSongs();
    });
  }

  /// 清除搜索
  void _clearSearch() {
    _searchController.clear();
    _loadSongs();
  }

  /// 切换歌曲选中状态
  void _toggleSongSelection(int songId) {
    setState(() {
      if (_selectedIds.contains(songId)) {
        _selectedIds.remove(songId);
      } else {
        _selectedIds.add(songId);
      }
    });
  }

  /// 全选/取消全选
  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _songs.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_songs.map((s) => s.id));
      }
    });
  }

  /// 确认选择
  void _onConfirm() {
    if (_selectedIds.isEmpty) return;
    Navigator.of(context).pop(_selectedIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 拖拽指示器
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withAlpha(100),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  '选择歌曲',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _selectedIds.isEmpty ? null : _onConfirm,
                  child: Text('确定(${_selectedIds.length})'),
                ),
              ],
            ),
          ),

          // 搜索框
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '搜索歌曲、艺术家或专辑',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // 全选行
          if (_songs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: InkWell(
                onTap: _toggleSelectAll,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _selectedIds.length == _songs.length,
                        onChanged: (_) => _toggleSelectAll(),
                      ),
                      const Text('全选'),
                    ],
                  ),
                ),
              ),
            ),

          // 歌曲列表
          Expanded(
            child: _isLoading && _songs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _songs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.music_note,
                              size: 64,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? '暂无歌曲'
                                  : '未找到匹配的歌曲',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _songs.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _songs.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final song = _songs[index];
                          final isSelected = _selectedIds.contains(song.id);

                          return InkWell(
                            onTap: () => _toggleSongSelection(song.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (_) => _toggleSongSelection(song.id),
                                  ),
                                  const SizedBox(width: 8),
                                  CoverImage(
                                    coverUrl: song.coverUrl,
                                    coverPath: song.coverPath,
                                    size: 48,
                                    borderRadius: 8,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (song.artist != null)
                                          Text(
                                            song.artist!,
                                            style: TextStyle(
                                              color: colorScheme.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
