import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
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
                onPressed: _showUploadDialog,
                icon: const Icon(Icons.upload_file),
                label: const Text('上传插件'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _openPluginDownloadPage,
                icon: const Icon(Icons.download),
                label: const Text('获取插件'),
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
          loading:
              () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
          error:
              (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      error is ApiException ? error.message : '加载失败',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
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

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder:
          (context) => _PluginUploadDialog(
            onUploadComplete: () {
              ref.invalidate(pluginsProvider);
            },
            pluginApi: ref.read(pluginApiProvider),
          ),
    );
  }

  static const _pluginDownloadUrl = 'https://mimusic.hanxi.cc/issues/4.html';

  Future<void> _openPluginDownloadPage() async {
    final uri = Uri.parse(_pluginDownloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ResponsiveSnackBar.show(context, message: '无法打开链接: $_pluginDownloadUrl');
    }
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
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final plugin = plugins[index];
        return _PluginItem(plugin: plugin);
      },
    );
  }
}

/// 插件上传对话框
class _PluginUploadDialog extends StatefulWidget {
  final VoidCallback onUploadComplete;
  final PluginApi pluginApi;

  const _PluginUploadDialog({
    required this.onUploadComplete,
    required this.pluginApi,
  });

  @override
  State<_PluginUploadDialog> createState() => _PluginUploadDialogState();
}

class _PluginUploadDialogState extends State<_PluginUploadDialog> {
  PlatformFile? _selectedFile;
  bool _uploading = false;

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 选择文件
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wasm', 'zip'],
        withData: kIsWeb, // Web 平台需要读取字节数据
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '选择文件失败: $e');
      }
    }
  }

  /// 上传文件
  Future<void> _uploadFile() async {
    final file = _selectedFile;
    if (file == null) return;

    setState(() => _uploading = true);

    try {
      PluginUploadResponse response;

      if (kIsWeb) {
        // Web 平台：使用字节数据上传
        final bytes = file.bytes;
        if (bytes == null) {
          throw ApiException(message: '无法读取文件数据');
        }
        response = await widget.pluginApi.uploadPluginBytes(bytes, file.name);
      } else {
        // 原生平台：使用文件路径上传
        final path = file.path;
        if (path == null) {
          throw ApiException(message: '无法获取文件路径');
        }
        response = await widget.pluginApi.uploadPlugin(path, file.name);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onUploadComplete();

        // 显示上传结果
        if (response.success > 0 && response.failed == 0) {
          ResponsiveSnackBar.showSuccess(
            context,
            message:
                response.message.isNotEmpty
                    ? response.message
                    : '上传成功：${response.success} 个插件',
          );
        } else if (response.failed > 0) {
          final failedResults =
              response.results.where((r) => !r.success).toList();
          final errorMsg = failedResults
              .map((r) => '${r.fileName}: ${r.error}')
              .join('\n');
          ResponsiveSnackBar.show(
            context,
            message:
                '成功 ${response.success} 个，失败 ${response.failed} 个\n$errorMsg',
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '上传失败: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '上传失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('上传插件'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 文件选择区域
            InkWell(
              onTap: _uploading ? null : _pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        _selectedFile != null
                            ? colorScheme.primary
                            : colorScheme.outline,
                    width: _selectedFile != null ? 2 : 1,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color:
                      _selectedFile != null
                          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                          : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 48,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text('点击选择文件', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      '支持 .wasm 或 .zip 格式（ZIP 可批量导入多个插件）',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // 已选文件信息
            if (_selectedFile != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFile!.name,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatFileSize(_selectedFile!.size),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed:
                          _uploading
                              ? null
                              : () => setState(() => _selectedFile = null),
                      tooltip: '移除',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _uploading ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _selectedFile != null && !_uploading ? _uploadFile : null,
          icon:
              _uploading
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Icon(Icons.upload),
          label: Text(_uploading ? '上传中...' : '上传'),
        ),
      ],
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
  bool _isResetting = false;

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
        ResponsiveSnackBar.showError(context, message: '操作失败: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '操作失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isToggling = false);
      }
    }
  }

  Future<void> _resetPlugin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('确认重置'),
            content: Text(
              '确定要重置插件 "${widget.plugin.displayName}" 吗？\n\n这将清空插件的所有数据并重新启动。',
            ),
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
                child: const Text('重置'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isResetting = true);

    try {
      final pluginApi = ref.read(pluginApiProvider);
      await pluginApi.resetPlugin(widget.plugin.id);
      ref.invalidate(pluginsProvider);
      if (mounted) {
        ResponsiveSnackBar.show(context, message: '插件已重置');
      }
    } on ApiException catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '重置失败: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '重置失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    }
  }

  Future<void> _deletePlugin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
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
        ResponsiveSnackBar.show(context, message: '插件已删除');
      }
    } on ApiException catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '删除失败: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '删除失败: $e');
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
        child: Icon(Icons.extension, color: statusColor, size: 20),
      ),
      title: Row(
        children: [
          Expanded(child: Text(plugin.displayName)),
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
          if (plugin.author != null) Text('作者: ${plugin.author}'),
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
          // 重置按钮
          IconButton(
            icon:
                _isResetting
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.refresh),
            onPressed: _isResetting ? null : _resetPlugin,
            tooltip: '重置',
          ),
          // 删除按钮
          IconButton(
            icon:
                _isDeleting
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
