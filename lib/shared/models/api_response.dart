/// 通用 API 响应包装类
class ApiResponse<T> {
  /// 响应数据
  final T? data;

  /// 错误信息
  final String? error;

  /// 详细错误信息
  final String? detail;

  const ApiResponse({
    this.data,
    this.error,
    this.detail,
  });

  /// 是否成功
  bool get isSuccess => error == null;

  /// 是否失败
  bool get isError => error != null;

  /// 创建成功响应
  factory ApiResponse.success(T data) {
    return ApiResponse(data: data);
  }

  /// 创建错误响应
  factory ApiResponse.failure(String error, {String? detail}) {
    return ApiResponse(error: error, detail: detail);
  }

  /// 从 JSON 解析（需要提供 data 解析函数）
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    if (json.containsKey('error')) {
      return ApiResponse(
        error: json['error'] as String?,
        detail: json['detail'] as String?,
      );
    }
    
    final data = json['data'];
    return ApiResponse(
      data: fromJsonT != null && data != null ? fromJsonT(data) : data as T?,
    );
  }

  @override
  String toString() {
    if (isError) {
      return 'ApiResponse.error($error, detail: $detail)';
    }
    return 'ApiResponse.success($data)';
  }
}
