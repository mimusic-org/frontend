import 'dart:io' show File;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/utils/cover_url.dart';
import '../../../shared/utils/responsive_snackbar.dart';
import '../../player/presentation/providers/player_provider.dart';
import '../domain/playlist.dart';
import 'providers/playlist_provider.dart';
import 'widgets/playlist_card.dart';
import 'widgets/song_cover_picker_modal.dart';

/// 歌单列表页面
class PlaylistsPage extends ConsumerStatefulWidget {
  const PlaylistsPage({super.key});

  @override
  ConsumerState<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends ConsumerState<PlaylistsPage> {
  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(playlistListProvider(_selectedType));

    return Scaffold(
      appBar: AppBar(
        title: const Text('歌单'),
        actions: [
          // 自动创建按钮
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: '自动创建歌单',
            onPressed: _autoCreatePlaylists,
          ),
          // 创建歌单按钮
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '创建歌单',
            onPressed: () => _showCreateDialog(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(playlistListProvider(_selectedType));
        },
        child: CustomScrollView(
          slivers: [
            // 类型筛选
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SegmentedButton<String?>(
                  segments: const [
                    ButtonSegment(
                      value: null,
                      label: Text('全部'),
                      icon: Icon(Icons.list),
                    ),
                    ButtonSegment(
                      value: AppConstants.playlistTypeNormal,
                      label: Text('歌单'),
                      icon: Icon(Icons.queue_music),
                    ),
                    ButtonSegment(
                      value: AppConstants.playlistTypeRadio,
                      label: Text('电台'),
                      icon: Icon(Icons.radio),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (selected) {
                    setState(() {
                      _selectedType = selected.first;
                    });
                  },
                ),
              ),
            ),

            // 歌单列表
            playlistsAsync.when(
              data:
                  (response) => _buildPlaylistGrid(context, response.playlists),
              loading:
                  () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(64),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              error:
                  (error, stack) => SliverToBoxAdapter(
                    child: _buildErrorContent(error.toString()),
                  ),
            ),

            // 底部安全区域
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.bottom + 80,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistGrid(BuildContext context, List<Playlist> playlists) {
    if (playlists.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyContent());
    }

    final crossAxisCount = context.responsive<int>(
      mobile: 2,
      tablet: 3,
      desktop: 4,
      tv: 5,
    );

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.7, // 卡片高度比宽度略高，预留文字区域
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final playlist = playlists[index];
          return PlaylistCard(
            playlist: playlist,
            // 使用 push 保持导航栈，便于返回
            onTap: () => context.push('/playlists/${playlist.id}'),
            onEdit: () => _showEditDialog(playlist),
            onDelete:
                playlist.isBuiltIn ? null : () => _confirmDelete(playlist),
            onPlayAll: () => _playAll(playlist),
          );
        }, childCount: playlists.length),
      ),
    );
  }

  Widget _buildEmptyContent() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(64),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.queue_music_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无歌单',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右上角按钮创建歌单',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorContent(String error) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('加载失败', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              error,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  () => ref.invalidate(playlistListProvider(_selectedType)),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示创建歌单对话框
  Future<void> _showCreateDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _PlaylistFormDialog(title: '创建歌单'),
    );

