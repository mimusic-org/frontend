import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/tv_theme.dart';

/// TV 焦点组件包装器
/// 
/// 用于在 TV 端提供 D-Pad 焦点导航支持，包含：
/// - 焦点状态的视觉反馈（缩放、边框、阴影）
/// - Enter/Select 按键处理
/// - 平滑的动画过渡
class TvFocusable extends StatefulWidget {
  /// 子组件
  final Widget child;
  
  /// Enter/Select 按下时触发
  final VoidCallback? onSelect;
  
  /// 是否自动获取焦点
  final bool autofocus;
  
  /// 自定义焦点节点
  final FocusNode? focusNode;
  
  /// 获焦时的缩放比例，默认 1.05
  final double focusedScale;
  
  /// 焦点边框宽度，默认 3
  final double focusBorderWidth;
  
  /// 焦点边框颜色，默认使用主题色
  final Color? focusBorderColor;
  
  /// 是否显示焦点阴影
  final bool showShadow;
  
  /// 边框圆角，默认 12
  final double borderRadius;
  
  /// 动画时长
  final Duration animationDuration;
  
  /// 是否启用焦点
  final bool enabled;

  const TvFocusable({
    super.key,
    required this.child,
    this.onSelect,
    this.autofocus = false,
    this.focusNode,
    this.focusedScale = TvTheme.focusScale,
    this.focusBorderWidth = TvTheme.focusBorderWidth,
    this.focusBorderColor,
    this.showShadow = true,
    this.borderRadius = 12,
    this.animationDuration = TvTheme.focusAnimationDuration,
    this.enabled = true,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  late FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(TvFocusable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
    }
  }

  /// 处理按键事件
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled || widget.onSelect == null) {
      return KeyEventResult.ignored;
    }

    // 只处理按下事件
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    // 处理 Enter 键和 Select 键（遥控器确认键）
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA ||
        event.logicalKey == LogicalKeyboardKey.space) {
      widget.onSelect?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focusBorderColor = widget.focusBorderColor ?? theme.colorScheme.primary;

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      canRequestFocus: widget.enabled,
      onKeyEvent: _handleKeyEvent,
      onFocusChange: (hasFocus) {
        setState(() {
          _hasFocus = hasFocus;
        });
      },
      child: GestureDetector(
        onTap: widget.enabled ? widget.onSelect : null,
        child: AnimatedScale(
          scale: _hasFocus ? widget.focusedScale : 1.0,
          duration: widget.animationDuration,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: widget.animationDuration,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: _hasFocus
                  ? Border.all(
                      color: focusBorderColor,
                      width: widget.focusBorderWidth,
                    )
                  : Border.all(
                      color: Colors.transparent,
                      width: widget.focusBorderWidth,
                    ),
              boxShadow: _hasFocus && widget.showShadow
                  ? [
                      BoxShadow(
                        color: focusBorderColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                widget.borderRadius - widget.focusBorderWidth,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// TV 焦点按钮
/// 
/// 专为 TV 设计的大尺寸按钮，支持 D-Pad 焦点导航
class TvButton extends StatelessWidget {
  /// 按钮文字
  final String? label;
  
  /// 按钮图标
  final IconData? icon;
  
  /// 点击回调
  final VoidCallback? onPressed;
  
  /// 是否自动获取焦点
  final bool autofocus;
  
  /// 自定义焦点节点
  final FocusNode? focusNode;
  
  /// 按钮最小尺寸
  final double minSize;
  
  /// 图标大小
  final double iconSize;
  
  /// 是否启用
  final bool enabled;

  const TvButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.autofocus = false,
    this.focusNode,
    this.minSize = TvTheme.minButtonSize,
    this.iconSize = 32,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget content;
    
    if (icon != null && label != null) {
      // 图标 + 文字
      content = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize),
          const SizedBox(height: 4),
          Text(
            label!,
            style: TvTheme.buttonStyle(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else if (icon != null) {
      // 仅图标
      content = Icon(icon, size: iconSize);
    } else if (label != null) {
      // 仅文字
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Text(
          label!,
          style: TvTheme.buttonStyle(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else {
      content = const SizedBox.shrink();
    }

    return TvFocusable(
      onSelect: enabled ? onPressed : null,
      autofocus: autofocus,
      focusNode: focusNode,
      enabled: enabled,
      borderRadius: 16,
      child: Container(
        constraints: BoxConstraints(
          minWidth: minSize,
          minHeight: minSize,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: content,
        ),
      ),
    );
  }
}

/// TV 图标按钮
/// 
/// 简化版的 TV 按钮，仅包含图标
class TvIconButton extends StatelessWidget {
  /// 按钮图标
  final IconData icon;
  
  /// 点击回调
  final VoidCallback? onPressed;
  
  /// 是否自动获取焦点
  final bool autofocus;
  
  /// 自定义焦点节点
  final FocusNode? focusNode;
  
  /// 按钮尺寸
  final double size;
  
  /// 图标大小
  final double iconSize;
  
  /// 是否启用
  final bool enabled;
  
  /// 背景颜色
  final Color? backgroundColor;
  
  /// 图标颜色
  final Color? iconColor;

  const TvIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.autofocus = false,
    this.focusNode,
    this.size = TvTheme.minButtonSize,
    this.iconSize = 32,
    this.enabled = true,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return TvFocusable(
      onSelect: enabled ? onPressed : null,
      autofocus: autofocus,
      focusNode: focusNode,
      enabled: enabled,
      borderRadius: size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Icon(
            icon,
            size: iconSize,
            color: iconColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
