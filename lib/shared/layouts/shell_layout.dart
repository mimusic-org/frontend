import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/responsive.dart';
import '../../features/library/presentation/providers/favorite_provider.dart';
import '../../features/player/presentation/widgets/desktop_player.dart';
import '../../features/player/presentation/widgets/mini_player.dart';
import '../../features/player/presentation/widgets/tv_player.dart';
import 'adaptive_scaffold.dart';

/// ShellRoute 的布局组件
/// 整合 AdaptiveScaffold 和路由导航
class ShellLayout extends ConsumerWidget {
  final Widget child;

  const ShellLayout({
    super.key,
    required this.child,
  });

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

    // 初始化收藏系统（幂等操作，多次调用不会重复初始化）
    final favoriteState = ref.watch(favoriteProvider);
    if (!favoriteState.initialized && !favoriteState.isLoading) {
      // 在下一帧中初始化，避免在 build 中直接调用异步方法
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(favoriteProvider.notifier).initialize();
      });
    }

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
        return const TvMiniPlayer();
    }
  }
}
