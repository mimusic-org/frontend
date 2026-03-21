import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用偏好设置存储
class AppPreferences {
  static const _themeModeKey = 'theme_mode';
  static const _apiBaseUrlKey = 'api_base_url';
  static const _lastUsedDeviceKey = 'last_used_device';

  final SharedPreferences _prefs;

  AppPreferences(this._prefs);

  /// 异步创建实例
  static Future<AppPreferences> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPreferences(prefs);
  }

  /// 获取主题模式
  ThemeMode getThemeMode() {
    final value = _prefs.getString(_themeModeKey);
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  /// 设置主题模式
  Future<bool> setThemeMode(ThemeMode mode) {
    String value;
    switch (mode) {
      case ThemeMode.light:
        value = 'light';
      case ThemeMode.dark:
        value = 'dark';
      case ThemeMode.system:
        value = 'system';
    }
    return _prefs.setString(_themeModeKey, value);
  }

  /// 获取自定义 API 地址（独立部署模式）
  String? getApiBaseUrl() {
    return _prefs.getString(_apiBaseUrlKey);
  }

  /// 设置自定义 API 地址
  Future<bool> setApiBaseUrl(String url) {
    return _prefs.setString(_apiBaseUrlKey, url);
  }

  /// 清除自定义 API 地址
  Future<bool> clearApiBaseUrl() {
    return _prefs.remove(_apiBaseUrlKey);
  }

  /// 获取最后使用的设备 ID
  String? getLastUsedDevice() {
    return _prefs.getString(_lastUsedDeviceKey);
  }

  /// 设置最后使用的设备 ID
  Future<bool> setLastUsedDevice(String deviceId) {
    return _prefs.setString(_lastUsedDeviceKey, deviceId);
  }

  /// 清除最后使用的设备
  Future<bool> clearLastUsedDevice() {
    return _prefs.remove(_lastUsedDeviceKey);
  }

  /// 清除所有偏好设置
  Future<bool> clear() {
    return _prefs.clear();
  }
}
