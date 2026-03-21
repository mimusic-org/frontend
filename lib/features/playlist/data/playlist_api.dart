import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../shared/models/song.dart';
import '../domain/playlist.dart';

/// 歌单 API 客户端
class PlaylistApi {
  final Dio dio;

  PlaylistApi(this.dio);

  /// 获取歌单列表
  /// GET /api/v1/playlists?type=normal&limit=20&offset=0
  Future<PlaylistListResponse> getPlaylists({
    String? type,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (type != null) {
      queryParams['type'] = type;
    }

    final response = await dio.get(
      '${AppConfig.apiPrefix}/playlists',
      queryParameters: queryParams,
    );
    return PlaylistListResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// 创建歌单
  /// POST /api/v1/playlists
  Future<Playlist> createPlaylist({
    required String type,
    required String name,
    String? description,
    String? coverPath,
  }) async {
    final data = <String, dynamic>{
      'type': type,
      'name': name,
    };
    if (description != null) {
      data['description'] = description;
    }
    if (coverPath != null) {
      data['cover_path'] = coverPath;
    }

    final response = await dio.post(
      '${AppConfig.apiPrefix}/playlists',
      data: data,
    );
    return Playlist.fromJson(response.data as Map<String, dynamic>);
  }

  /// 获取歌单详情
  /// GET /api/v1/playlists/{id}
  Future<Playlist> getPlaylist(int id) async {
    final response = await dio.get('${AppConfig.apiPrefix}/playlists/$id');
    return Playlist.fromJson(response.data as Map<String, dynamic>);
  }

  /// 更新歌单
  /// PUT /api/v1/playlists/{id}
  Future<Playlist> updatePlaylist(
    int id, {
    String? name,
    String? description,
    String? coverPath,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) {
      data['name'] = name;
    }
    if (description != null) {
      data['description'] = description;
    }
    if (coverPath != null) {
      data['cover_path'] = coverPath;
    }

    final response = await dio.put(
      '${AppConfig.apiPrefix}/playlists/$id',
      data: data,
    );
    return Playlist.fromJson(response.data as Map<String, dynamic>);
  }

  /// 删除歌单
  /// DELETE /api/v1/playlists/{id}
  Future<void> deletePlaylist(int id) async {
    await dio.delete('${AppConfig.apiPrefix}/playlists/$id');
  }

  /// 自动创建歌单（根据目录结构）
  /// POST /api/v1/playlists/auto-create
  Future<void> autoCreatePlaylists() async {
    await dio.post('${AppConfig.apiPrefix}/playlists/auto-create');
  }

  /// 获取歌单内歌曲
  /// GET /api/v1/playlists/{id}/songs?limit=20&offset=0
  Future<SongListResponse> getPlaylistSongs(
    int id, {
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await dio.get(
      '${AppConfig.apiPrefix}/playlists/$id/songs',
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
    );
    return SongListResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// 向歌单添加歌曲
  /// POST /api/v1/playlists/{id}/songs
  Future<void> addSongsToPlaylist(int id, List<int> songIds) async {
    await dio.post(
      '${AppConfig.apiPrefix}/playlists/$id/songs',
      data: {'song_ids': songIds},
    );
  }

  /// 重新排序歌单内歌曲
  /// PUT /api/v1/playlists/{id}/songs/reorder
  Future<void> reorderPlaylistSongs(int id, List<int> songIds) async {
    await dio.put(
      '${AppConfig.apiPrefix}/playlists/$id/songs/reorder',
      data: {'song_ids': songIds},
    );
  }

  /// 从歌单移除歌曲
  /// DELETE /api/v1/playlists/{id}/songs/{songId}
  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    await dio.delete(
      '${AppConfig.apiPrefix}/playlists/$playlistId/songs/$songId',
    );
  }

  /// 更新歌单最后访问时间
  /// POST /api/v1/playlists/{id}/touch
  Future<void> touchPlaylist(int id) async {
    await dio.post('${AppConfig.apiPrefix}/playlists/$id/touch');
  }
}
