import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/library/presentation/providers/favorite_provider.dart';

/// 收藏按钮组件
/// 点击切换收藏状态，带有缩放动画效果
class FavoriteButton extends ConsumerStatefulWidget {
  /// 歌曲 ID
  final int songId;

  /// 图标大小
  final double size;

  /// 点击回调（可选，用于自定义处理逻辑）
  final void Function(bool isFavorited)? onToggle;

  const FavoriteButton({
    super.key,
    required this.songId,
    this.size = 24,
    this.onToggle,
  });

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    _animationController.forward(from: 0);

    final isFavorited = ref.read(isSongFavoritedProvider(widget.songId));

    try {
      final newState = await ref
          .read(favoriteProvider.notifier)
          .toggleFavorite(widget.songId);

      widget.onToggle?.call(newState);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newState ? '已添加到收藏' : '已取消收藏'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFavorited ? '取消收藏失败' : '收藏失败'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavorited = ref.watch(isSongFavoritedProvider(widget.songId));

    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        onPressed: _isLoading ? null : _toggleFavorite,
        iconSize: widget.size,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: widget.size + 8,
          minHeight: widget.size + 8,
        ),
        icon: Icon(
          isFavorited ? Icons.favorite : Icons.favorite_border,
          color: isFavorited
              ? Colors.red
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        tooltip: isFavorited ? '取消收藏' : '收藏',
      ),
    );
  }
}
