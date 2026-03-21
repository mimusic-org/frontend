import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/responsive.dart';
import '../../playlist/domain/playlist.dart';
import '../../playlist/presentation/providers/playlist_provider.dart';
import '../../settings/data/plugin_api.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import 'widgets/playlist_carousel.dart';
import 'widgets/plugin_grid.dart';

/// 首页
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistListProvider(null));
    final pluginsAsync = ref.watch(pluginsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(playlistListProvider(null));
        },
        child: CustomScrollView(
          slivers: [
            // 顶部 AppBar
            SliverAppBar(
              expandedHeight: context.responsive<double>(
                mobile: 120,
                tablet: 140,
                desktop: 160,
              ),
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  _getGreeting(),
                  style: TextStyle(
                    fontSize: context.responsive<double>(
                      mobile: 20,
                      tablet: 24,
                      desktop: 28,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                titlePadding: EdgeInsets.only(
                  left: context.responsive<double>(mobile: 16, desktop: 24),
                  bottom: 16,
                ),
              ),
            ),

            // 主体内容
            SliverToBoxAdapter(
              child: playlistsAsync.when(
                data: (response) => _buildContent(
                  context,
                  ref,
                  response.playlists,
                  pluginsAsync.valueOrNull ?? [],
                ),
                loading: () => const _LoadingContent(),
                error: (error, stack) => _ErrorContent(
                  error: error.toString(),
                  onRetry: () => ref.invalidate(playlistListProvider(null)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<Playlist> playlists,
    List<Plugin> plugins,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // 分离普通歌单和电台歌单
    final normalPlaylists = playlists.where((p) => p.type == 'normal').toList();
    final radioPlaylists = playlists.where((p) => p.type == 'radio').toList();

    // 筛选活跃且有入口路径的插件
    final activePlugins = plugins
        .where((p) => p.isActive && p.entryPath != null && p.entryPath!.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        // 我的歌单区域
        if (normalPlaylists.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '我的歌单',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.playlists),
                  child: const Text('查看全部'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PlaylistCarousel(
            playlists: normalPlaylists,
            onPlaylistTap: (playlist) {
              // 使用 push 保持导航栈，便于返回
              context.push('/playlists/${playlist.id}');
            },
          ),
          const SizedBox(height: 32),
        ],

        // 电台歌单区域
        if (radioPlaylists.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '我的电台',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          PlaylistCarousel(
            playlists: radioPlaylists,
            onPlaylistTap: (playlist) {
              // 使用 push 保持导航栈，便于返回
              context.push('/playlists/${playlist.id}');
            },
          ),
          const SizedBox(height: 32),
        ],

        // 插件入口区域
        if (activePlugins.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '插件入口',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.settings),
                  child: const Text('管理插件'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PluginGrid(plugins: activePlugins),
          const SizedBox(height: 32),
        ],

        // 统计信息
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    icon: Icons.queue_music,
                    label: '歌单',
                    value: normalPlaylists.length.toString(),
                    color: colorScheme.primary,
                  ),
                  _StatItem(
                    icon: Icons.radio,
                    label: '电台',
                    value: radioPlaylists.length.toString(),
                    color: colorScheme.secondary,
                  ),
                  _StatItem(
                    icon: Icons.library_music,
                    label: '总计',
                    value: playlists.length.toString(),
                    color: colorScheme.tertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // 空状态
        if (playlists.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.library_music_outlined,
                  size: 64,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无歌单',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.go(AppRoutes.playlists),
                  icon: const Icon(Icons.add),
                  label: const Text('创建歌单'),
                ),
              ],
            ),
          ),

        // 底部安全区域
        SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
      ],
    );
  }

  /// 获取问候语
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) {
      return '夜深了';
    } else if (hour < 12) {
      return '早上好';
    } else if (hour < 14) {
      return '中午好';
    } else if (hour < 18) {
      return '下午好';
    } else {
      return '晚上好';
    }
  }
}

/// 统计项组件
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 加载中内容
class _LoadingContent extends StatelessWidget {
  const _LoadingContent();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(64),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// 错误内容
class _ErrorContent extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorContent({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
