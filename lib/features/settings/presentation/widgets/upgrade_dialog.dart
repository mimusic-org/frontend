import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../data/upgrade_api.dart';
import '../providers/settings_provider.dart';

/// 升级对话框
class UpgradeDialog extends ConsumerStatefulWidget {
  const UpgradeDialog({super.key});

  /// 显示升级对话框
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const UpgradeDialog(),
    );
  }

  @override
  ConsumerState<UpgradeDialog> createState() => _UpgradeDialogState();
}

class _UpgradeDialogState extends ConsumerState<UpgradeDialog> {
  bool _isChecking = true;
  bool _isStarting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 使用 addPostFrameCallback 延迟调用，避免在 initState 中访问 inherited widget
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkUpgrade();
    });
  }

  Future<void> _checkUpgrade() async {
    setState(() {
      _isChecking = true;
      _error = null;
    });

    try {
      // 刷新检查更新
      ref.invalidate(upgradeCheckProvider);
      await ref.read(upgradeCheckProvider.future);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '检查更新失败: $e');
    } finally {
      setState(() => _isChecking = false);
    }
  }

  Future<void> _startUpgrade() async {
    setState(() {
      _isStarting = true;
      _error = null;
    });

    try {
      await ref.read(upgradeProgressProvider.notifier).startUpgrade();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '启动升级失败: $e');
    } finally {
      setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final upgradeCheckAsync = ref.watch(upgradeCheckProvider);
    final upgradeProgress = ref.watch(upgradeProgressProvider);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update),
          const SizedBox(width: 8),
          const Text('检查更新'),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 300,
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
                    Icon(Icons.error_outline, color: colorScheme.error, size: 20),
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
            // 正在升级
            else if (upgradeProgress.isUpgrading)
              _buildUpgradeProgress(upgradeProgress)
            // 升级完成
            else if (upgradeProgress.isCompleted)
              _buildUpgradeCompleted()
            // 升级出错
            else if (upgradeProgress.isError)
              _buildUpgradeError(upgradeProgress)
            // 显示检查结果
            else
              upgradeCheckAsync.when(
                data: (check) => _buildCheckResult(check),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(
                  e is ApiException ? e.message : '检查失败',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: _buildActions(upgradeCheckAsync, upgradeProgress),
    );
  }

  Widget _buildCheckResult(UpgradeCheck check) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!check.hasUpdate) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            const Text('已是最新版本'),
            const SizedBox(height: 8),
            Text(
              '当前版本: ${check.currentVersion ?? '未知'}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 版本信息
        Container(
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
                  const Text('发现新版本'),
                ],
              ),
              const SizedBox(height: 8),
              Text('当前版本: ${check.currentVersion ?? '未知'}'),
              Text('最新版本: ${check.latestVersion ?? '未知'}'),
            ],
          ),
        ),

        // 发布说明
        if (check.releaseNotes != null) ...[
          const SizedBox(height: 16),
          Text('更新说明:', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 150),
            child: SingleChildScrollView(
              child: Text(
                check.releaseNotes!,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUpgradeProgress(UpgradeProgress progress) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress.progress / 100,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 16),
        Text(progress.statusText),
        if (progress.message != null) ...[
          const SizedBox(height: 8),
          Text(
            progress.message!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildUpgradeCompleted() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 16),
          const Text('升级完成'),
          const SizedBox(height: 8),
          Text(
            '应用即将重启',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeError(UpgradeProgress progress) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(Icons.error, color: colorScheme.error, size: 48),
        const SizedBox(height: 16),
        const Text('升级失败'),
        if (progress.message != null) ...[
          const SizedBox(height: 8),
          Text(
            progress.message!,
            style: TextStyle(color: colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  List<Widget> _buildActions(AsyncValue<UpgradeCheck> upgradeCheckAsync, UpgradeProgress upgradeProgress) {
    // 正在升级时不显示按钮
    if (upgradeProgress.isUpgrading) {
      return [];
    }

    // 升级完成
    if (upgradeProgress.isCompleted) {
      return [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ];
    }

    // 升级出错
    if (upgradeProgress.isError) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        FilledButton(
          onPressed: () {
            ref.read(upgradeProgressProvider.notifier).reset();
            _checkUpgrade();
          },
          child: const Text('重试'),
        ),
      ];
    }

    // 正在检查
    if (_isChecking) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ];
    }

    // 检查结果
    return upgradeCheckAsync.when(
      data: (check) {
        if (check.hasUpdate) {
          return [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('稍后'),
            ),
            FilledButton(
              onPressed: _isStarting ? null : _startUpgrade,
              child: _isStarting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('立即升级'),
            ),
          ];
        }
        return [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ];
      },
      loading: () => [],
      error: (_, __) => [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        FilledButton(
          onPressed: _checkUpgrade,
          child: const Text('重试'),
        ),
      ],
    );
  }
}
