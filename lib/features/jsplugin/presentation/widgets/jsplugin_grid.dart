import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/app_config.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/responsive.dart';
import '../../data/jsplugin_api.dart';
import '../providers/jsplugin_provider.dart';

/// JS 插件入口网格组件
class JSPluginGrid extends ConsumerWidget {
  const JSPluginGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pluginsAsync = ref.watch(jsPluginsProvider);

    return pluginsAsync.when(
      data: (plugins) {
        final activePlugins = plugins
            .where(
              (p) =>
                  p.isActive &&
                  p.entryPath != null &&
                  p.entryPath!.isNotEmpty,
            )
            .toList();

        if (activePlugins.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'JS 插件',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final containerWidth = constraints.maxWidth - 32;
                final crossAxisCount = context.isMobile ||
                        containerWidth < ResponsiveBreakpoints.tablet
                    ? (containerWidth / 180).floor().clamp(1, 2)
                    : context.responsive<int>(
                        mobile: 2, tablet: 3, desktop: 4);

                final spacing = context.responsive<double>(
                  mobile: 12,
                  tablet: 16,
                  desktop: 16,
                );

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: activePlugins.length,
                  itemBuilder: (context, index) {
                    final plugin = activePlugins[index];
                    return _JSPluginCard(plugin: plugin);
                  },
                );
              },
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// JS 插件卡片组件
class _JSPluginCard extends StatelessWidget {
  final JSPlugin plugin;

  const _JSPluginCard({required this.plugin});

  /// 根据插件名称生成颜色
  Color _generateColor() {
    final hash = plugin.displayName.hashCode;
    final hue = (hash % 360).abs().toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.5).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = _generateColor();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openPlugin(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 左侧彩色圆形图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.javascript,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // 中间信息
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plugin.displayName,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (plugin.version != null &&
                        plugin.version!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'v${plugin.version}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 打开插件入口
  void _openPlugin(BuildContext context) {
    if (plugin.entryPath == null || plugin.entryPath!.isEmpty) {
      return;
    }

    final url =
        '${AppConfig.baseUrl}/api/v1/jsplugin/${plugin.entryPath}';

    if (kIsWeb) {
      // Web 平台：使用 launchUrl 在新标签页打开
      final token = SecureStorageService.cachedAccessToken ?? '';
      final separator = url.contains('?') ? '&' : '?';
      final webUrl = token.isNotEmpty
          ? Uri.parse('$url${separator}access_token=$token')
          : Uri.parse(url);
      launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } else {
      // 原生平台：应用内 WebView
      context.push(
        Uri(
          path: AppRoutes.plugin,
          queryParameters: {'url': url, 'name': plugin.displayName},
        ).toString(),
      );
    }
  }
}
