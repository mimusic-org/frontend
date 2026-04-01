import 'package:flutter/material.dart';

/// 响应式 SnackBar 辅助工具
///
/// 根据屏幕类型自动调整 SnackBar 的字体大小、内边距和宽度，
/// 确保在 TV 和大屏幕设备上具有良好的可读性。
class ResponsiveSnackBar {
  ResponsiveSnackBar._();

  /// 计算消息文本所需的宽度（含内边距），上限为屏幕宽度减去边距
  static double _calcWidth(BuildContext context, String message) {
    // SnackBar Material3 默认 padding: horizontal 16, vertical 14
    const double snackBarHorizontalPadding = 16.0;
    const double safetyBuffer = 16.0; // 防止字体渲染误差导致换行
    const double minWidth = 120.0;
    const double screenMargin = 32.0; // 左右各 16dp 屏幕边距

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScaler = mediaQuery.textScaler;
    final maxWidth = screenWidth - screenMargin;

    // 获取当前主题的默认字体大小（SnackBar content 默认 bodyMedium）
    final defaultFontSize =
        Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14.0;
    final scaledFontSize = textScaler.scale(defaultFontSize);

    final textPainter = TextPainter(
      text: TextSpan(text: message, style: TextStyle(fontSize: scaledFontSize)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth);

    final contentWidth =
        textPainter.width + snackBarHorizontalPadding * 2 + safetyBuffer;
    return contentWidth.clamp(minWidth, maxWidth);
  }

  /// 显示响应式 SnackBar
  ///
  /// 所有端统一使用自适应内容宽度，Toast 背景随文字长度变化。
  static void show(
    BuildContext context, {
    required String message,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(
          // 显式设置颜色确保对比度
          // 自定义背景色时用白色，默认背景使用 Material 3 的 onInverseSurface
          color:
              backgroundColor != null
                  ? Colors.white
                  : Theme.of(context).colorScheme.onInverseSurface,
        ),
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      width: _calcWidth(context, message),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  /// 显示错误类型的响应式 SnackBar
  static void showError(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    show(
      context,
      message: message,
      backgroundColor: colorScheme.error,
      duration: duration,
    );
  }

  /// 显示成功类型的响应式 SnackBar
  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    show(
      context,
      message: message,
      backgroundColor: colorScheme.primary,
      duration: duration,
    );
  }
}
