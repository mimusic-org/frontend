import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Token 安全存储服务
/// 优先使用 FlutterSecureStorage，在不支持的平台（如 macOS 沙箱未签名）自动回退到 SharedPreferences
class SecureStorageService {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _tokenExpiresAtKey = 'token_expires_at';
  static const _fallbackPrefix = 'secure_fallback_';

  /// 同步缓存的 Access Token，供需要同步访问 token 的地方使用（如构建 URL）
  static String? cachedAccessToken;

  final FlutterSecureStorage _storage;
  bool _useFallback = false;
  SharedPreferences? _prefs;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  Future<void> _write(String key, String value) async {
    if (_useFallback) {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString('$_fallbackPrefix$key', value);
      return;
    }
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('SecureStorage write failed, using fallback: $e');
      _useFallback = true;
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString('$_fallbackPrefix$key', value);
    }
  }

  Future<String?> _read(String key) async {
    if (_useFallback) {
      _prefs ??= await SharedPreferences.getInstance();
      return _prefs!.getString('$_fallbackPrefix$key');
    }
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('SecureStorage read failed, using fallback: $e');
      _useFallback = true;
      _prefs ??= await SharedPreferences.getInstance();
      return _prefs!.getString('$_fallbackPrefix$key');
    }
  }

  Future<void> _delete(String key) async {
    if (_useFallback) {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove('$_fallbackPrefix$key');
      return;
    }
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('SecureStorage delete failed, using fallback: $e');
      _useFallback = true;
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove('$_fallbackPrefix$key');
    }
  }

  /// 保存 Access Token
  Future<void> saveAccessToken(String token) async {
    cachedAccessToken = token;
    await _write(_accessTokenKey, token);
  }

  /// 获取 Access Token
  Future<String?> getAccessToken() async {
    final token = await _read(_accessTokenKey);
    cachedAccessToken = token;
    return token;
  }

  /// 保存 Refresh Token
  Future<void> saveRefreshToken(String token) async {
    await _write(_refreshTokenKey, token);
  }

  /// 获取 Refresh Token
  Future<String?> getRefreshToken() async {
    return _read(_refreshTokenKey);
  }

  /// 一次性保存所有 Token 信息
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) async {
    cachedAccessToken = accessToken;
    final expiresAt =
        DateTime.now().add(Duration(seconds: expiresIn)).toIso8601String();

    await Future.wait([
      _write(_accessTokenKey, accessToken),
      _write(_refreshTokenKey, refreshToken),
      _write(_tokenExpiresAtKey, expiresAt),
    ]);
  }

  /// 清除所有 Token
  Future<void> clearTokens() async {
    cachedAccessToken = null;
    await Future.wait([
      _delete(_accessTokenKey),
      _delete(_refreshTokenKey),
      _delete(_tokenExpiresAtKey),
    ]);
  }

  /// 检查是否有 Token
  Future<bool> hasTokens() async {
    final accessToken = await getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  /// 获取 Token 过期时间
  Future<DateTime?> getTokenExpiresAt() async {
    final expiresAt = await _read(_tokenExpiresAtKey);
    if (expiresAt == null) return null;
    return DateTime.tryParse(expiresAt);
  }

  /// 检查 Access Token 是否已过期
  Future<bool> isAccessTokenExpired() async {
    final expiresAt = await getTokenExpiresAt();
    if (expiresAt == null) return true;
    // 提前 30 秒认为过期，以便有时间刷新
    return DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 30)));
  }
}