    if (result != null && mounted) {
      final notifier = ref.read(playlistNotifierProvider.notifier);
      final playlist = await notifier.createPlaylist(
        type: result['type'] as String,
        name: result['name'] as String,
        description: result['description'] as String?,
      );

      if (playlist != null && mounted) {
        ResponsiveSnackBar.showSuccess(context, message: '歌单创建成功');
      }
    }
  }

  /// 显示编辑歌单对话框
  Future<void> _showEditDialog(Playlist playlist) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => _PlaylistFormDialog(
            title: playlist.isBuiltIn ? '修改封面' : '编辑歌单',
            initialName: playlist.name,
            initialDescription: playlist.description,
            initialType: playlist.type,
            initialCoverPath: playlist.coverPath,
            initialCoverUrl: playlist.coverUrl,
            playlistId: playlist.id,
            isEdit: true,
            isBuiltIn: playlist.isBuiltIn,
          ),
    );

    if (result != null && mounted) {
      final notifier = ref.read(playlistNotifierProvider.notifier);

      // 处理封面
      final coverMode = result['coverMode'] as String?;
      final localFile = result['localFile'] as PlatformFile?;
      final selectedCoverPath = result['selectedCoverPath'] as String?;
      final selectedCoverUrl = result['selectedCoverUrl'] as String?;

      if (coverMode == 'local' && localFile != null) {
        // 上传本地图片
        final uploadedPlaylist = await notifier.uploadPlaylistCover(
          playlist.id,
          bytes: localFile.bytes,
          filePath: localFile.path,
          fileName: localFile.name,
        );
        if (uploadedPlaylist == null && mounted) {
          ResponsiveSnackBar.showError(context, message: '封面上传失败');
          return;
        }
        // 更新其他信息，同时传递封面信息防止被后端覆盖
        final updated = await notifier.updatePlaylist(
          playlist.id,
          name: result['name'] as String,
          description: result['description'] as String?,
          coverPath: uploadedPlaylist?.coverPath,
          coverUrl: uploadedPlaylist?.coverUrl,
        );

        if (updated != null && mounted) {
          ResponsiveSnackBar.showSuccess(context, message: '歌单更新成功');
        }
      } else if (coverMode == 'song') {
        // 从歌曲选择的封面
        final updated = await notifier.updatePlaylist(
          playlist.id,
          name: result['name'] as String,
          description: result['description'] as String?,
          coverPath: selectedCoverPath ?? '',
          coverUrl: selectedCoverUrl ?? '',
        );

        if (updated != null && mounted) {
          ResponsiveSnackBar.showSuccess(context, message: '歌单更新成功');
        }
      } else if (coverMode == 'clear') {
        // 清除封面
        final updated = await notifier.updatePlaylist(
          playlist.id,
          name: result['name'] as String,
          description: result['description'] as String?,
          coverPath: '',
          coverUrl: '',
        );

        if (updated != null && mounted) {
          ResponsiveSnackBar.showSuccess(context, message: '歌单更新成功');
        }
      } else {
        // 未修改封面
        final updated = await notifier.updatePlaylist(
          playlist.id,
          name: result['name'] as String,
          description: result['description'] as String?,
        );

        if (updated != null && mounted) {
          ResponsiveSnackBar.showSuccess(context, message: '歌单更新成功');
        }
      }
    }
  }

  /// 确认删除歌单
  Future<void> _confirmDelete(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定要删除歌单「${playlist.name}」吗？此操作不可恢复。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('删除'),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      final notifier = ref.read(playlistNotifierProvider.notifier);
      final success = await notifier.deletePlaylist(playlist.id);

      if (success && mounted) {
        ResponsiveSnackBar.showSuccess(context, message: '歌单已删除');
      }
    }
  }

  /// 自动创建歌单
  Future<void> _autoCreatePlaylists() async {
    bool includeSubdirs = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('自动创建歌单'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '根据歌曲的文件路径自动创建歌单，每个目录对应一个歌单。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '注意：此操作会先删除所有之前自动创建的歌单（带 "auto_created" 标签），然后重新创建。',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          value: includeSubdirs,
                          onChanged: (value) {
                            setDialogState(() {
                              includeSubdirs = value ?? false;
                            });
                          },
                          title: const Text('包含子目录'),
                          subtitle: const Text(
                            '勾选后，歌曲会添加到所有祖先目录歌单中；否则只添加到直接父目录歌单',
                          ),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '示例',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '假设有歌曲：a/b/c.mp3, a/bb/cc.mp3, a/ccc.mp3',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '• 不包含子目录：创建 a、b、bb 三个歌单，a 只有 ccc.mp3',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '• 包含子目录：创建 a、b、bb 三个歌单，a 包含所有歌曲',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('确认创建'),
                    ),
                  ],
                ),
          ),
    );

    if (confirmed != true || !mounted) return;

    final notifier = ref.read(playlistNotifierProvider.notifier);
    final success = await notifier.autoCreatePlaylists(
      includeSubdirs: includeSubdirs,
    );

    if (mounted) {
      if (success) {
        ResponsiveSnackBar.showSuccess(context, message: '自动创建歌单成功');
      } else {
        ResponsiveSnackBar.showError(context, message: '自动创建歌单失败');
      }
    }
  }

  /// 播放歌单全部歌曲（委托给 PlayerNotifier.playPlaylistById）
  Future<void> _playAll(Playlist playlist) async {
    final total = await ref
        .read(playerStateProvider.notifier)
        .playPlaylistById(playlist.id);
    if (!mounted) return;
    if (total < 0) {
      ResponsiveSnackBar.showError(context, message: '播放失败');
    } else if (total == 0) {
      ResponsiveSnackBar.show(context, message: '歌单为空');
    } else {
      ResponsiveSnackBar.show(context, message: '播放全部 $total 首歌曲');
    }
  }
}

/// 歌单表单对话框
class _PlaylistFormDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialDescription;
  final String? initialType;
  final String? initialCoverPath;
  final String? initialCoverUrl;
  final int? playlistId;
  final bool isEdit;
  final bool isBuiltIn;

  const _PlaylistFormDialog({
    required this.title,
    this.initialName,
    this.initialDescription,
    this.initialType,
    this.initialCoverPath,
    this.initialCoverUrl,
    this.playlistId,
    this.isEdit = false,
    this.isBuiltIn = false,
  });

  @override
  State<_PlaylistFormDialog> createState() => _PlaylistFormDialogState();
}

