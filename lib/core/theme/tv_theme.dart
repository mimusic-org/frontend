import 'package:flutter/material.dart';

/// TV 端的主题配置和尺寸常量
class TvTheme {
  TvTheme._();

  // ==================== 尺寸常量 ====================
  
  /// 按钮最小尺寸
  static const double minButtonSize = 80;
  
  /// 标题字体大小 (24sp)
  static const double fontSizeTitle = 24;
  
  /// 正文字体大小 (20sp)
  static const double fontSizeBody = 20;
  
  /// 副标题/说明字体大小 (16sp)
  static const double fontSizeCaption = 16;
  
  /// 按钮文字大小 (18sp)
  static const double fontSizeButton = 18;
  
  /// 网格间距
  static const double gridSpacing = 24;
  
  /// 内容区域内边距
  static const double contentPadding = 48;
  
  /// 网格列数
  static const int gridColumns = 4;
  
  /// 焦点边框宽度
  static const double focusBorderWidth = 3;
  
  /// 焦点缩放比例
  static const double focusScale = 1.05;
  
  /// 列表项最小高度
  static const double listItemMinHeight = 72;
  
  /// 导航栏高度
  static const double navBarHeight = 80;
  
  /// Tab 项最小高度
  static const double tabItemMinHeight = 64;
  
  /// 封面图大尺寸（播放器用）
  static const double largeCoverSize = 300;
  
  /// 封面图中等尺寸（卡片用）
  static const double mediumCoverSize = 200;
  
  /// 卡片圆角
  static const double cardRadius = 16;
  
  /// 焦点动画时长
  static const Duration focusAnimationDuration = Duration(milliseconds: 150);
  
  // ==================== 间距常量 ====================
  
  /// 小间距
  static const double spacingSmall = 8;
  
  /// 中等间距
  static const double spacingMedium = 16;
  
  /// 大间距
  static const double spacingLarge = 24;
  
  /// 超大间距
  static const double spacingXLarge = 48;
  
  // ==================== 边距预设 ====================
  
  /// 内容区域默认内边距
  static const EdgeInsets contentPaddingAll = EdgeInsets.all(contentPadding);
  
  /// 网格内边距
  static const EdgeInsets gridPadding = EdgeInsets.all(48);
  
  /// 列表项内边距
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 16,
  );
  
  // ==================== 文字样式 ====================
  
  /// 获取 TV 标题文字样式
  static TextStyle titleStyle(BuildContext context) {
    return Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontSize: fontSizeTitle,
      fontWeight: FontWeight.w600,
    ) ?? const TextStyle(fontSize: fontSizeTitle, fontWeight: FontWeight.w600);
  }
  
  /// 获取 TV 正文文字样式
  static TextStyle bodyStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontSize: fontSizeBody,
    ) ?? const TextStyle(fontSize: fontSizeBody);
  }
  
  /// 获取 TV 副标题文字样式
  static TextStyle captionStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyMedium?.copyWith(
      fontSize: fontSizeCaption,
      color: theme.colorScheme.onSurfaceVariant,
    ) ?? TextStyle(
      fontSize: fontSizeCaption,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }
  
  /// 获取 TV 按钮文字样式
  static TextStyle buttonStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
      fontSize: fontSizeButton,
      fontWeight: FontWeight.w500,
    ) ?? const TextStyle(fontSize: fontSizeButton, fontWeight: FontWeight.w500);
  }
}
