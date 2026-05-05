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

  /// 焦点变化回调
  final ValueChanged<bool>? onFocusChange;

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
    this.onFocusChange,
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
        widget.onFocusChange?.call(hasFocus);
      },
      child: GestureDetector(
        onTap: widget.enabled ? widget.onSelect : null,
        child: AnimatedScale(
          scale: _hasFocus ? widget.focusedScale : 1.0,
          duration: widget.animationDuration,
          curve: TvTheme.focusAnimationCurve,
          child: AnimatedContainer(
            duration: widget.animationDuration,
            curve: TvTheme.focusAnimationCurve,
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
                      // 外层柔和光晕
                      BoxShadow(
                        color: focusBorderColor.withValues(alpha: 0.3),
                        blurRadius: TvTheme.focusShadowBlurRadius,
                        spreadRadius: TvTheme.focusGlowSpreadRadius,
                      ),
                      // 内层锐利边框光
                      BoxShadow(
                        color: focusBorderColor.withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
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
class TvButton extends StatefulWidget {
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
  State<TvButton> createState() => _TvButtonState();
}

class _TvButtonState extends State<TvButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focusColor = _hasFocus ? theme.colorScheme.primary : null;
    
    Widget content;
    
    if (widget.icon != null && widget.label != null) {
      // 图标 + 文字
      content = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.icon, size: widget.iconSize, color: focusColor),
          const SizedBox(height: 4),
          Text(
            widget.label!,
            style: TvTheme.buttonStyle(context).copyWith(color: focusColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else if (widget.icon != null) {
      // 仅图标
      content = Icon(widget.icon, size: widget.iconSize, color: focusColor);
    } else if (widget.label != null) {
      // 仅文字
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Text(
          widget.label!,
          style: TvTheme.buttonStyle(context).copyWith(color: focusColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else {
      content = const SizedBox.shrink();
    }

    return TvFocusable(
      onSelect: widget.enabled ? widget.onPressed : null,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      borderRadius: 16,
      onFocusChange: (hasFocus) {
        setState(() {
          _hasFocus = hasFocus;
        });
      },
      child: Container(
        constraints: BoxConstraints(
          minWidth: widget.minSize,
          minHeight: widget.minSize,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.5,
          child: content,
        ),
      ),
    );
  }
}

/// TV 图标按钮
/// 
/// 简化版的 TV 按钮，仅包含图标
class TvIconButton extends StatefulWidget {
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

  /// 焦点变化回调
  final ValueChanged<bool>? onFocusChange;

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
    this.onFocusChange,
  });

  @override
  State<TvIconButton> createState() => _TvIconButtonState();
}

class _TvIconButtonState extends State<TvIconButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = _hasFocus
        ? theme.colorScheme.primary
        : (widget.iconColor ?? theme.colorScheme.onSurface);
    
    return TvFocusable(
      onSelect: widget.enabled ? widget.onPressed : null,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      borderRadius: widget.size / 2,
      onFocusChange: (hasFocus) {
        setState(() {
          _hasFocus = hasFocus;
        });
        widget.onFocusChange?.call(hasFocus);
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.5,
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: effectiveIconColor,
          ),
        ),
      ),
    );
  }
}

/// 为非按钮型容器元素（卡片、列表项）提供统一的 TV 焦点包装
class TvFocusableContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSelect;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  const TvFocusableContainer({
    super.key,
    required this.child,
    this.onSelect,
    this.autofocus = false,
    this.focusNode,
    this.onFocusChange,
    this.borderRadius,
    this.padding,
  });

  @override
  State<TvFocusableContainer> createState() => _TvFocusableContainerState();
}

class _TvFocusableContainerState extends State<TvFocusableContainer> {
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
  void didUpdateWidget(TvFocusableContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.onSelect == null) {
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

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
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(12);

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      onFocusChange: (hasFocus) {
        setState(() {
          _hasFocus = hasFocus;
        });
        widget.onFocusChange?.call(hasFocus);
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: TvTheme.focusAnimationDuration,
          curve: TvTheme.focusAnimationCurve,
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: _hasFocus
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
                : null,
            border: Border.all(
              color: _hasFocus
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: TvTheme.focusBorderWidth,
            ),
            boxShadow: _hasFocus
                ? [
                    // 外层柔和光晕
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: TvTheme.focusShadowBlurRadius,
                      spreadRadius: TvTheme.focusGlowSpreadRadius,
                    ),
                    // 内层锐利边框光
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
