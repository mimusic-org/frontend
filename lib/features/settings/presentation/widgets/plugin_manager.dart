import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../data/plugin_api.dart';
import '../providers/settings_provider.dart';

/// 插件管理组件
class PluginManager extends ConsumerStatefulWidget {
  const PluginManager({super.key});

  @override
  ConsumerState<PluginManager> createState() => _PluginManagerState();
}

class _PluginManagerState extends ConsumerState<PluginManager> {
  @override
  Widget build(BuildContext context) {
    final pluginsAsync = ref.watch(pluginsProvider);

    return ExpansionTile(
      leading: const Icon(Icons.extension),
      title: const Text('插件管理'),
      subtitle: const Text('管理已安装的插件'),
      children: [
        // 上传按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _showUploadHint,
                icon: const Icon(Icons.upload_file),
                label: const Text('上传插件'),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(pluginsProvider),
                tooltip: '刷新',
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 插件列表
        pluginsAsync.when(
          data: (plugins) => _buildPluginList(plugins),
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  error is ApiException ? error.message : '加载失败',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(pluginsProvider),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showUploadHint() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('上传插件'),
        content: const Text(
          '由于移动端限制，请通过浏览器访问服务器的 Web 界面来上传插件。\n\n'
          '支持的格式: .wasm, .zip',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildPluginList(List<Plugin> plugins) {
    if (plugins.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.extension_off, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('暂无已安装的插件'),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: plugins.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final plugin = plugins[index];
        return _PluginItem(plugin: plugin);
      },
    );
  }
}

class _PluginItem extends ConsumerStatefulWidget {
  final Plugin plugin;

  const _PluginItem({required this.plugin});

  @override
  ConsumerState<_PluginItem> createState() => _PluginItemState();
}

class _PluginItemState extends ConsumerState<_PluginItem> {
  bool _isToggling = false;
  bool _isDeleting = false;

  Future<void> _togglePlugin() async {
    setState(() => _isToggling = true);

    try {
      final pluginApi = ref.read(pluginApiProvider);
      if (widget.plugin.isActive) {
        await pluginApi.disablePlugin(widget.plugin.id);
      } else {
        await pluginApi.enablePlugin(widget.plugin.id);
      }
      ref.invalidate(pluginsProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isToggling = false);
      }
    }
  }

  Future<void> _deletePlugin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除插件 "${widget.plugin.displayName}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      final pluginApi = ref.read(pluginApiProvider);
      await pluginApi.deletePlugin(widget.plugin.id);
      ref.invalidate(pluginsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('插件已删除')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plugin = widget.plugin;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 状态颜色
    Color statusColor;
    if (plugin.isError) {
      statusColor = colorScheme.error;
    } else if (plugin.isActive) {
      statusColor = Colors.green;
    } else {
      statusColor = colorScheme.outline;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.2),
        child: Icon(
          Icons.extension,
          color: statusColor,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(plugin.displayName),
          ),
          if (plugin.version != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'v${plugin.version}',
                style: theme.textTheme.labelSmall,
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plugin.author != null)
            Text('作者: ${plugin.author}'),
          if (plugin.description != null)
            Text(
              plugin.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 启用/禁用开关
          if (_isToggling)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: plugin.isActive,
              onChanged: plugin.isError ? null : (_) => _togglePlugin(),
            ),
          // 删除按钮
          IconButton(
            icon: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            onPressed: _isDeleting ? null : _deletePlugin,
            tooltip: '删除',
          ),
        ],
      ),
      isThreeLine: plugin.description != null,
    );
  }
}
