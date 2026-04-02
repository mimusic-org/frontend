import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/responsive.dart';
import '../../features/library/presentation/providers/favorite_provider.dart';
import '../../features/player/domain/player_state.dart';
import '../../features/player/presentation/providers/player_provider.dart';
import '../../features/player/presentation/widgets/desktop_player.dart';
import '../../features/player/presentation/widgets/mini_player.dart';
import '../../features/player/presentation/widgets/playlist_drawer.dart';
import '../../features/player/presentation/widgets/tv_player.dart';
import '../utils/responsive_snackbar.dart';
import 'adaptive_scaffold.dart';

/// ShellRoute 的布局组件
/// 整合 AdaptiveScaffold 和路由导航
class ShellLayout extends ConsumerWidget {
  final Widget child;

  const ShellLayout({super.key, required this.child});

  /// 路由路径到导航索引的映射
  static const Map<String, int> _routeToIndex = {
    AppRoutes.home: 0,
    AppRoutes.library: 1,
    AppRoutes.playlists: 2,
    AppRoutes.settings: 3,
  };

  /// 导航索引到路由路径的映射
  static const List<String> _indexToRoute = [
    AppRoutes.home,
    AppRoutes.library,
    AppRoutes.playlists,
    AppRoutes.settings,
  ];

  /// 根据当前路由路径计算导航索引
  int _getCurrentIndex(String location) {
    // 精确匹配
    if (_routeToIndex.containsKey(location)) {
      return _routeToIndex[location]!;
    }

    // 前缀匹配（处理子路由情况，如 /playlists/:id）
    if (location.startsWith('/playlists')) {
      return 2;
    }

    // 默认返回首页索引
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 获取当前路由位置
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _getCurrentIndex(location);

    // 确保收藏系统被初始化（FavoriteNotifier.build 中自动调度）
    ref.watch(favoriteProvider);

    // 监听播放器错误状态
    ref.listen<PlayerState>(playerStateProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        ResponsiveSnackBar.showError(context, message: next.errorMessage!);
      }
    });

    // 监听播放队列侧边栏状态（仅桌面/平板端有效）
    final showPlaylistDrawer = ref.watch(
      playerStateProvider.select((s) => s.showPlaylistDrawer),
    );

    return AdaptiveScaffold(
      body: child,
      currentIndex: currentIndex,
      onDestinationSelected: (index) {
        // 根据索引导航到对应路由
        if (index >= 0 && index < _indexToRoute.length) {
          context.go(_indexToRoute[index]);
        }
      },
      bottomPlayer: _buildBottomPlayer(context),
      playlistDrawer: showPlaylistDrawer ? const PlaylistDrawer() : null,
    );
  }

  /// 根据屏幕类型构建底部播放器
  Widget _buildBottomPlayer(BuildContext context) {
    final screenType = context.screenType;
    switch (screenType) {
      case ScreenType.mobile:
        return const MiniPlayer();
      case ScreenType.tablet:
      case ScreenType.desktop:
        return const DesktopPlayer();
      case ScreenType.tv:
        // 仅在 Android TV 等真正的 TV 平台使用 TvMiniPlayer
        // 桌面/Web 大屏使用 DesktopPlayer 以保留完整工具栏
        if (defaultTargetPlatform == TargetPlatform.android) {
          return const TvMiniPlayer();
        }
        return const DesktopPlayer();
    }
  }
}
