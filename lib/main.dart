import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/gestures.dart';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'config/app_config.dart';
import 'core/audio/audio_service.dart';
import 'core/storage/app_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/responsive.dart';
import 'core/router/app_router.dart';
import 'features/settings/presentation/providers/settings_provider.dart';

/// 全局 AudioHandler Provider
final audioHandlerProvider = Provider<MiMusicAudioHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden');
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 全局异常处理，防止未捕获异常导致白屏
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error\n$stack');
    return true;
  };

  if (AppConfig.isEmbedded) {
    // 嵌入模式：Flutter Web 嵌入 Go 后端，直接使用当前页面的 origin 作为后端 API 地址
    // 两者同域，无需手动配置
    AppConfig.baseUrl = Uri.base.origin;
  } else {
    // 独立部署模式：从本地存储恢复用户之前配置的 API 地址
    final prefs = await AppPreferences.create();
    final savedUrl = prefs.getApiBaseUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      AppConfig.baseUrl = savedUrl;
    }
  }

  // Android 13+ 需要运行时请求通知权限
  if (!kIsWeb && Platform.isAndroid) {
    final status = await Permission.notification.status;
    debugPrint('[Main] 📱 Android 平台检测');
    debugPrint('[Main] 通知权限状态: $status');
    if (status.isDenied) {
      debugPrint('[Main] 请求通知权限...');
      final result = await Permission.notification.request();
      debugPrint('[Main] 通知权限请求结果: $result');
    }
    // 检查权限是否永久拒绝
    if (status.isPermanentlyDenied) {
      debugPrint('[Main] ⚠️ 通知权限被永久拒绝，需要在系统设置中手动开启');
    }
  }

  // 初始化 audio_service（带降级保护）
  MiMusicAudioHandler audioHandler;
  try {
    debugPrint('[Main] 🚀 开始初始化 AudioService...');
    debugPrint('[Main] AudioServiceConfig:');
    debugPrint('[Main]   - channelId: com.mimusic.playback');
    debugPrint('[Main]   - channelName: MiMusic 播放控制');

    audioHandler = await AudioService.init<MiMusicAudioHandler>(
      builder: () {
        debugPrint('[Main] 调用 MiMusicAudioHandler builder...');
        return MiMusicAudioHandler();
      },
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.mimusic.playback',
        androidNotificationChannelName: 'MiMusic 播放控制',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    // 等待 handler 内部初始化完成（AudioSession + stream listeners）
    debugPrint('[Main] 等待 handler 初始化完成...');
    await audioHandler.ensureInitialized();
    debugPrint(
      '[Main] ✅ AudioService 初始化成功, handler type: ${audioHandler.runtimeType}',
    );
  } catch (e, stackTrace) {
    debugPrint('[Main] ❌ AudioService.init 失败: $e');
    debugPrint('[Main] Stack trace: $stackTrace');
    debugPrint('[Main] ⚠️ 使用降级 handler (通知栏功能将不可用)');
    audioHandler = MiMusicAudioHandler();
    await audioHandler.ensureInitialized();
  }

  runApp(
    ProviderScope(
      overrides: [
        // 将 audioHandler 注入到 Riverpod 中
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const MiMusicApp(),
    ),
  );
}

/// 支持鼠标拖拽滚动的 ScrollBehavior（macOS / desktop）
class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class MiMusicApp extends ConsumerWidget {
  const MiMusicApp({super.key});

  /// 根据屏幕宽度获取 ScreenType
  ScreenType _getScreenType(double width) {
    if (width >= ResponsiveBreakpoints.tv) return ScreenType.tv;
    if (width >= ResponsiveBreakpoints.desktop) return ScreenType.desktop;
    if (width >= ResponsiveBreakpoints.tablet) return ScreenType.tablet;
    return ScreenType.mobile;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'MiMusic',
      debugShowCheckedModeBanner: false,
      scrollBehavior: _AppScrollBehavior(),
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // 在 builder 中获取 MediaQuery 来应用响应式主题
        final width = MediaQuery.of(context).size.width;
        final screenType = _getScreenType(width);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data:
              isDark
                  ? AppTheme.darkTheme(screenType: screenType)
                  : AppTheme.lightTheme(screenType: screenType),
          child: child!,
        );
      },
    );
  }
}
