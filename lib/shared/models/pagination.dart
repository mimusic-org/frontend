/// 分页参数模型
class PaginationParams {
  /// 每页数量
  final int limit;

  /// 偏移量
  final int offset;

  const PaginationParams({
    this.limit = 20,
    this.offset = 0,
  });

  /// 转换为查询参数
  Map<String, String> toQueryParams() => {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

  /// 获取下一页参数
  PaginationParams nextPage() => PaginationParams(
        limit: limit,
        offset: offset + limit,
      );

  /// 获取上一页参数
  PaginationParams? previousPage() {
    if (offset <= 0) return null;
    return PaginationParams(
      limit: limit,
      offset: (offset - limit).clamp(0, offset),
    );
  }

  /// 获取指定页参数（从 0 开始）
  PaginationParams page(int pageIndex) => PaginationParams(
        limit: limit,
        offset: pageIndex * limit,
      );

  /// 当前页码（从 0 开始）
  int get currentPage => offset ~/ limit;

  @override
  String toString() => 'PaginationParams(limit: $limit, offset: $offset)';
}

/// 分页响应模型
class PaginatedResponse<T> {
  /// 数据列表
  final List<T> items;

  /// 总数量
  final int total;

  /// 当前偏移量
  final int offset;

  /// 每页数量
  final int limit;

  const PaginatedResponse({
    required this.items,
    required this.total,
    this.offset = 0,
    this.limit = 20,
  });

  /// 是否有更多数据
  bool get hasMore => offset + items.length < total;

  /// 是否为空
  bool get isEmpty => items.isEmpty;

  /// 是否非空
  bool get isNotEmpty => items.isNotEmpty;

  /// 当前页码（从 0 开始）
  int get currentPage => offset ~/ limit;

  /// 总页数
  int get totalPages => (total / limit).ceil();

  /// 获取下一页参数
  PaginationParams? nextPageParams() {
    if (!hasMore) return null;
    return PaginationParams(
      limit: limit,
      offset: offset + limit,
    );
  }

  /// 从 JSON 解析
  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final items = (json['items'] as List<dynamic>?)
            ?.map((e) => fromJsonT(e as Map<String, dynamic>))
            .toList() ??
        [];
    
    return PaginatedResponse(
      items: items,
      total: json['total'] as int? ?? items.length,
      offset: json['offset'] as int? ?? 0,
      limit: json['limit'] as int? ?? 20,
    );
  }

  /// 合并两个分页响应（用于无限滚动）
  PaginatedResponse<T> merge(PaginatedResponse<T> other) {
    return PaginatedResponse(
      items: [...items, ...other.items],
      total: other.total,
      offset: other.offset,
      limit: other.limit,
    );
  }

  @override
  String toString() =>
      'PaginatedResponse(items: ${items.length}, total: $total, offset: $offset, hasMore: $hasMore)';
}
