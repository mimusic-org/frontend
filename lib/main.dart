import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/app_config.dart';
import 'core/storage/app_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/settings/presentation/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web 平台禁用 Google Fonts 运行时加载，避免从 Google CDN 拉取字体资源
  if (kIsWeb) {
    GoogleFonts.config.allowRuntimeFetching = false;
  }

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

  runApp(
    const ProviderScope(
      child: MiMusicApp(),
    ),
  );
}

class MiMusicApp extends ConsumerWidget {
  const MiMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'MiMusic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
