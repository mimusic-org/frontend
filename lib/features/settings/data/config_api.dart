import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_exceptions.dart';

/// 配置项模型
class Config {
  final int? id;
  final String key;
  final String value; // JSON 字符串
  final DateTime? updatedAt;

  Config({
    this.id,
    required this.key,
    required this.value,
    this.updatedAt,
  });

  factory Config.fromJson(Map<String, dynamic> json) {
    return Config(
      id: json['id'] as int?,
      key: json['key'] as String,
      value: json['value'] as String,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'key': key,
      'value': value,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  @override
  String toString() => 'Config(key: $key, value: $value)';
}

/// 配置 API 服务
class ConfigApi {
  final Dio dio;

  ConfigApi({required this.dio});

  /// 获取所有配置
  /// GET /api/v1/configs
  Future<List<Config>> getConfigs() async {
    try {
      final response = await dio.get('${AppConfig.apiPrefix}/configs');
      final data = response.data['configs'] as List<dynamic>;
      return data
          .map((e) => Config.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 创建配置
  /// POST /api/v1/configs
  Future<Config> createConfig({
    required String key,
    required String value,
  }) async {
    try {
      final response = await dio.post(
        '${AppConfig.apiPrefix}/configs',
        data: {
          'key': key,
          'value': value,
        },
      );
      return Config.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取单个配置
  /// GET /api/v1/configs/{key}
  Future<Config> getConfig(String key) async {
    try {
      final response = await dio.get('${AppConfig.apiPrefix}/configs/$key');
      return Config.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 更新配置
  /// PUT /api/v1/configs/{key}
  Future<Config> updateConfig({
    required String key,
    required String value,
  }) async {
    try {
      final response = await dio.put(
        '${AppConfig.apiPrefix}/configs/$key',
        data: {'value': value},
      );
      return Config.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 删除配置
  /// DELETE /api/v1/configs/{key}
  Future<void> deleteConfig(String key) async {
    try {
      await dio.delete('${AppConfig.apiPrefix}/configs/$key');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
