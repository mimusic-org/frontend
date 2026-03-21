import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants.dart';
import '../../../core/theme/responsive.dart';
import '../../player/presentation/providers/player_provider.dart';
import '../domain/playlist.dart';
import 'providers/playlist_provider.dart';
import 'widgets/playlist_card.dart';

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
              data: (response) => _buildPlaylistGrid(context, response.playlists),
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(64),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, stack) => SliverToBoxAdapter(
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
      return SliverToBoxAdapter(
        child: _buildEmptyContent(),
      );
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
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final playlist = playlists[index];
            return PlaylistCard(
              playlist: playlist,
              // 使用 push 保持导航栈，便于返回
              onTap: () => context.push('/playlists/${playlist.id}'),
              onEdit: () => _showEditDialog(playlist),
              onDelete: playlist.isBuiltIn ? null : () => _confirmDelete(playlist),
              onPlayAll: () => _playAll(playlist),
            );
          },
          childCount: playlists.length,
        ),
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
            Icon(
              Icons.error_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: textTheme.titleMedium,
            ),
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
              onPressed: () => ref.invalidate(playlistListProvider(_selectedType)),
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
      builder: (context) => const _PlaylistFormDialog(
        title: '创建歌单',
      ),
    );

    if (result != null && mounted) {
      final notifier = ref.read(playlistNotifierProvider.notifier);
      final playlist = await notifier.createPlaylist(
        type: result['type'] as String,
        name: result['name'] as String,
        description: result['description'] as String?,
      );

      if (playlist != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('歌单创建成功')),
        );
      }
    }
  }

  /// 显示编辑歌单对话框
  Future<void> _showEditDialog(Playlist playlist) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _PlaylistFormDialog(
        title: '编辑歌单',
        initialName: playlist.name,
        initialDescription: playlist.description,
        initialType: playlist.type,
        isEdit: true,
      ),
    );

    if (result != null && mounted) {
      final notifier = ref.read(playlistNotifierProvider.notifier);
      final updated = await notifier.updatePlaylist(
        playlist.id,
        name: result['name'] as String,
        description: result['description'] as String?,
      );

      if (updated != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('歌单更新成功')),
        );
      }
    }
  }

  /// 确认删除歌单
  Future<void> _confirmDelete(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('歌单已删除')),
        );
      }
    }
  }

  /// 自动创建歌单
  Future<void> _autoCreatePlaylists() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自动创建歌单'),
        content: const Text('根据音乐文件的目录结构自动创建歌单，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final notifier = ref.read(playlistNotifierProvider.notifier);
      final success = await notifier.autoCreatePlaylists();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '歌单创建完成' : '创建失败'),
          ),
        );
      }
    }
  }

  /// 播放歌单全部歌曲
  Future<void> _playAll(Playlist playlist) async {
    try {
      // 获取歌单歌曲
      final playlistApi = ref.read(playlistApiProvider);
      final response = await playlistApi.getPlaylistSongs(playlist.id, limit: 9999, offset: 0);
      final songs = response.songs;

      if (songs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('歌单为空')),
          );
        }
        return;
      }

      // 调用播放器播放
      ref.read(playerStateProvider.notifier).playPlaylist(songs);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放全部 ${songs.length} 首歌曲')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
    }
  }
}

/// 歌单表单对话框
class _PlaylistFormDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialDescription;
  final String? initialType;
  final bool isEdit;

  const _PlaylistFormDialog({
    required this.title,
    this.initialName,
    this.initialDescription,
    this.initialType,
    this.isEdit = false,
  });

  @override
  State<_PlaylistFormDialog> createState() => _PlaylistFormDialogState();
}

class _PlaylistFormDialogState extends State<_PlaylistFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _type;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descriptionController = TextEditingController(text: widget.initialDescription);
    _type = widget.initialType ?? AppConstants.playlistTypeNormal;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                autofocus: true,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('确定'),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() == true) {
      Navigator.of(context).pop({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'type': _type,
      });
    }
  }
}
