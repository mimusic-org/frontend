import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/constants.dart';
import '../../../shared/models/song.dart';
import 'providers/songs_provider.dart';

/// 编辑/添加网络歌曲或电台的页面
class SongEditPage extends ConsumerStatefulWidget {
  final Song? song;
  final String songType; // 'remote' 或 'radio'

  const SongEditPage({
    super.key,
    this.song,
    required this.songType,
  });

  @override
  ConsumerState<SongEditPage> createState() => _SongEditPageState();
}

class _SongEditPageState extends ConsumerState<SongEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _albumController;
  late final TextEditingController _urlController;
  late final TextEditingController _coverUrlController;
  late final TextEditingController _durationController;
  late bool _isLive;
  bool _isSubmitting = false;

  bool get isEditMode => widget.song != null;
  bool get isRadio => widget.songType == AppConstants.songTypeRadio;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song?.title ?? '');
    _artistController = TextEditingController(text: widget.song?.artist ?? '');
    _albumController = TextEditingController(text: widget.song?.album ?? '');
    _urlController = TextEditingController(text: widget.song?.url ?? '');
    _coverUrlController = TextEditingController(text: widget.song?.coverUrl ?? '');
    _durationController = TextEditingController(
      text: widget.song?.duration.toStringAsFixed(0) ?? '',
    );
    _isLive = widget.song?.isLive ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _urlController.dispose();
    _coverUrlController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode
            ? (isRadio ? '编辑电台' : '编辑网络歌曲')
            : (isRadio ? '添加电台' : '添加网络歌曲')),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _onSubmit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '标题 *',
                  hintText: '请输入标题',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入标题';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // 艺术家
              TextFormField(
                controller: _artistController,
                decoration: const InputDecoration(
                  labelText: '艺术家',
                  hintText: '请输入艺术家',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // 专辑（仅网络歌曲）
              if (!isRadio) ...[
                TextFormField(
                  controller: _albumController,
                  decoration: const InputDecoration(
                    labelText: '专辑',
                    hintText: '请输入专辑',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
              ],

              // URL
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL *',
                  hintText: '请输入音频链接',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入 URL';
                  }
                  final uri = Uri.tryParse(value);
                  if (uri == null || !uri.hasScheme) {
                    return '请输入有效的 URL';
                  }
                  return null;
                },
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // 封面 URL
              TextFormField(
                controller: _coverUrlController,
                decoration: const InputDecoration(
                  labelText: '封面 URL',
                  hintText: '请输入封面图片链接',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // 时长（仅网络歌曲）
              if (!isRadio) ...[
                TextFormField(
                  controller: _durationController,
                  decoration: const InputDecoration(
                    labelText: '时长（秒）',
                    hintText: '请输入时长',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 16),
              ],

              // 直播流（仅电台）
              if (isRadio) ...[
                SwitchListTile(
                  title: const Text('直播流'),
                  subtitle: const Text('开启后表示这是一个直播电台'),
                  value: _isLive,
                  onChanged: (value) {
                    setState(() {
                      _isLive = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              // 封面预览
              if (_coverUrlController.text.isNotEmpty) ...[
                const Text('封面预览：'),
                const SizedBox(height: 8),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _coverUrlController.text,
                      width: 150,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 150,
                        height: 150,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 48),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repository = ref.read(songsRepositoryProvider);

      if (isEditMode) {
        // 更新歌曲
        await repository.updateSong(
          widget.song!.id,
          title: _titleController.text.trim(),
          artist: _artistController.text.trim().isEmpty
              ? null
              : _artistController.text.trim(),
          album: isRadio
              ? null
              : (_albumController.text.trim().isEmpty
                  ? null
                  : _albumController.text.trim()),
          url: _urlController.text.trim(),
          coverUrl: _coverUrlController.text.trim().isEmpty
              ? null
              : _coverUrlController.text.trim(),
          duration: isRadio
              ? null
              : (double.tryParse(_durationController.text)),
          isLive: isRadio ? _isLive : null,
        );
      } else if (isRadio) {
        // 创建电台
        await repository.createRadioSong(
          title: _titleController.text.trim(),
          artist: _artistController.text.trim().isEmpty
              ? null
              : _artistController.text.trim(),
          url: _urlController.text.trim(),
          coverUrl: _coverUrlController.text.trim().isEmpty
              ? null
              : _coverUrlController.text.trim(),
          isLive: _isLive,
        );
      } else {
        // 创建网络歌曲
        await repository.createRemoteSong(
          title: _titleController.text.trim(),
          artist: _artistController.text.trim().isEmpty
              ? null
              : _artistController.text.trim(),
          album: _albumController.text.trim().isEmpty
              ? null
              : _albumController.text.trim(),
          url: _urlController.text.trim(),
          coverUrl: _coverUrlController.text.trim().isEmpty
              ? null
              : _coverUrlController.text.trim(),
          duration: double.tryParse(_durationController.text),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditMode ? '保存成功' : '添加成功')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
