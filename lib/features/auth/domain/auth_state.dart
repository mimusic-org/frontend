/// 认证 Token 响应
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.tokenType = 'Bearer',
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
      tokenType: json['token_type'] as String? ?? 'Bearer',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_in': expiresIn,
      'token_type': tokenType,
    };
  }

  @override
  String toString() =>
      'AuthTokens(tokenType: $tokenType, expiresIn: $expiresIn)';
}

/// Token 信息（用于 Token 管理列表）
class TokenInfo {
  final int id;
  final String tokenId;
  final String tokenType; // 'access' or 'refresh'
  final String? clientInfo;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final DateTime createdAt;

  TokenInfo({
    required this.id,
    required this.tokenId,
    required this.tokenType,
    this.clientInfo,
    required this.expiresAt,
    this.revokedAt,
    required this.createdAt,
  });

  factory TokenInfo.fromJson(Map<String, dynamic> json) {
    return TokenInfo(
      id: json['id'] as int,
      tokenId: json['token_id'] as String,
      tokenType: json['token_type'] as String,
      clientInfo: json['client_info'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      revokedAt: json['revoked_at'] != null
          ? DateTime.parse(json['revoked_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'token_id': tokenId,
      'token_type': tokenType,
      'client_info': clientInfo,
      'expires_at': expiresAt.toIso8601String(),
      'revoked_at': revokedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// 是否已被撤销
  bool get isRevoked => revokedAt != null;

  /// 是否已过期
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// 是否有效
  bool get isValid => !isRevoked && !isExpired;
}

/// Token 列表响应
class TokenListResponse {
  final List<TokenInfo> tokens;
  final int total;

  TokenListResponse({
    required this.tokens,
    required this.total,
  });

  factory TokenListResponse.fromJson(Map<String, dynamic> json) {
    final tokensList = json['tokens'] as List<dynamic>;
    return TokenListResponse(
      tokens: tokensList
          .map((e) => TokenInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as int?) ?? tokensList.length,
    );
  }
}

/// 认证状态枚举
enum AuthStatus {
  /// 未知状态（应用刚启动，还没检查过）
  unknown,

  /// 已认证
  authenticated,

  /// 未认证
  unauthenticated,
}

/// 认证状态
class AuthState {
  final AuthStatus status;
  final String? error;
  final bool isLoading;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.error,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? error,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// 初始状态
  static const initial = AuthState();

  /// 加载中状态
  AuthState loading() => copyWith(isLoading: true, error: null);

  /// 认证成功状态
  AuthState authenticated() => copyWith(
        status: AuthStatus.authenticated,
        isLoading: false,
        error: null,
      );

  /// 未认证状态
  AuthState unauthenticated([String? error]) => copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        error: error,
      );

  @override
  String toString() =>
      'AuthState(status: $status, isLoading: $isLoading, error: $error)';
}
