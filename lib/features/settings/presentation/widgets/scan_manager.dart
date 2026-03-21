import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exceptions.dart';
import '../providers/settings_provider.dart';

/// 扫描管理组件
class ScanManager extends ConsumerStatefulWidget {
  const ScanManager({super.key});

  @override
  ConsumerState<ScanManager> createState() => _ScanManagerState();
}

class _ScanManagerState extends ConsumerState<ScanManager> {
  bool _isLoading = false;
  String? _error;
  String _scanMode = 'skip'; // 'skip' 或 'reimport'

  @override
  void initState() {
    super.initState();
    // 初始化时刷新进度状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scanProgressProvider.notifier).refreshProgress();
    });
  }

  Future<void> _startScan() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(scanProgressProvider.notifier).startScan(
        reimport: _scanMode == 'reimport',
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '扫描失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelScan() async {
    try {
      await ref.read(scanProgressProvider.notifier).cancelScan();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取消失败: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取消失败: $e')),
        );
      }
    }
  }

  void _reset() {
    ref.read(scanProgressProvider.notifier).reset();
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(scanProgressProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 错误信息
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _error = null),
                  iconSize: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 根据状态显示不同内容
        if (progress.isIdle) _buildIdleState(),
        if (progress.isScanning) _buildScanningState(progress),
        if (progress.isCompleted) _buildCompletedState(progress),
        if (progress.isCancelled) _buildCancelledState(progress),
        if (progress.isError) _buildErrorState(progress),
      ],
    );
  }

  Widget _buildIdleState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 扫描模式选择器
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'skip', label: Text('跳过已存在')),
            ButtonSegment(value: 'reimport', label: Text('重新导入')),
          ],
          selected: {_scanMode},
          onSelectionChanged: (selected) {
            setState(() => _scanMode = selected.first);
          },
        ),
        const SizedBox(height: 12),
        // 扫描按钮
        FilledButton.icon(
      onPressed: _isLoading ? null : _startScan,
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.search),
      label: Text(_isLoading ? '正在启动...' : '扫描本地音乐'),
        ),
      ],
    );
  }

  Widget _buildScanningState(progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 进度条
        LinearProgressIndicator(
          value: progress.progress / 100,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 12),

        // 当前文件
        if (progress.currentFile != null)
          Text(
            '正在扫描: ${progress.currentFile}',
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 4),

        // 统计信息
        Text(
          '已处理: ${progress.processed}/${progress.totalFiles}, 新增: ${progress.added}, 更新: ${progress.updated}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),

        // 取消按钮
        OutlinedButton.icon(
          onPressed: _cancelScan,
          icon: const Icon(Icons.cancel),
          label: const Text('取消扫描'),
        ),
      ],
    );
  }

  Widget _buildCompletedState(progress) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('扫描完成'),
                    Text(
                      '新增 ${progress.added} 首, 更新 ${progress.updated} 首, 失败 ${progress.failed} 个',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.refresh),
          label: const Text('重新扫描'),
        ),
      ],
    );
  }

  Widget _buildCancelledState(progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '扫描已取消 (已处理 ${progress.processed} 个文件)',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.refresh),
          label: const Text('重新扫描'),
        ),
      ],
    );
  }

  Widget _buildErrorState(progress) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.error, color: colorScheme.error),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('扫描出错'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      ],
    );
  }
}
