import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/storage/lyric_cache_service.dart';
import '../../../../shared/utils/responsive_snackbar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/cache_api.dart';
import '../providers/settings_provider.dart';

/// 缓存大小档位选项
const _cacheSizeOptions = [
  (value: 100 * 1024 * 1024, label: '100 MB'),
  (value: 500 * 1024 * 1024, label: '500 MB'),
  (value: 1024 * 1024 * 1024, label: '1 GB'),
  (value: 2 * 1024 * 1024 * 1024, label: '2 GB'),
  (value: 5 * 1024 * 1024 * 1024, label: '5 GB'),
  (value: 10 * 1024 * 1024 * 1024, label: '10 GB'),
  (value: 0, label: '不限制'),
];

/// 缓存管理 Widget
///
/// 管理服务端音乐缓存和本地缓存（音频 + 图片 + 歌词）。
/// 作为设置页面的一个分组卡片内容。
class CacheManager extends ConsumerStatefulWidget {
  const CacheManager({super.key});

  @override
  ConsumerState<CacheManager> createState() => _CacheManagerState();
}

class _CacheManagerState extends ConsumerState<CacheManager> {
  bool _isCleaningServer = false;
  bool _isCleaningLocal = false;
  int _localCacheSize = 0;
  bool _localCacheSizeLoaded = false;
  int _localCacheMaxSizeIndex = 2; // 默认 1 GB（索引 2）
  bool _localConfigLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadLocalCacheSize();
      _loadLocalCacheConfig();
    }
  }

  /// 加载本地缓存配置
  Future<void> _loadLocalCacheConfig() async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      final maxSize = prefs.getLocalCacheMaxSize();
      if (mounted) {
        setState(() {
          _localCacheMaxSizeIndex = _findSizeIndex(maxSize);
          _localConfigLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('[CacheManager] 加载本地缓存配置失败: $e');
    }
  }

  /// 保存本地缓存大小配置
  Future<void> _saveLocalCacheMaxSize(int index) async {
    try {
      final prefs = await ref.read(appPreferencesProvider.future);
      final maxSize = _cacheSizeOptions[index].value;
      await prefs.setLocalCacheMaxSize(maxSize);
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '保存配置失败: $e');
      }
    }
  }

  /// 加载本地缓存大小
  Future<void> _loadLocalCacheSize() async {
    int total = 0;

    // 歌词缓存大小
    total += await LyricCacheService().getCacheSize();

    // just_audio 缓存大小（临时目录中的 just_audio_cache）
    try {
      final tempDir = await getTemporaryDirectory();
      final audioCacheDir = Directory('${tempDir.path}/just_audio_cache');
      if (await audioCacheDir.exists()) {
        await for (final entity in audioCacheDir.list(recursive: true)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
    } catch (e) {
      debugPrint('[CacheManager] 获取音频缓存大小失败: $e');
    }

    // cached_network_image 图片缓存大小
    try {
      final tempDir = await getTemporaryDirectory();
      final imageCacheDir =
          Directory('${tempDir.path}/libCachedImageData');
      if (await imageCacheDir.exists()) {
        await for (final entity in imageCacheDir.list(recursive: true)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
    } catch (e) {
      debugPrint('[CacheManager] 获取图片缓存大小失败: $e');
    }

    if (mounted) {
      setState(() {
        _localCacheSize = total;
        _localCacheSizeLoaded = true;
      });
    }
  }

  /// 清理服务端缓存
  Future<void> _cleanServerCache() async {
    final confirmed = await _showConfirmDialog(
      title: '清理服务端缓存',
      content: '确定要清理服务端的所有音乐缓存吗？清理后需要重新下载。',
    );
    if (confirmed != true) return;

    setState(() => _isCleaningServer = true);
    try {
      final cacheApi = ref.read(cacheApiProvider);
      await cacheApi.cleanCache();
      // 刷新统计数据
      ref.invalidate(serverCacheStatsProvider);
      if (mounted) {
        ResponsiveSnackBar.show(context, message: '服务端缓存已清理');
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '清理失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isCleaningServer = false);
    }
  }

  /// 清理本地缓存
  Future<void> _cleanLocalCache() async {
    final confirmed = await _showConfirmDialog(
      title: '清理本地缓存',
      content: '确定要清理所有本地缓存吗？包括音频缓存、图片缓存和歌词缓存。',
    );
    if (confirmed != true) return;

    setState(() => _isCleaningLocal = true);
    try {
      // 清理歌词缓存
      await LyricCacheService().clear();

      // 清理 just_audio 缓存
      try {
        final tempDir = await getTemporaryDirectory();
        final audioCacheDir = Directory('${tempDir.path}/just_audio_cache');
        if (await audioCacheDir.exists()) {
          await audioCacheDir.delete(recursive: true);
        }
      } catch (e) {
        debugPrint('[CacheManager] 清理音频缓存失败: $e');
      }

      // 清理 cached_network_image 图片缓存
      try {
        final tempDir = await getTemporaryDirectory();
        final imageCacheDir =
            Directory('${tempDir.path}/libCachedImageData');
        if (await imageCacheDir.exists()) {
          await imageCacheDir.delete(recursive: true);
        }
      } catch (e) {
        debugPrint('[CacheManager] 清理图片缓存失败: $e');
      }

      // 重新加载本地缓存大小
      await _loadLocalCacheSize();

      if (mounted) {
        ResponsiveSnackBar.show(context, message: '本地缓存已清理');
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '清理失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isCleaningLocal = false);
    }
  }

  /// 更新服务端缓存配置
  Future<void> _updateServerCacheConfig(int maxSize) async {
    try {
      final cacheApi = ref.read(cacheApiProvider);
      await cacheApi.updateCacheConfig(CacheConfig(maxSize: maxSize));
      ref.invalidate(serverCacheConfigProvider);
      ref.invalidate(serverCacheStatsProvider);
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '更新配置失败: $e');
      }
    }
  }

  /// 显示确认对话框
  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
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
            child: const Text('确认清理'),
          ),
        ],
      ),
    );
  }

  /// 格式化文件大小
  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 根据 maxSize 值找到对应的档位索引
  int _findSizeIndex(int maxSize) {
    for (int i = 0; i < _cacheSizeOptions.length; i++) {
      if (_cacheSizeOptions[i].value == maxSize) return i;
    }
    // 默认 1 GB（索引 2）
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 服务端音乐缓存
          _buildServerCacheSection(theme, colorScheme),

          // 本地缓存（仅非 Web 平台显示）
          if (!kIsWeb) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _buildLocalCacheSection(theme, colorScheme),
          ],
        ],
      ),
    );
  }

  /// 构建服务端缓存区域
  Widget _buildServerCacheSection(ThemeData theme, ColorScheme colorScheme) {
    final statsAsync = ref.watch(serverCacheStatsProvider);
    final configAsync = ref.watch(serverCacheConfigProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cloud_outlined, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '服务端音乐缓存',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 缓存统计
        statsAsync.when(
          data: (stats) {
            final maxSize = stats.maxSize;
            final progress =
                maxSize > 0 ? (stats.totalSize / maxSize).clamp(0.0, 1.0) : 0.0;
            final sizeText = maxSize > 0
                ? '${_formatSize(stats.totalSize)} / ${_formatSize(maxSize)}'
                : '${_formatSize(stats.totalSize)} (无上限)';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(sizeText, style: theme.textTheme.bodyMedium),
                    Text(
                      '${stats.fileCount} 个文件',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (maxSize > 0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor:
                          colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress > 0.9
                            ? colorScheme.error
                            : colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (e, _) => Text(
            '获取缓存信息失败',
            style: TextStyle(color: colorScheme.error),
          ),
        ),

        const SizedBox(height: 16),

        // 最大缓存大小滑动条
        configAsync.when(
          data: (config) {
            int currentIndex = _findSizeIndex(config.maxSize);
            return StatefulBuilder(
              builder: (context, setSliderState) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '最大缓存大小: ${_cacheSizeOptions[currentIndex].label}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Slider(
                      value: currentIndex.toDouble(),
                      min: 0,
                      max: (_cacheSizeOptions.length - 1).toDouble(),
                      divisions: _cacheSizeOptions.length - 1,
                      label: _cacheSizeOptions[currentIndex].label,
                      onChanged: (value) {
                        setSliderState(() {
                          currentIndex = value.round();
                        });
                      },
                      onChangeEnd: (value) {
                        final newMaxSize =
                            _cacheSizeOptions[value.round()].value;
                        _updateServerCacheConfig(newMaxSize);
                      },
                    ),
                  ],
                );
              },
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 8),

        // 清理按钮
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isCleaningServer ? null : _cleanServerCache,
            icon: _isCleaningServer
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            label: Text(_isCleaningServer ? '清理中...' : '清理服务端缓存'),
          ),
        ),
      ],
    );
  }

  /// 构建本地缓存区域
  Widget _buildLocalCacheSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.phone_android_outlined,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '本地缓存',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 本地缓存大小
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '缓存大小',
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              _localCacheSizeLoaded
                  ? _formatSize(_localCacheSize)
                  : '计算中...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '包含音频缓存、图片缓存和歌词缓存',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 16),

        // 最大本地缓存大小滑动条
        if (_localConfigLoaded) ...[
          Text(
            '最大本地缓存大小: ${_cacheSizeOptions[_localCacheMaxSizeIndex].label}',
            style: theme.textTheme.bodyMedium,
          ),
          Slider(
            value: _localCacheMaxSizeIndex.toDouble(),
            min: 0,
            max: (_cacheSizeOptions.length - 1).toDouble(),
            divisions: _cacheSizeOptions.length - 1,
            label: _cacheSizeOptions[_localCacheMaxSizeIndex].label,
            onChanged: (value) {
              setState(() {
                _localCacheMaxSizeIndex = value.round();
              });
            },
            onChangeEnd: (value) {
              _saveLocalCacheMaxSize(value.round());
            },
          ),
          const SizedBox(height: 8),
        ],

        // 清理按钮
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isCleaningLocal ? null : _cleanLocalCache,
            icon: _isCleaningLocal
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            label: Text(_isCleaningLocal ? '清理中...' : '清理本地缓存'),
          ),
        ),
      ],
    );
  }
}
