import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/app_config.dart';
import '../../../../core/theme/responsive.dart';
import '../../../settings/data/plugin_api.dart';

/// 插件入口网格组件
class PluginGrid extends StatelessWidget {
  final List<Plugin> plugins;

  const PluginGrid({
    super.key,
    required this.plugins,
  });

  /// 获取活跃且有入口路径的插件
  List<Plugin> get _activePlugins {
    return plugins
        .where((p) => p.isActive && p.entryPath != null && p.entryPath!.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final activePlugins = _activePlugins;
    if (activePlugins.isEmpty) {
      return const SizedBox.shrink();
    }

    // 根据屏幕尺寸确定列数
    final crossAxisCount = context.responsive<int>(
      mobile: 2,
      tablet: 3,
      desktop: 4,
    );

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
        childAspectRatio: 2.2, // 宽高比，卡片较宽
      ),
      itemCount: activePlugins.length,
      itemBuilder: (context, index) {
        final plugin = activePlugins[index];
        return _PluginCard(plugin: plugin);
      },
    );
  }
}

/// 插件卡片组件
class _PluginCard extends StatelessWidget {
  final Plugin plugin;

  const _PluginCard({required this.plugin});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openPluginEntry(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 左侧图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.extension,
                  color: colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // 中间信息
              Expanded(
                child: Column(
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
                    if (plugin.description != null &&
                        plugin.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        plugin.description!,
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
              // 右侧箭头
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 打开插件入口
  Future<void> _openPluginEntry(BuildContext context) async {
    if (plugin.entryPath == null || plugin.entryPath!.isEmpty) {
      return;
    }

    // 构建完整 URL: baseUrl + /api/v1/plugin + entryPath
    final url = Uri.parse('${AppConfig.baseUrl}${AppConfig.apiPrefix}/plugin${plugin.entryPath}');

    try {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法打开插件: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
