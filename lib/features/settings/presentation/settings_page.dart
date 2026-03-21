import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import 'providers/settings_provider.dart';
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
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 分组1: 外观设置
          _buildSectionCard(
            title: '外观设置',
            icon: Icons.palette_outlined,
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('主题模式'),
                subtitle: const Text('选择应用的主题外观'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: const ThemeSelector(),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 分组2: 音乐库管理
          _buildSectionCard(
            title: '音乐库管理',
            icon: Icons.library_music_outlined,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: const ScanManager(),
              ),
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
            children: [
              const TokenManager(),
            ],
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

          const SizedBox(height: 32),
        ],
      ),
    );
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
      error: (_, __) => const Text('使用默认地址'),
    );
  }

  Future<void> _showApiUrlDialog() async {
    // 先加载当前值
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      final currentUrl = prefs.getApiBaseUrl();
      _apiUrlController.text = currentUrl ?? '';
    } catch (e) {
      _apiUrlController.text = '';
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API 地址'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('设置服务器 API 地址，留空使用默认地址。'),
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
              try {
                final prefs = await ref.read(appPreferencesProvider.future);
                await prefs.clearApiBaseUrl();
                _apiUrlController.clear();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已重置为默认地址')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('重置失败: $e')),
                  );
                }
              }
            },
            child: const Text('重置'),
          ),
          FilledButton(
            onPressed: () async {
              final url = _apiUrlController.text.trim();
              if (url.isNotEmpty && !Uri.tryParse(url)!.hasScheme) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效的 URL（包含 http:// 或 https://）')),
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
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('API 地址已更新，重启应用后生效')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('保存失败: $e')),
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

  Future<void> _showAboutDialog() async {
    String version = '1.0.0';
    String? gitCommit;

    try {
      final check = await ref.read(upgradeCheckProvider.future);
      final current = check.currentVersion;
      if (current != null && current.isNotEmpty) {
        version = current;
        // 尝试从版本信息中提取 git commit（如果格式为 v1.0.0-abc1234）
        final parts = current.split('-');
        if (parts.length > 1) {
          version = parts[0];
          gitCommit = parts.sublist(1).join('-');
        }
      }
    } catch (_) {
      // 忽略错误，使用默认版本号
    }

    if (!mounted) return;

    showAboutDialog(
      context: context,
      applicationName: 'MiMusic',
      applicationVersion: version,
      applicationIcon: const FlutterLogo(size: 48),
      applicationLegalese: '© 2024 MiMusic. All rights reserved.',
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
      ],
    );
  }
}
