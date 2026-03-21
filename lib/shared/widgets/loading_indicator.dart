import 'package:flutter/material.dart';

/// 加载指示器组件
class LoadingIndicator extends StatelessWidget {
  /// 加载提示文字（可选）
  final String? message;

  /// 指示器大小
  final double size;

  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 加载遮罩组件
/// 在子组件上方叠加半透明遮罩和加载指示器
class LoadingOverlay extends StatelessWidget {
  /// 是否显示加载状态
  final bool isLoading;

  /// 子组件
  final Widget child;

  /// 加载提示文字
  final String? message;

  /// 遮罩颜色
  final Color? overlayColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.overlayColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: overlayColor ??
                  Theme.of(context).colorScheme.surface.withAlpha(200),
              child: LoadingIndicator(message: message),
            ),
          ),
      ],
    );
  }
}
