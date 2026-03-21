import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/models/song.dart';
import '../../data/songs_api.dart';
import '../../data/songs_repository.dart';

/// SongsApi Provider
final songsApiProvider = Provider<SongsApi>((ref) {
  final dio = ref.watch(dioProvider);
  return SongsApi(dio);
});

/// SongsRepository Provider
final songsRepositoryProvider = Provider<SongsRepository>((ref) {
  final songsApi = ref.watch(songsApiProvider);
  return SongsRepository(songsApi);
});

/// 歌曲列表状态
class SongsListState {
  final List<Song> songs;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String keyword;
  final String? type;
  final int currentPage;
  final bool hasMore;
  final bool isSelectionMode;
  final Set<int> selectedSongIds;

  const SongsListState({
    this.songs = const [],
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.keyword = '',
    this.type,
    this.currentPage = 0,
    this.hasMore = true,
    this.isSelectionMode = false,
    this.selectedSongIds = const {},
  });

  SongsListState copyWith({
    List<Song>? songs,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? keyword,
    String? type,
    int? currentPage,
    bool? hasMore,
    bool? isSelectionMode,
    Set<int>? selectedSongIds,
    bool clearError = false,
    bool clearType = false,
  }) {
    return SongsListState(
      songs: songs ?? this.songs,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      keyword: keyword ?? this.keyword,
      type: clearType ? null : (type ?? this.type),
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedSongIds: selectedSongIds ?? this.selectedSongIds,
    );
  }
}

/// 歌曲列表状态管理器
class SongsListNotifier extends StateNotifier<SongsListState> {
  final SongsRepository _repository;
  final int _pageSize;

  SongsListNotifier(this._repository, {int pageSize = AppConstants.defaultPageSize})
      : _pageSize = pageSize,
        super(const SongsListState());

  /// 加载歌曲列表
  Future<void> loadSongs({
    int page = 0,
    String? keyword,
    String? type,
    bool clearType = false,
  }) async {
    // 如果要清除 type，传 clearType; 否则传 type
    state = state.copyWith(
      isLoading: true,
      keyword: keyword ?? state.keyword,
      type: clearType ? null : type,
      clearType: clearType,
      currentPage: page,
      clearError: true,
    );

    final effectiveType = clearType ? null : (type ?? state.type);

    try {
      final response = await _repository.getSongs(
        type: effectiveType,
        keyword: keyword ?? state.keyword,
        limit: _pageSize,
        offset: page * _pageSize,
      );

      state = state.copyWith(
        songs: response.songs,
        total: response.total,
        isLoading: false,
        hasMore: response.songs.length >= _pageSize,
        currentPage: page,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 加载更多
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.currentPage + 1;
      final response = await _repository.getSongs(
        type: state.type,
        keyword: state.keyword,
        limit: _pageSize,
        offset: nextPage * _pageSize,
      );

      state = state.copyWith(
        songs: [...state.songs, ...response.songs],
        total: response.total,
        isLoadingMore: false,
        hasMore: response.songs.length >= _pageSize,
        currentPage: nextPage,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  /// 刷新
  Future<void> refresh() async {
    await loadSongs(
      page: 0,
      keyword: state.keyword,
      type: state.type,
    );
  }

  /// 搜索
  Future<void> search(String keyword) async {
    await loadSongs(
      page: 0,
      keyword: keyword,
      type: state.type,
    );
  }

  /// 设置类型筛选
  Future<void> setTypeFilter(String? type) async {
    if (type == null) {
      // 点击"全部"时，清除 type 筛选
      await loadSongs(
        page: 0,
        keyword: state.keyword,
        clearType: true,
      );
    } else {
      await loadSongs(
        page: 0,
        keyword: state.keyword,
        type: type,
      );
    }
  }

  /// 切换多选模式
  void toggleSelectMode() {
    if (state.isSelectionMode) {
      state = state.copyWith(
        isSelectionMode: false,
        selectedSongIds: {},
      );
    } else {
      state = state.copyWith(isSelectionMode: true);
    }
  }

  /// 切换歌曲选中状态
  void toggleSongSelection(int songId) {
    final newSelection = Set<int>.from(state.selectedSongIds);
    if (newSelection.contains(songId)) {
      newSelection.remove(songId);
    } else {
      newSelection.add(songId);
    }
    state = state.copyWith(selectedSongIds: newSelection);
  }

  /// 清除选择
  void clearSelection() {
    state = state.copyWith(selectedSongIds: {});
  }

  /// 全选当前页面歌曲
  void selectAll() {
    final allIds = state.songs.map((s) => s.id).toSet();
    state = state.copyWith(selectedSongIds: allIds);
  }

  /// 删除歌曲
  Future<void> deleteSong(int songId) async {
    try {
      await _repository.deleteSong(songId);
      state = state.copyWith(
        songs: state.songs.where((s) => s.id != songId).toList(),
        total: state.total - 1,
        selectedSongIds: state.selectedSongIds.difference({songId}),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 清理歌曲
  Future<int> cleanSongs() async {
    try {
      final cleaned = await _repository.cleanSongs();
      await refresh();
      return cleaned;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return 0;
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// 歌曲列表 StateNotifierProvider
final songsListProvider =
    StateNotifierProvider<SongsListNotifier, SongsListState>((ref) {
  final repository = ref.watch(songsRepositoryProvider);
  return SongsListNotifier(repository);
});

/// 单首歌曲 Provider
final songDetailProvider =
    FutureProvider.family<Song, int>((ref, songId) async {
  final repository = ref.watch(songsRepositoryProvider);
  return repository.getSong(songId);
});
