import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_exceptions.dart';

/// 目录条目模型
class DirEntry {
  final String name;
  final String path;
  final bool hasChildren;

  DirEntry({
    required this.name,
    required this.path,
    required this.hasChildren,
  });

  factory DirEntry.fromJson(Map<String, dynamic> json) {
    return DirEntry(
      name: json['name'] as String,
      path: json['path'] as String,
      hasChildren: json['has_children'] as bool? ?? false,
    );
  }
}

/// 目录列表结果
class DirectoryListResult {
  final List<DirEntry> directories;
  final String root;

  DirectoryListResult({
    required this.directories,
    required this.root,
  });

  factory DirectoryListResult.fromJson(Map<String, dynamic> json) {
    final dirs = (json['directories'] as List<dynamic>?)
            ?.map((e) => DirEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return DirectoryListResult(
      directories: dirs,
      root: json['root'] as String? ?? '',
    );
  }
}

/// 清理结果模型
class CleanResult {
  final int total;
  final int fileNotFound;
  final int inExcludedDir;

  CleanResult({
    required this.total,
    required this.fileNotFound,
    required this.inExcludedDir,
  });

  factory CleanResult.fromJson(Map<String, dynamic> json) {
    return CleanResult(
      total: json['total'] as int? ?? 0,
      fileNotFound: json['file_not_found'] as int? ?? 0,
      inExcludedDir: json['in_excluded_dir'] as int? ?? 0,
    );
  }
}

/// 目录 API 服务
class DirectoryApi {
  final Dio dio;

  DirectoryApi({required this.dio});

  /// 获取子目录列表（懒加载）
  /// GET /api/v1/scan/directories?path=
  Future<DirectoryListResult> getDirectories({String? path}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (path != null && path.isNotEmpty) {
        queryParams['path'] = path;
      }
      final response = await dio.get(
        '${AppConfig.apiPrefix}/scan/directories',
        queryParameters: queryParams,
      );
      return DirectoryListResult.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取所有目录名称（自动补全用）
  /// GET /api/v1/scan/dir-names
  Future<List<String>> getDirNames() async {
    try {
      final response =
          await dio.get('${AppConfig.apiPrefix}/scan/dir-names');
      final names = response.data['names'] as List<dynamic>?;
      return names?.map((e) => e as String).toList() ?? [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 清理无效歌曲
  /// POST /api/v1/songs/clean
  Future<CleanResult> cleanInvalidSongs() async {
    try {
      final response =
          await dio.post('${AppConfig.apiPrefix}/songs/clean');
      return CleanResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
