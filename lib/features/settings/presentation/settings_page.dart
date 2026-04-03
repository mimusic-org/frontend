import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/utils/responsive_snackbar.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import 'widgets/config_manager.dart';
import 'widgets/plugin_manager.dart';
import 'widgets/scan_manager.dart';
import 'widgets/theme_selector.dart';
import 'widgets/token_manager.dart';
import 'widgets/upgrade_dialog.dart';

/// 设置页面
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _apiUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 嵌入模式下 API 地址已由 main() 设定，无需加载存储的地址
    if (!AppConfig.isEmbedded) {
      _loadApiUrl();
    }
  }

  Future<void> _loadApiUrl() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      final url = prefs.getApiBaseUrl();
      if (url != null) {
        _apiUrlController.text = url;
      }
    } catch (e) {
      // 忽略
    }
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 分组1: 外观设置
          _buildSectionCard(
            title: '外观设置',
            icon: Icons.palette_outlined,
            children: [
              const ListTile(
                leading: Icon(Icons.brightness_6),
                title: Text('主题模式'),
                subtitle: Text('选择应用的主题外观'),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: ThemeSelector(),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 分组2: 音乐库管理
          _buildSectionCard(
            title: '音乐库管理',
            icon: Icons.library_music_outlined,
            children: [
              const Padding(padding: EdgeInsets.all(16), child: ScanManager()),
            ],
          ),

          const SizedBox(height: 16),

          // 分组3: 服务器配置（嵌入模式下隐藏，独立部署时显示）
          if (!AppConfig.isEmbedded)
            _buildSectionCard(
              title: '服务器配置',
              icon: Icons.dns_outlined,
              children: [
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('API 地址'),
                  subtitle: _buildApiUrlSubtitle(),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showApiUrlDialog,
                ),
              ],
            ),

          const SizedBox(height: 16),

          // 分组4: 令牌管理
          _buildSectionCard(
            title: '安全',
            icon: Icons.security_outlined,
            children: [const TokenManager()],
          ),

          const SizedBox(height: 16),

          // 分组5: 插件管理
          _buildSectionCard(
            title: '扩展',
            icon: Icons.extension_outlined,
            children: [
              const PluginManager(),
              const Divider(height: 1),
              const ConfigManager(),
            ],
          ),

          const SizedBox(height: 16),

          // 分组6: 系统
          _buildSectionCard(
            title: '系统',
            icon: Icons.settings_outlined,
            children: [
              ListTile(
                leading: const Icon(Icons.system_update),
                title: const Text('检查更新'),
                subtitle: const Text('检查是否有新版本'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => UpgradeDialog.show(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('关于'),
                subtitle: const Text('版本信息和许可证'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showAboutDialog,
              ),
            ],
          ),

          // 分组7: 账户
          _buildSectionCard(
            title: '账户',
            icon: Icons.account_circle_outlined,
            children: [
              ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  '退出登录',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showLogoutDialog,
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('确认退出'),
            content: const Text('确定要退出当前账户吗？'),
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
                child: const Text('确认退出'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
    }
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 内容
          ...children,
        ],
      ),
    );
  }

  Widget _buildApiUrlSubtitle() {
    final prefsAsync = ref.watch(appPreferencesProvider);
    return prefsAsync.when(
      data: (prefs) {
        final url = prefs.getApiBaseUrl();
        return Text(url ?? '使用默认地址');
      },
      loading: () => const Text('加载中...'),
      error: (_, _) => const Text('使用默认地址'),
    );
  }

  Future<void> _showApiUrlDialog() async {
    // 先加载当前值
    String oldUrl = '';
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      final currentUrl = prefs.getApiBaseUrl();
      oldUrl = currentUrl ?? '';
      _apiUrlController.text = oldUrl;
    } catch (e) {
      _apiUrlController.text = '';
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('API 地址'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('设置服务器 API 地址。'),
                const SizedBox(height: 16),
                TextField(
                  controller: _apiUrlController,
                  decoration: const InputDecoration(
                    labelText: 'API 地址',
                    hintText: 'http://example.com:8080',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () async {
                  final dialogContext = context;
                  try {
                    final prefs = await ref.read(appPreferencesProvider.future);
                    final urlBeforeReset = prefs.getApiBaseUrl() ?? '';
                    await prefs.clearApiBaseUrl();
                    _apiUrlController.clear();
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    if (!mounted) return;
                    if (urlBeforeReset.isNotEmpty) {
                      // 地址从有值变为空（重置），需要重新登录
                      AppConfig.baseUrl = '';
                      ref.invalidate(dioProvider);
                      await ref.read(authStateProvider.notifier).logout();
                      if (mounted) {
                        ResponsiveSnackBar.show(
                          this.context,
                          message: 'API 地址已重置，请重新登录',
                        );
                      }
                    } else {
                      if (mounted) {
                        ResponsiveSnackBar.show(
                          this.context,
                          message: '已重置为默认地址',
                        );
                      }
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                      ResponsiveSnackBar.showError(
                        dialogContext,
                        message: '重置失败: $e',
                      );
                    }
                  }
                },
                child: const Text('重置'),
              ),
              FilledButton(
                onPressed: () async {
                  final dialogContext = context;
                  final url = _apiUrlController.text.trim().replaceAll(
                    RegExp(r'/+$'),
                    '',
                  );
                  if (url.isNotEmpty && !Uri.tryParse(url)!.hasScheme) {
                    ResponsiveSnackBar.show(
                      dialogContext,
                      message: '请输入有效的 URL（包含 http:// 或 https://）',
                    );
                    return;
                  }

                  try {
                    final prefs = await ref.read(appPreferencesProvider.future);
                    if (url.isEmpty) {
                      await prefs.clearApiBaseUrl();
                    } else {
                      await prefs.setApiBaseUrl(url);
                    }
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    if (!mounted) return;
                    if (url != oldUrl) {
                      // 地址发生变化，更新运行时配置并退出登录
                      AppConfig.baseUrl = url;
                      ref.invalidate(dioProvider);
                      await ref.read(authStateProvider.notifier).logout();
                      if (mounted) {
                        ResponsiveSnackBar.show(
                          this.context,
                          message: 'API 地址已更新，请重新登录',
                        );
                      }
                    } else {
                      if (mounted) {
                        ResponsiveSnackBar.show(
                          this.context,
                          message: 'API 地址已更新',
                        );
                      }
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                      ResponsiveSnackBar.showError(
                        dialogContext,
                        message: '保存失败: $e',
                      );
                    }
                  }
                },
                child: const Text('保存'),
              ),
            ],
          ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showAboutDialog() async {
    String version = '1.0.0';
    String? gitCommit;

    try {
      final dio = ref.read(dioProvider);
      final response = await dio
          .get('${AppConfig.apiPrefix}/version')
          .timeout(const Duration(seconds: 3));
      final data = response.data as Map<String, dynamic>;
      final ver = data['version'] as String?;
      if (ver != null && ver.isNotEmpty) {
        version = ver;
      }
      final commit = data['git_commit'] as String?;
      if (commit != null && commit != 'unknown' && commit.isNotEmpty) {
        gitCommit = commit;
      }
    } catch (_) {
      // 忽略错误，使用默认版本号
    }

    if (!mounted) return;

    showAboutDialog(
      context: context,
      applicationName: 'MiMusic',
      applicationVersion: version,
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.music_note_rounded,
          size: 28,
          color: Colors.white,
        ),
      ),
      applicationLegalese: '© 2024-2026 MiMusic. All rights reserved.',
      children: [
        const SizedBox(height: 16),
        const Text('MiMusic 是一个开源的个人音乐服务器应用。'),
        const SizedBox(height: 8),
        const Text('支持本地音乐库管理、在线播放和插件扩展。'),
        if (gitCommit != null) ...[
          const SizedBox(height: 8),
          Text(
            'Git: $gitCommit',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _launchUrl('https://github.com/mimusic-org/mimusic'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.open_in_new,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'GitHub: mimusic-org/mimusic',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
