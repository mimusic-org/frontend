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
import '../../data/jsplugin_api.dart';
import '../providers/jsplugin_provider.dart';

/// JS 插件管理组件
class JSPluginManager extends ConsumerStatefulWidget {
  const JSPluginManager({super.key});

  @override
  ConsumerState<JSPluginManager> createState() => _JSPluginManagerState();
}

class _JSPluginManagerState extends ConsumerState<JSPluginManager> {
  @override
  Widget build(BuildContext context) {
    final pluginsAsync = ref.watch(jsPluginsProvider);

    return ExpansionTile(
      leading: const Icon(Icons.javascript),
      title: const Text('JS 插件管理'),
      subtitle: const Text('管理已安装的 JS 插件'),
      children: [
        // 顶部操作栏
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
                        onPressed: () => ref.invalidate(jsPluginsProvider),
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
                        onPressed: () => ref.invalidate(jsPluginsProvider),
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
                      onPressed: () => ref.invalidate(jsPluginsProvider),
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
          (context) => _JSPluginUploadDialog(
            onUploadComplete: () {
              ref.invalidate(jsPluginsProvider);
            },
            pluginApi: ref.read(jsPluginApiProvider),
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

  Widget _buildPluginList(List<JSPlugin> plugins) {
    if (plugins.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.extension_off, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('暂无已安装的 JS 插件'),
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
        return _JSPluginItem(plugin: plugin);
      },
    );
  }
}

/// JS 插件上传对话框
class _JSPluginUploadDialog extends StatefulWidget {
  final VoidCallback onUploadComplete;
  final JSPluginApi pluginApi;

  const _JSPluginUploadDialog({
    required this.onUploadComplete,
    required this.pluginApi,
  });

  @override
  State<_JSPluginUploadDialog> createState() => _JSPluginUploadDialogState();
}

class _JSPluginUploadDialogState extends State<_JSPluginUploadDialog> {
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
        allowedExtensions: ['zip'],
        withData: kIsWeb,
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
      JSPluginUploadResponse response;

      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) {
          throw ApiException(message: '无法读取文件数据');
        }
        response = await widget.pluginApi.uploadPluginBytes(bytes, file.name);
      } else {
        final path = file.path;
        if (path == null) {
          throw ApiException(message: '无法获取文件路径');
        }
        response = await widget.pluginApi.uploadPlugin(path, file.name);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onUploadComplete();

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
      title: const Text('上传 JS 插件'),
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
                      '支持 .zip 格式（ZIP 可批量导入多个插件）',
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

/// JS 插件列表项
class _JSPluginItem extends ConsumerStatefulWidget {
  final JSPlugin plugin;

  const _JSPluginItem({required this.plugin});

  @override
  ConsumerState<_JSPluginItem> createState() => _JSPluginItemState();
}

class _JSPluginItemState extends ConsumerState<_JSPluginItem> {
  bool _isToggling = false;
  bool _isDeleting = false;
  bool _isCheckingUpdate = false;

  Future<void> _togglePlugin() async {
    setState(() => _isToggling = true);

    try {
      final api = ref.read(jsPluginApiProvider);
      if (widget.plugin.isActive) {
        await api.disablePlugin(widget.plugin.id);
      } else {
        await api.enablePlugin(widget.plugin.id);
      }
      ref.invalidate(jsPluginsProvider);
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

  Future<void> _openHomepage(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ResponsiveSnackBar.show(context, message: '无法打开链接: $url');
    }
  }

  Future<void> _checkUpdate() async {
    setState(() => _isCheckingUpdate = true);

    try {
      final api = ref.read(jsPluginApiProvider);
      final result = await api.checkUpdate(widget.plugin.id)
          .timeout(const Duration(seconds: 20));
      if (mounted) {
        if (result.hasUpdate) {
          ResponsiveSnackBar.showSuccess(
            context,
            message:
                '发现新版本: v${result.currentVersion} → v${result.remoteVersion}',
          );
        } else {
          ResponsiveSnackBar.show(context, message: '已是最新版本');
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context,
          message: '检查更新失败: ${e.message}',
        );
      }
    } on TimeoutException {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '检查更新超时，请稍后重试');
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '检查更新失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
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
      final api = ref.read(jsPluginApiProvider);
      await api.deletePlugin(widget.plugin.id);
      ref.invalidate(jsPluginsProvider);
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
    final isMobile = context.isMobile;

    // 状态颜色
    Color statusColor;
    if (plugin.isError) {
      statusColor = Colors.red;
    } else if (plugin.isActive) {
      statusColor = Colors.green;
    } else {
      statusColor = Colors.grey;
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
          // 第 2 行 —— 元信息行：状态胶囊 + 版本号 + 作者
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
          // 第 4 行 —— 主页链接（仅桌面端）
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

  /// 状态胶囊
  Widget _buildStatusChip(JSPlugin plugin, ColorScheme colorScheme) {
    final String label;
    final Color color;
    if (plugin.isError) {
      label = '错误';
      color = Colors.red;
    } else if (plugin.isActive) {
      label = '已启用';
      color = Colors.green;
    } else {
      label = '已禁用';
      color = Colors.grey;
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

  /// 版本号徽章
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

  /// 标题行右侧的操作区
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
                _checkUpdate();
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
                PopupMenuItem<String>(
                  value: 'update',
                  enabled: !_isCheckingUpdate,
                  child: ListTile(
                    leading:
                        _isCheckingUpdate
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.system_update_alt),
                    title: const Text('检查更新'),
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
        icon:
            _isCheckingUpdate
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Icon(Icons.system_update_alt),
        onPressed: _isCheckingUpdate ? null : _checkUpdate,
        tooltip: '检查更新',
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
