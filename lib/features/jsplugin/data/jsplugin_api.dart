import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_exceptions.dart';

/// JS 插件模型
class JSPlugin {
  final int id;
  final String? name;
  final String? version;
  final String? description;
  final String? author;
  final String? homepage;
  final String? entryPath;
  final String? main;
  final List<String> permissions;
  final String filePath;
  final String status; // 'active', 'inactive', 'error'
  final DateTime createdAt;
  final DateTime updatedAt;

  JSPlugin({
    required this.id,
    this.name,
    this.version,
    this.description,
    this.author,
    this.homepage,
    this.entryPath,
    this.main,
    this.permissions = const [],
    required this.filePath,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JSPlugin.fromJson(Map<String, dynamic> json) {
    return JSPlugin(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String?,
      version: json['version'] as String?,
      description: json['description'] as String?,
      author: json['author'] as String?,
      homepage: json['homepage'] as String?,
      entryPath: json['entry_path'] as String?,
      main: json['main'] as String?,
      permissions:
          (json['permissions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      filePath: json['file_path'] as String? ?? '',
      status: json['status'] as String? ?? 'inactive',
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now(),
      updatedAt:
          json['updated_at'] != null
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
  String toString() => 'JSPlugin(id: $id, name: $displayName, status: $status)';
}

/// 单个 JS 插件上传结果
class JSPluginUploadResult {
  final String fileName;
  final JSPlugin? plugin;
  final String? error;
  final bool success;

  JSPluginUploadResult({
    required this.fileName,
    this.plugin,
    this.error,
    required this.success,
  });

  factory JSPluginUploadResult.fromJson(Map<String, dynamic> json) {
    return JSPluginUploadResult(
      fileName: json['file_name'] as String? ?? '',
      plugin:
          json['plugin'] != null
              ? JSPlugin.fromJson(json['plugin'] as Map<String, dynamic>)
              : null,
      error: json['error'] as String?,
      success: json['success'] as bool? ?? false,
    );
  }
}

/// 批量 JS 插件上传响应
class JSPluginUploadResponse {
  final int total;
  final int success;
  final int failed;
  final List<JSPluginUploadResult> results;
  final String message;

  JSPluginUploadResponse({
    required this.total,
    required this.success,
    required this.failed,
    required this.results,
    required this.message,
  });

  factory JSPluginUploadResponse.fromJson(Map<String, dynamic> json) {
    return JSPluginUploadResponse(
      total: json['total'] as int? ?? 0,
      success: json['success'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      results:
          (json['results'] as List<dynamic>?)
              ?.map(
                (e) => JSPluginUploadResult.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      message: json['message'] as String? ?? '',
    );
  }
}

/// JS 插件更新检查结果
class JSPluginUpdateCheck {
  final bool hasUpdate;
  final String currentVersion;
  final String remoteVersion;
  final String downloadUrl;

  JSPluginUpdateCheck({
    required this.hasUpdate,
    required this.currentVersion,
    required this.remoteVersion,
    required this.downloadUrl,
  });

  factory JSPluginUpdateCheck.fromJson(Map<String, dynamic> json) {
    return JSPluginUpdateCheck(
      hasUpdate: json['has_update'] as bool? ?? false,
      currentVersion: json['current_version'] as String? ?? '',
      remoteVersion: json['remote_version'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
    );
  }
}

/// JS 插件 API 服务
class JSPluginApi {
  final Dio dio;

  JSPluginApi({required this.dio});

  /// 获取所有 JS 插件
  /// GET /api/v1/jsplugins
  Future<List<JSPlugin>> getPlugins() async {
    try {
      final response = await dio.get('${AppConfig.apiPrefix}/jsplugins');
      final list = response.data['plugins'] as List<dynamic>? ?? [];
      return list
          .map((e) => JSPlugin.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取单个 JS 插件
  /// GET /api/v1/jsplugins/{id}
  Future<JSPlugin> getPlugin(int id) async {
    try {
      final response = await dio.get('${AppConfig.apiPrefix}/jsplugins/$id');
      final data = response.data as Map<String, dynamic>;
      return JSPlugin.fromJson(data['plugin'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 上传 JS 插件（从文件路径，适用于原生平台）
  /// POST /api/v1/jsplugins/upload (multipart)
  Future<JSPluginUploadResponse> uploadPlugin(
    String filePath,
    String fileName,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final response = await dio.post(
        '${AppConfig.apiPrefix}/jsplugins/upload',
        data: formData,
      );
      return JSPluginUploadResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 上传 JS 插件（从字节数据，适用于 Web 平台）
  /// POST /api/v1/jsplugins/upload (multipart)
  Future<JSPluginUploadResponse> uploadPluginBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      });
      final response = await dio.post(
        '${AppConfig.apiPrefix}/jsplugins/upload',
        data: formData,
      );
      return JSPluginUploadResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 删除 JS 插件
  /// DELETE /api/v1/jsplugins/{id}
  Future<void> deletePlugin(int id) async {
    try {
      await dio.delete('${AppConfig.apiPrefix}/jsplugins/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 启用 JS 插件
  /// POST /api/v1/jsplugins/{id}/enable
  Future<JSPlugin> enablePlugin(int id) async {
    try {
      final response = await dio.post(
        '${AppConfig.apiPrefix}/jsplugins/$id/enable',
      );
      final data = response.data as Map<String, dynamic>;
      return JSPlugin.fromJson(data['plugin'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 禁用 JS 插件
  /// POST /api/v1/jsplugins/{id}/disable
  Future<JSPlugin> disablePlugin(int id) async {
    try {
      final response = await dio.post(
        '${AppConfig.apiPrefix}/jsplugins/$id/disable',
      );
      final data = response.data as Map<String, dynamic>;
      return JSPlugin.fromJson(data['plugin'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 检查 JS 插件更新
  /// GET /api/v1/jsplugins/{id}/check-update
  Future<JSPluginUpdateCheck> checkUpdate(int id, {String? proxy}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (proxy != null && proxy.isNotEmpty) {
        queryParams['proxy'] = proxy;
      }
      final response = await dio.get(
        '${AppConfig.apiPrefix}/jsplugins/$id/check-update',
        queryParameters: queryParams,
      );
      return JSPluginUpdateCheck.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 执行 JS 插件更新
  /// POST /api/v1/jsplugins/{id}/update
  Future<void> updatePlugin(int id, {String? proxy}) async {
    try {
      final body = <String, dynamic>{};
      if (proxy != null && proxy.isNotEmpty) {
        body['proxy'] = proxy;
      }
      await dio.post('${AppConfig.apiPrefix}/jsplugins/$id/update', data: body);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
