import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_exceptions.dart';

/// 插件模型
class Plugin {
  final int id;
  final String? name;
  final String? version;
  final String? description;
  final String? author;
  final String? homepage;
  final String? entryPath;
  final String filePath;
  final String status; // 'active', 'inactive', 'error'
  final DateTime createdAt;
  final DateTime updatedAt;

  Plugin({
    required this.id,
    this.name,
    this.version,
    this.description,
    this.author,
    this.homepage,
    this.entryPath,
    required this.filePath,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Plugin.fromJson(Map<String, dynamic> json) {
    return Plugin(
      id: json['id'] as int,
      name: json['name'] as String?,
      version: json['version'] as String?,
      description: json['description'] as String?,
      author: json['author'] as String?,
      homepage: json['homepage'] as String?,
      entryPath: json['entry_path'] as String?,
      filePath: json['file_path'] as String? ?? '',
      status: json['status'] as String? ?? 'inactive',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  /// 是否激活
  bool get isActive => status == 'active';

  /// 是否出错
  bool get isError => status == 'error';

  /// 显示名称
  String get displayName => name ?? filePath.split('/').last;

  @override
  String toString() => 'Plugin(id: $id, name: $displayName, status: $status)';
}

/// 插件 API 服务
class PluginApi {
  final Dio dio;

  PluginApi({required this.dio});

  /// 获取所有插件
  /// GET /api/v1/plugins
  Future<List<Plugin>> getPlugins() async {
    try {
      final response = await dio.get('${AppConfig.apiPrefix}/plugins');
      final data = response.data['plugins'] as List<dynamic>;
      return data
          .map((e) => Plugin.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 上传插件
  /// POST /api/v1/plugins (multipart)
  Future<Plugin> uploadPlugin(String filePath, String fileName) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final response = await dio.post(
        '${AppConfig.apiPrefix}/plugins',
        data: formData,
      );
      return Plugin.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取单个插件
  /// GET /api/v1/plugins/{id}
  Future<Plugin> getPlugin(int id) async {
    try {
      final response = await dio.get('${AppConfig.apiPrefix}/plugins/$id');
      return Plugin.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 删除插件
  /// DELETE /api/v1/plugins/{id}
  Future<void> deletePlugin(int id) async {
    try {
      await dio.delete('${AppConfig.apiPrefix}/plugins/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 启用插件
  /// POST /api/v1/plugins/{id}/enable
  Future<void> enablePlugin(int id) async {
    try {
      await dio.post('${AppConfig.apiPrefix}/plugins/$id/enable');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 禁用插件
  /// POST /api/v1/plugins/{id}/disable
  Future<void> disablePlugin(int id) async {
    try {
      await dio.post('${AppConfig.apiPrefix}/plugins/$id/disable');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
