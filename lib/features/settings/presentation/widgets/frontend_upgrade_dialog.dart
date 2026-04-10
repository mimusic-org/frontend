import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/app_config.dart';
import '../../../../core/theme/responsive.dart';
import '../../data/frontend_version_api.dart';

/// 前端（客户端）更新对话框
class FrontendUpgradeDialog extends StatelessWidget {
  final FrontendVersionCheck versionCheck;

  const FrontendUpgradeDialog({super.key, required this.versionCheck});

  /// 显示前端更新对话框
  static Future<void> show(
    BuildContext context, {
    required FrontendVersionCheck versionCheck,
  }) {
    return showDialog(
      context: context,
      builder: (context) => FrontendUpgradeDialog(versionCheck: versionCheck),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.phone_android),
          SizedBox(width: 8),
          Text('客户端更新'),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.responsiveDialogMaxWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 版本信息
              Text(
                '当前版本: ${AppConfig.frontendVersionDisplay}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),

              // 新版本信息
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.new_releases, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '最新版本: v${versionCheck.latestVersion}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 发布时间
              if (versionCheck.publishedAt != null) ...[
                const SizedBox(height: 12),
                Text(
                  '发布时间: ${_formatDate(versionCheck.publishedAt!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],

              // 更新说明
              if (versionCheck.releaseNotes != null &&
                  versionCheck.releaseNotes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('更新说明:', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      child: MarkdownBody(
                        data: versionCheck.releaseNotes!,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                          p: theme.textTheme.bodySmall,
                          listBullet: theme.textTheme.bodySmall,
                          blockSpacing: 8,
                        ),
                        onTapLink: (text, href, title) {
                          if (href != null) {
                            launchUrl(Uri.parse(href),
                                mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          child: const Text('稍后'),
        ),
        FilledButton.icon(
          onPressed: () => _launchReleaseUrl(context),
          style: FilledButton.styleFrom(
            minimumSize: context.responsiveButtonMinSize,
          ),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('前往下载'),
        ),
      ],
    );
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 打开发布页面
  Future<void> _launchReleaseUrl(BuildContext context) async {
    final url = Uri.parse(
      versionCheck.releaseUrl.isNotEmpty
          ? versionCheck.releaseUrl
          : AppConfig.frontendReleasesUrl,
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
