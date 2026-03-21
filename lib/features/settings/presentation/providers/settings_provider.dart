import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/config_api.dart';
import '../../data/plugin_api.dart';
import '../../data/scan_api.dart';
import '../../data/upgrade_api.dart';

// ============================================================================
// API Providers
// ============================================================================

/// ConfigApi Provider
final configApiProvider = Provider<ConfigApi>((ref) {
  final dio = ref.watch(dioProvider);
  return ConfigApi(dio: dio);
});

/// ScanApi Provider
final scanApiProvider = Provider<ScanApi>((ref) {
  final dio = ref.watch(dioProvider);
  return ScanApi(dio: dio);
});

/// PluginApi Provider
final pluginApiProvider = Provider<PluginApi>((ref) {
  final dio = ref.watch(dioProvider);
  return PluginApi(dio: dio);
});

/// UpgradeApi Provider
final upgradeApiProvider = Provider<UpgradeApi>((ref) {
  final dio = ref.watch(dioProvider);
  return UpgradeApi(dio: dio);
});

// ============================================================================
// Data Providers
// ============================================================================

/// 获取所有配置
final configsProvider = FutureProvider<List<Config>>((ref) async {
  final configApi = ref.watch(configApiProvider);
  return configApi.getConfigs();
});

/// 获取插件列表
final pluginsProvider = FutureProvider<List<Plugin>>((ref) async {
  final pluginApi = ref.watch(pluginApiProvider);
  return pluginApi.getPlugins();
});

/// 检查更新
final upgradeCheckProvider = FutureProvider<UpgradeCheck>((ref) async {
  final upgradeApi = ref.watch(upgradeApiProvider);
  return upgradeApi.checkUpgrade();
});

// ============================================================================
// Theme Mode Provider
// ============================================================================

/// 主题模式 Notifier
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;

  ThemeModeNotifier(this._ref) : super(ThemeMode.system) {
    _loadThemeMode();
  }

  /// 从 AppPreferences 加载主题模式
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await _ref.read(appPreferencesProvider.future);
      state = prefs.getThemeMode();
    } catch (e) {
      // 加载失败使用默认值
      state = ThemeMode.system;
    }
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await _ref.read(appPreferencesProvider.future);
      await prefs.setThemeMode(mode);
    } catch (e) {
      // 保存失败忽略
    }
  }
}

/// 主题模式 Provider
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref);
});

// ============================================================================
// Scan Progress Provider
// ============================================================================

/// 扫描进度 Notifier
class ScanProgressNotifier extends StateNotifier<ScanProgress> {
  final ScanApi _scanApi;
  Timer? _pollTimer;

  ScanProgressNotifier(this._scanApi) : super(ScanProgress.idle);

  /// 开始扫描
  Future<void> startScan({bool reimport = false}) async {
    try {
      await _scanApi.startScan(reimport: reimport);
      // 开始轮询进度
      _startPolling();
    } catch (e) {
      state = ScanProgress(
        status: 'error',
        progress: 0,
        totalFiles: 0,
        processed: 0,
        added: 0,
        updated: 0,
        failed: 0,
      );
      rethrow;
    }
  }

  /// 取消扫描
  Future<void> cancelScan() async {
    try {
      await _scanApi.cancelScan();
      _stopPolling();
      state = ScanProgress(
        status: 'cancelled',
        progress: state.progress,
        totalFiles: state.totalFiles,
        processed: state.processed,
        added: state.added,
        updated: state.updated,
        failed: state.failed,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// 刷新进度
  Future<void> refreshProgress() async {
    try {
      state = await _scanApi.getProgress();

      // 如果扫描完成或出错，停止轮询
      if (state.isCompleted || state.isError || state.isCancelled) {
        _stopPolling();
      }
    } catch (e) {
      // 获取进度失败忽略
    }
  }

  /// 重置状态
  void reset() {
    _stopPolling();
    state = ScanProgress.idle;
  }

  /// 开始轮询
  void _startPolling() {
    _stopPolling();
    // 每 2 秒轮询一次
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      refreshProgress();
    });
    // 立即获取一次
    refreshProgress();
  }

  /// 停止轮询
  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}

/// 扫描进度 Provider
final scanProgressProvider =
    StateNotifierProvider<ScanProgressNotifier, ScanProgress>((ref) {
  final scanApi = ref.watch(scanApiProvider);
  return ScanProgressNotifier(scanApi);
});

// ============================================================================
// Upgrade Progress Provider
// ============================================================================

/// 升级进度 Notifier
class UpgradeProgressNotifier extends StateNotifier<UpgradeProgress> {
  final UpgradeApi _upgradeApi;
  Timer? _pollTimer;

  UpgradeProgressNotifier(this._upgradeApi) : super(UpgradeProgress.idle);

  /// 开始升级
  Future<void> startUpgrade() async {
    try {
      await _upgradeApi.startUpgrade();
      _startPolling();
    } catch (e) {
      state = UpgradeProgress(
        status: 'error',
        progress: 0,
        message: e.toString(),
      );
      rethrow;
    }
  }

  /// 刷新进度
  Future<void> refreshProgress() async {
    try {
      state = await _upgradeApi.getProgress();

      if (state.isCompleted || state.isError) {
        _stopPolling();
      }
    } catch (e) {
      // 获取进度失败忽略
    }
  }

  /// 重置状态
  void reset() {
    _stopPolling();
    state = UpgradeProgress.idle;
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      refreshProgress();
    });
    refreshProgress();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}

/// 升级进度 Provider
final upgradeProgressProvider =
    StateNotifierProvider<UpgradeProgressNotifier, UpgradeProgress>((ref) {
  final upgradeApi = ref.watch(upgradeApiProvider);
  return UpgradeProgressNotifier(upgradeApi);
});
