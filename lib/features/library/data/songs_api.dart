import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../shared/models/song.dart';

/// 歌曲 API 客户端
class SongsApi {
  final Dio dio;

  SongsApi(this.dio);

  /// 获取歌曲列表
  /// [type] 歌曲类型：local, remote, radio（可选）
  /// [keyword] 搜索关键词（可选）
  /// [limit] 每页数量，默认 20
  /// [offset] 偏移量，默认 0
  Future<SongListResponse> getSongs({
    String? type,
    String? keyword,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (type != null && type.isNotEmpty) {
      queryParams['type'] = type;
    }
    if (keyword != null && keyword.isNotEmpty) {
      queryParams['keyword'] = keyword;
    }

    final response = await dio.get<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/songs',
      queryParameters: queryParams,
    );
    return SongListResponse.fromJson(response.data!);
  }

  /// 获取单首歌曲详情
  Future<Song> getSong(int id) async {
    final response = await dio.get<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/songs/$id',
    );
    return Song.fromJson(response.data!);
  }

  /// 创建网络歌曲
  Future<Song> createRemoteSong({
    required String title,
    String? artist,
    String? album,
    required String url,
    String? coverUrl,
    double? duration,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/songs/remote',
      data: {
        'title': title,
        'artist': artist,
        'album': album,
        'url': url,
        'cover_url': coverUrl,
        'duration': duration,
      },
    );
    return Song.fromJson(response.data!);
  }

  /// 创建电台歌曲
  Future<Song> createRadioSong({
    required String title,
    String? artist,
    required String url,
    String? coverUrl,
    bool isLive = false,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/songs/radio',
      data: {
        'title': title,
        'artist': artist,
        'url': url,
        'cover_url': coverUrl,
        'is_live': isLive,
      },
    );
    return Song.fromJson(response.data!);
  }

  /// 更新歌曲
  Future<Song> updateSong(
    int id, {
    String? title,
    String? artist,
    String? album,
    String? url,
    String? coverUrl,
    double? duration,
    bool? isLive,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (artist != null) data['artist'] = artist;
    if (album != null) data['album'] = album;
    if (url != null) data['url'] = url;
    if (coverUrl != null) data['cover_url'] = coverUrl;
    if (duration != null) data['duration'] = duration;
    if (isLive != null) data['is_live'] = isLive;

    final response = await dio.put<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/songs/$id',
      data: data,
    );
    return Song.fromJson(response.data!);
  }

  /// 删除歌曲
  Future<void> deleteSong(int id) async {
    await dio.delete('${AppConfig.apiPrefix}/songs/$id');
  }

  /// 清理无效歌曲
  Future<int> cleanSongs() async {
    final response = await dio.post<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/songs/clean',
    );
    return response.data?['cleaned'] as int? ?? 0;
  }
}
