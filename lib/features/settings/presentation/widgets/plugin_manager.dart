import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/responsive.dart';
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
          child:
              context.isMobile
                  ? Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _showUploadDialog,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('上传插件'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openPluginDownloadPage,
                        icon: const Icon(Icons.download),
                        label: const Text('获取插件'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => ref.invalidate(pluginsProvider),
                        tooltip: '刷新',
                      ),
                    ],
                  )
                  : Row(
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

  Future<void> _openHomepage(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ResponsiveSnackBar.show(context, message: '无法打开链接: $url');
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

  void _showUpdateDialog() {
    showDialog(
      context: context,
      builder:
          (context) => _PluginUpdateDialog(
            plugin: widget.plugin,
            pluginApi: ref.read(pluginApiProvider),
            onUpdateComplete: () {
              ref.invalidate(pluginsProvider);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plugin = widget.plugin;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = context.isMobile;

    // 状态颜色
    Color statusColor;
    if (plugin.isError) {
      statusColor = colorScheme.error;
    } else if (plugin.isActive) {
      statusColor = Colors.green;
    } else {
      statusColor = colorScheme.outline;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第 1 行 —— 标题行：头像 + 插件名 + 操作区
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: statusColor.withValues(alpha: 0.2),
                child: Icon(Icons.extension, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  plugin.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ..._buildTrailingActions(isMobile),
            ],
          ),
          // 第 2 行 —— 元信息行：状态胶囊 + 版本号 + 作者（Wrap 自适应换行）
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildStatusChip(plugin, colorScheme),
                if (plugin.version != null)
                  _buildVersionBadge(plugin.version!, theme),
                if (plugin.author != null)
                  Text(
                    '作者: ${plugin.author}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          // 第 3 行 —— 描述（如果存在）
          if (plugin.description != null)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 6),
              child: Text(
                plugin.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          // 第 4 行 —— 主页链接（仅桌面端；移动端已在菜单中提供）
          if (!isMobile &&
              plugin.homepage != null &&
              plugin.homepage!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 4),
              child: GestureDetector(
                onTap: () => _openHomepage(plugin.homepage!),
                child: Text(
                  plugin.homepage!,
                  style: TextStyle(
                    color: colorScheme.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: colorScheme.primary,
                    fontSize: theme.textTheme.bodySmall?.fontSize,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 状态胶囊：小圆点 + 文字，颜色与 statusColor 保持一致
  Widget _buildStatusChip(Plugin plugin, ColorScheme colorScheme) {
    final String label;
    final Color color;
    if (plugin.isError) {
      label = '错误';
      color = colorScheme.error;
    } else if (plugin.isActive) {
      label = '已启用';
      color = Colors.green;
    } else {
      label = '已禁用';
      color = colorScheme.outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 版本号徽章：保留原灰色圆角样式
  Widget _buildVersionBadge(String version, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('v$version', style: theme.textTheme.labelSmall),
    );
  }

  /// 标题行右侧的操作区：
  ///  - 移动端：[Switch, PopupMenuButton(主页/更新/重置/删除)]
  ///  - 桌面端：[Switch, 更新, 重置, 删除]
  List<Widget> _buildTrailingActions(bool isMobile) {
    final plugin = widget.plugin;
    final colorScheme = Theme.of(context).colorScheme;

    final Widget switchOrLoader =
        _isToggling
            ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
            : Switch(
              value: plugin.isActive,
              onChanged: plugin.isError ? null : (_) => _togglePlugin(),
            );

    if (isMobile) {
      return [
        switchOrLoader,
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: '更多操作',
          onSelected: (value) {
            switch (value) {
              case 'homepage':
                _openHomepage(plugin.homepage!);
              case 'update':
                _showUpdateDialog();
              case 'reset':
                _resetPlugin();
              case 'delete':
                _deletePlugin();
            }
          },
          itemBuilder:
              (context) => [
                if (plugin.homepage != null && plugin.homepage!.isNotEmpty) ...[
                  const PopupMenuItem<String>(
                    value: 'homepage',
                    child: ListTile(
                      leading: Icon(Icons.open_in_new),
                      title: Text('打开主页'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                ],
                const PopupMenuItem<String>(
                  value: 'update',
                  child: ListTile(
                    leading: Icon(Icons.system_update_alt),
                    title: Text('检查更新'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'reset',
                  enabled: !_isResetting,
                  child: ListTile(
                    leading:
                        _isResetting
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.restart_alt),
                    title: const Text('重置'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  enabled: !_isDeleting,
                  child: ListTile(
                    leading:
                        _isDeleting
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : Icon(
                              Icons.delete_outline,
                              color: colorScheme.error,
                            ),
                    title: Text(
                      '删除',
                      style: TextStyle(color: colorScheme.error),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
        ),
      ];
    }

    // 桌面端
    return [
      switchOrLoader,
      IconButton(
        icon: const Icon(Icons.system_update_alt),
        onPressed: _showUpdateDialog,
        tooltip: '检查更新',
      ),
      IconButton(
        icon:
            _isResetting
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Icon(Icons.restart_alt),
        onPressed: _isResetting ? null : _resetPlugin,
        tooltip: '重置',
      ),
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
    ];
  }
}

/// 插件更新对话框
class _PluginUpdateDialog extends StatefulWidget {
  final Plugin plugin;
  final PluginApi pluginApi;
  final VoidCallback onUpdateComplete;

  const _PluginUpdateDialog({
    required this.plugin,
    required this.pluginApi,
    required this.onUpdateComplete,
  });

  @override
  State<_PluginUpdateDialog> createState() => _PluginUpdateDialogState();
}

class _PluginUpdateDialogState extends State<_PluginUpdateDialog> {
  /// 预设的 GitHub 代理列表
  static const List<_ProxyOption> _presetProxies = [
    _ProxyOption(label: '直连 (不使用代理)', value: ''),
    _ProxyOption(label: 'ghproxy.com', value: 'https://ghproxy.com/'),
    _ProxyOption(label: 'ghfast.top', value: 'https://ghfast.top/'),
    _ProxyOption(label: 'gh.con.sh', value: 'https://gh.con.sh/'),
    _ProxyOption(
      label: 'mirror.ghproxy.com',
      value: 'https://mirror.ghproxy.com/',
    ),
  ];

  bool _isChecking = false;
  bool _isUpdating = false;
  String? _error;
  PluginUpdateCheck? _checkResult;

  /// 当前选中的代理索引，-1 表示自定义
  int _selectedProxyIndex = 0;
  final TextEditingController _customProxyController = TextEditingController();

  /// 获取当前生效的代理地址
  String get _effectiveProxy {
    if (_selectedProxyIndex == -1) {
      return _customProxyController.text.trim();
    }
    if (_selectedProxyIndex >= 0 &&
        _selectedProxyIndex < _presetProxies.length) {
      return _presetProxies[_selectedProxyIndex].value;
    }
    return '';
  }

  @override
  void dispose() {
    _customProxyController.dispose();
    super.dispose();
  }

  Future<void> _checkUpdate() async {
    final proxy = _effectiveProxy;
    setState(() {
      _isChecking = true;
      _error = null;
      _checkResult = null;
    });

    try {
      final result = await widget.pluginApi
          .checkPluginUpdate(
            widget.plugin.id,
            githubProxy: proxy.isNotEmpty ? proxy : null,
          )
          .timeout(const Duration(seconds: 20));
      if (mounted) setState(() => _checkResult = result);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on TimeoutException {
      if (mounted) setState(() => _error = '检查更新超时，请尝试切换代理后重试');
    } catch (e) {
      if (mounted) setState(() => _error = '检查更新失败: $e');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _executeUpdate() async {
    final proxy = _effectiveProxy;
    setState(() {
      _isUpdating = true;
      _error = null;
    });

    try {
      await widget.pluginApi
          .updatePlugin(
            widget.plugin.id,
            githubProxy: proxy.isNotEmpty ? proxy : null,
          )
          .timeout(const Duration(seconds: 120));
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdateComplete();
        ResponsiveSnackBar.showSuccess(context, message: '插件更新成功');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = '更新失败: ${e.message}');
    } on TimeoutException {
      if (mounted) setState(() => _error = '更新超时，请重试');
    } catch (e) {
      if (mounted) setState(() => _error = '更新失败: $e');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update_alt),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '更新插件 - ${widget.plugin.displayName}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.responsiveDialogMaxWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 错误信息
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),

              // GitHub 代理选择
              if (!_isUpdating) _buildProxySelector(theme),

              // 正在检查
              if (_isChecking)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('正在检查更新...'),
                    ],
                  ),
                )
              // 正在更新
              else if (_isUpdating)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('正在下载并更新插件...'),
                      SizedBox(height: 8),
                      Text('请勿关闭此对话框', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              // 显示检查结果
              else if (_checkResult != null)
                _buildCheckResult(_checkResult!),
            ],
          ),
        ),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildProxySelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GitHub 代理', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          // 预设代理选项
          ...List.generate(_presetProxies.length, (index) {
            final proxy = _presetProxies[index];
            return RadioListTile<int>(
              title: Text(proxy.label, style: theme.textTheme.bodyMedium),
              value: index,
              groupValue: _selectedProxyIndex,
              dense: true,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onChanged: (value) {
                setState(() => _selectedProxyIndex = value!);
              },
            );
          }),
          // 自定义代理选项
          RadioListTile<int>(
            title: Text('自定义代理', style: theme.textTheme.bodyMedium),
            value: -1,
            groupValue: _selectedProxyIndex,
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            onChanged: (value) {
              setState(() => _selectedProxyIndex = value!);
            },
          ),
          // 自定义代理输入框
          if (_selectedProxyIndex == -1)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: TextField(
                controller: _customProxyController,
                decoration: const InputDecoration(
                  hintText: 'https://your-proxy.com/',
                  helperText: '输入代理地址，如 https://ghproxy.com/',
                  helperMaxLines: 2,
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
          const Divider(height: 24),
        ],
      ),
    );
  }

  Widget _buildCheckResult(PluginUpdateCheck check) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!check.hasUpdate) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            const Text('已是最新版本'),
            const SizedBox(height: 8),
            Text(
              '当前版本: ${check.currentVersion}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.new_releases, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(child: Text('发现新版本')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'v${check.currentVersion}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward,
                size: 16,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                'v${check.remoteVersion}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    // 正在更新时不显示按钮
    if (_isUpdating) {
      return [];
    }

    // 正在检查
    if (_isChecking) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: const Text('取消'),
        ),
      ];
    }

    // 有检查结果且有更新
    if (_checkResult != null && _checkResult!.hasUpdate) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: const Text('取消'),
        ),
        OutlinedButton(
          onPressed: _checkUpdate,
          style: OutlinedButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: const Text('重新检查'),
        ),
        FilledButton(
          onPressed: _executeUpdate,
          style: FilledButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: const Text('立即更新'),
        ),
      ];
    }

    // 有检查结果但无更新，或有错误
    if (_checkResult != null || _error != null) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: const Text('关闭'),
        ),
        FilledButton(
          onPressed: _checkUpdate,
          style: FilledButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: const Text('重新检查'),
        ),
      ];
    }

    // 初始状态
    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(
          minimumSize: context.responsiveButtonMinSize,
        ),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _checkUpdate,
        style: FilledButton.styleFrom(
          minimumSize: context.responsiveButtonMinSize,
        ),
        child: const Text('检查更新'),
      ),
    ];
  }
}

/// GitHub 代理选项
class _ProxyOption {
  final String label;
  final String value;

  const _ProxyOption({required this.label, required this.value});
}