class _PlaylistFormDialogState extends State<_PlaylistFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _type;
  final _formKey = GlobalKey<FormState>();

  /// 封面选择模式（仅编辑模式）
  String? _coverMode;
  PlatformFile? _localFile;
  String? _selectedCoverPath;
  String? _selectedCoverUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _type = widget.initialType ?? AppConstants.playlistTypeNormal;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// 获取当前预览的封面 URL
  String? get _previewCoverUrl {
    if (_coverMode == 'clear') return null;
    if (_coverMode == 'song') {
      return CoverUrl.buildCoverUrl(
        coverUrl: _selectedCoverUrl,
        coverPath: _selectedCoverPath,
      );
    }
    // 未修改时显示原有封面
    if (_coverMode == null) {
      return CoverUrl.buildCoverUrl(
        coverUrl: widget.initialCoverUrl,
        coverPath: widget.initialCoverPath,
      );
    }
    return null;
  }

  /// 上传本地图片
  Future<void> _pickLocalImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _localFile = result.files.first;
          _coverMode = 'local';
        });
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(context, message: '选择图片失败: $e');
      }
    }
  }

  /// 从歌曲选择封面
  Future<void> _pickFromSongs() async {
    if (widget.playlistId == null) return;
    final result = await showSongCoverPicker(context, widget.playlistId!);
    if (result != null) {
      setState(() {
        _selectedCoverPath = result['coverPath'];
        _selectedCoverUrl = result['coverUrl'];
        _coverMode = 'song';
        _localFile = null;
      });
    }
  }

  /// 清除封面
  void _clearCover() {
    setState(() {
      _coverMode = 'clear';
      _localFile = null;
      _selectedCoverPath = null;
      _selectedCoverUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasCover =
        _coverMode != 'clear' &&
        (_coverMode == 'local' ||
            _coverMode == 'song' ||
            widget.initialCoverPath?.isNotEmpty == true ||
            widget.initialCoverUrl?.isNotEmpty == true);

    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 编辑模式显示封面选择
                if (widget.isEdit) ...[
                  // 封面预览区域
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildCoverPreview(colorScheme),
                  ),
                  const SizedBox(height: 12),

                  // 封面操作按钮
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickLocalImage,
                        icon: const Icon(Icons.upload, size: 18),
                        label: const Text('上传图片'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickFromSongs,
                        icon: const Icon(Icons.music_note, size: 18),
                        label: const Text('从歌曲选择'),
                      ),
                      if (hasCover)
                        TextButton.icon(
                          onPressed: _clearCover,
                          icon: Icon(
                            Icons.clear,
                            size: 18,
                            color: colorScheme.error,
                          ),
                          label: Text(
                            '清除',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 歌单名称
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '歌单名称',
                    hintText: '请输入歌单名称',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入歌单名称';
                    }
                    return null;
                  },
                  autofocus: !widget.isEdit,
                  enabled: !widget.isBuiltIn,
                ),
                const SizedBox(height: 16),

                // 歌单描述
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '歌单描述',
                    hintText: '请输入歌单描述（可选）',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  enabled: !widget.isBuiltIn,
                ),
                const SizedBox(height: 16),

                // 歌单类型（仅创建时可选）
                if (!widget.isEdit)
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: AppConstants.playlistTypeNormal,
                        label: Text('普通歌单'),
                        icon: Icon(Icons.queue_music),
                      ),
                      ButtonSegment(
                        value: AppConstants.playlistTypeRadio,
                        label: Text('电台歌单'),
                        icon: Icon(Icons.radio),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (selected) {
                      setState(() {
                        _type = selected.first;
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('确定')),
      ],
    );
  }

  Widget _buildCoverPreview(ColorScheme colorScheme) {
    // 本地文件预览
    if (_coverMode == 'local' && _localFile != null) {
      if (kIsWeb && _localFile!.bytes != null) {
        return Image.memory(_localFile!.bytes!, fit: BoxFit.cover);
      } else if (!kIsWeb && _localFile!.path != null) {
        return Image.file(File(_localFile!.path!), fit: BoxFit.cover);
      }
    }

    // 网络图片预览
    final previewUrl = _previewCoverUrl;
    if (previewUrl != null) {
      return CachedNetworkImage(
        imageUrl: previewUrl,
        fit: BoxFit.cover,
        placeholder:
            (context, url) =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (context, url, error) => _buildPlaceholder(colorScheme),
      );
    }

    // 占位图
    return _buildPlaceholder(colorScheme);
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        Icons.queue_music,
        size: 40,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() == true) {
      final Map<String, dynamic> result = {
        'name': _nameController.text.trim(),
        'description':
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
        'type': _type,
      };

      // 编辑模式时添加封面信息
      if (widget.isEdit) {
        result['coverMode'] = _coverMode;
        result['localFile'] = _localFile;
        result['selectedCoverPath'] = _selectedCoverPath;
        result['selectedCoverUrl'] = _selectedCoverUrl;
      }

      Navigator.of(context).pop(result);
    }
  }
}
