import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/library/presentation/library_page.dart';
import '../../features/playlist/presentation/playlists_page.dart';
import '../../features/playlist/presentation/playlist_detail_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../shared/layouts/shell_layout.dart';

/// 路由路径常量
class AppRoutes {
  static const String login = '/login';
  static const String home = '/';
  static const String library = '/library';
  static const String playlists = '/playlists';
  static const String playlistDetail = '/playlists/:id';
  static const String settings = '/settings';
}

/// GoRouter Provider
final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggingIn = state.uri.path == AppRoutes.login;

      // 未认证且不在登录页面，跳转到登录页
      if (!isAuthenticated && !isLoggingIn) {
        return AppRoutes.login;
      }

      // 已认证且在登录页面，跳转到首页
      if (isAuthenticated && isLoggingIn) {
        return AppRoutes.home;
      }

      // 其他情况不做跳转
      return null;
    },
    routes: [
      // 登录页面（独立路由，不使用 ShellRoute）
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),

      // 主应用路由（使用 ShellRoute 包含导航和播放器）
      ShellRoute(
        builder: (context, state, child) => ShellLayout(child: child),
        routes: [
          // 首页
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomePage(),
            ),
          ),

          // 歌曲库
          GoRoute(
            path: AppRoutes.library,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LibraryPage(),
            ),
          ),

          // 歌单列表
          GoRoute(
            path: AppRoutes.playlists,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PlaylistsPage(),
            ),
          ),

          // 歌单详情
          GoRoute(
            path: AppRoutes.playlistDetail,
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return PlaylistDetailPage(playlistId: id);
            },
          ),

          // 设置
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsPage(),
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '页面未找到',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.path,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.home),
              icon: const Icon(Icons.home),
              label: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),
  );
});
