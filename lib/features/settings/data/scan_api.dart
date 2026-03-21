import 'package:dio/dio.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_exceptions.dart';

/// 扫描进度模型
class ScanProgress {
  final String status; // 'idle', 'scanning', 'completed', 'cancelled', 'error'
  final int progress; // 0-100
  final String? currentFile;
  final int totalFiles;
  final int processed;
  final int added;
  final int updated;
  final int failed;

  ScanProgress({
    required this.status,
    required this.progress,
    this.currentFile,
    required this.totalFiles,
    required this.processed,
    required this.added,
    required this.updated,
    required this.failed,
  });

  factory ScanProgress.fromJson(Map<String, dynamic> json) {
    return ScanProgress(
      status: json['status'] as String? ?? 'idle',
      progress: json['progress'] as int? ?? 0,
      currentFile: json['current_file'] as String?,
      totalFiles: json['total_files'] as int? ?? 0,
      processed: json['processed'] as int? ?? 0,
      added: json['added'] as int? ?? 0,
      updated: json['updated'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
    );
  }

  /// 默认空闲状态
  static ScanProgress get idle => ScanProgress(
        status: 'idle',
        progress: 0,
        totalFiles: 0,
        processed: 0,
        added: 0,
        updated: 0,
        failed: 0,
      );

  /// 是否正在扫描
  bool get isScanning => status == 'scanning';

  /// 是否完成
  bool get isCompleted => status == 'completed';

  /// 是否出错
  bool get isError => status == 'error';

  /// 是否已取消
  bool get isCancelled => status == 'cancelled';

  /// 是否空闲
  bool get isIdle => status == 'idle';

  @override
  String toString() =>
      'ScanProgress(status: $status, progress: $progress%, processed: $processed/$totalFiles)';
}

/// 扫描 API 服务
class ScanApi {
  final Dio dio;

  ScanApi({required this.dio});

  /// 开始扫描
  /// POST /api/v1/scan
  Future<void> startScan({bool reimport = false}) async {
    try {
      await dio.post('${AppConfig.apiPrefix}/scan', data: {'reimport': reimport});
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 获取扫描进度
  /// GET /api/v1/scan/progress
  Future<ScanProgress> getProgress() async {
    try {
      final response = await dio.get('${AppConfig.apiPrefix}/scan/progress');
      return ScanProgress.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 取消扫描
  /// POST /api/v1/scan/cancel
  Future<void> cancelScan() async {
    try {
      await dio.post('${AppConfig.apiPrefix}/scan/cancel');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
