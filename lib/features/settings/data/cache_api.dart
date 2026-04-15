import 'package:dio/dio.dart';

import '../../../config/app_config.dart';

/// 缓存统计信息
class CacheStats {
  final int totalSize; // 字节
  final int fileCount;
  final int maxSize; // 字节，0 表示无限制

  CacheStats({
    required this.totalSize,
    required this.fileCount,
    required this.maxSize,
  });

  factory CacheStats.fromJson(Map<String, dynamic> json) {
    return CacheStats(
      totalSize: json['total_size'] as int? ?? 0,
      fileCount: json['file_count'] as int? ?? 0,
      maxSize: json['max_size'] as int? ?? 0,
    );
  }
}

/// 缓存配置
class CacheConfig {
  final int maxSize; // 字节，0 表示无限制

  CacheConfig({required this.maxSize});

  factory CacheConfig.fromJson(Map<String, dynamic> json) {
    return CacheConfig(
      maxSize: json['max_size'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'max_size': maxSize};
  }
}

/// 后端缓存管理 API 封装
class CacheApi {
  final Dio dio;

  CacheApi({required this.dio});

  /// 获取缓存统计信息
  Future<CacheStats> getCacheStats() async {
    final response = await dio.get('${AppConfig.apiPrefix}/cache-manage/stats');
    return CacheStats.fromJson(response.data as Map<String, dynamic>);
  }

  /// 清理全部缓存
  Future<void> cleanCache() async {
    await dio.post('${AppConfig.apiPrefix}/cache-manage/clean');
  }

  /// 获取缓存配置
  Future<CacheConfig> getCacheConfig() async {
    final response =
        await dio.get('${AppConfig.apiPrefix}/cache-manage/config');
    return CacheConfig.fromJson(response.data as Map<String, dynamic>);
  }

  /// 更新缓存配置
  Future<void> updateCacheConfig(CacheConfig config) async {
    await dio.put(
      '${AppConfig.apiPrefix}/cache-manage/config',
      data: config.toJson(),
    );
  }
}
