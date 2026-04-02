import 'package:flutter/material.dart';

import '../../../../core/theme/responsive.dart';
import '../../domain/player_state.dart';

/// 播放模式弹出控制组件
class PopupPlayModeControl extends StatefulWidget {
  final PlayMode playMode;
  final ValueChanged<PlayMode> onPlayModeChanged;

  const PopupPlayModeControl({
    super.key,
    required this.playMode,
    required this.onPlayModeChanged,
  });

  @override
  State<PopupPlayModeControl> createState() => _PopupPlayModeControlState();
}

class _PopupPlayModeControlState extends State<PopupPlayModeControl> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  IconData get _playModeIcon {
    switch (widget.playMode) {
      case PlayMode.order:
        return Icons.format_list_numbered_rounded;
      case PlayMode.loop:
        return Icons.repeat_rounded;
      case PlayMode.single:
        return Icons.repeat_one_rounded;
      case PlayMode.random:
        return Icons.shuffle_rounded;
      case PlayMode.singlePlay:
        return Icons.looks_one_outlined;
    }
  }

  String _getPlayModeTooltip(PlayMode mode) {
    switch (mode) {
      case PlayMode.order:
        return '顺序播放';
      case PlayMode.loop:
        return '列表循环';
      case PlayMode.single:
        return '单曲循环';
      case PlayMode.random:
        return '随机播放';
      case PlayMode.singlePlay:
        return '单曲播放';
    }
  }

  void _showPlayModePanel() {
    _removeOverlay();

    final RenderBox? renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder:
          (context) => _PlayModeOverlayPanel(
            playMode: widget.playMode,
            onPlayModeChanged: (mode) {
              widget.onPlayModeChanged(mode);
              _removeOverlay();
            },
            onDismiss: _removeOverlay,
            anchorPosition: position,
            anchorSize: size,
            getIcon: _getPlayModeIconForMode,
            getTooltip: _getPlayModeTooltip,
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  IconData _getPlayModeIconForMode(PlayMode mode) {
    switch (mode) {
      case PlayMode.order:
        return Icons.format_list_numbered_rounded;
      case PlayMode.loop:
        return Icons.repeat_rounded;
      case PlayMode.single:
        return Icons.repeat_one_rounded;
      case PlayMode.random:
        return Icons.shuffle_rounded;
      case PlayMode.singlePlay:
        return Icons.looks_one_outlined;
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      key: _buttonKey,
      onPressed: _showPlayModePanel,
      icon: Icon(
        _playModeIcon,
        size: 20,
        color:
            widget.playMode != PlayMode.order
                ? theme.colorScheme.primary
                : null,
      ),
      tooltip: _getPlayModeTooltip(widget.playMode),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// 播放模式弹出面板
class _PlayModeOverlayPanel extends StatelessWidget {
  final PlayMode playMode;
  final ValueChanged<PlayMode> onPlayModeChanged;
  final VoidCallback onDismiss;
  final Offset anchorPosition;
  final Size anchorSize;
  final IconData Function(PlayMode) getIcon;
  final String Function(PlayMode) getTooltip;

  const _PlayModeOverlayPanel({
    required this.playMode,
    required this.onPlayModeChanged,
    required this.onDismiss,
    required this.anchorPosition,
    required this.anchorSize,
    required this.getIcon,
    required this.getTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    // 响应式面板尺寸
    final itemHeight = context.responsive<double>(
      mobile: 44,
      tablet: 48,
      desktop: 48,
      tv: 56,
    );
    final panelWidth = context.responsive<double>(
      mobile: 140,
      tablet: 160,
      desktop: 160,
      tv: 200,
    );
    final iconSize = context.responsive<double>(
      mobile: 20,
      tablet: 20,
      desktop: 20,
      tv: 24,
    );
    final fontSize = context.responsive<double>(
      mobile: 14,
      tablet: 14,
      desktop: 14,
      tv: 16,
    );

    final panelHeight = PlayMode.values.length * itemHeight + 16;

    // 计算面板位置（居中对齐按钮）
    double left = anchorPosition.dx + anchorSize.width / 2 - panelWidth / 2;
    // 确保不超出屏幕
    if (left < 16) left = 16;
    if (left + panelWidth > screenSize.width - 16) {
      left = screenSize.width - panelWidth - 16;
    }

    // 面板从按钮上方弹出
    double top = anchorPosition.dy - panelHeight - 8;

    // 如果面板会超出屏幕可见区域，显示在按钮下方
    final safeAreaTop = MediaQuery.of(context).padding.top;
    if (top < safeAreaTop + 16) {
      top = anchorPosition.dy + anchorSize.height + 8;
    }

    return Stack(
      children: [
        // 透明背景层，点击关闭
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        // 播放模式面板
        Positioned(
          left: left,
          top: top,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHigh,
            child: Container(
              width: panelWidth,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final mode in PlayMode.values)
                    InkWell(
                      onTap: () => onPlayModeChanged(mode),
                      child: Container(
                        width: double.infinity,
                        height: itemHeight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              getIcon(mode),
                              size: iconSize,
                              color:
                                  playMode == mode
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              getTooltip(mode),
                              style: TextStyle(
                                fontSize: fontSize,
                                color:
                                    playMode == mode
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                fontWeight:
                                    playMode == mode
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 睡眠定时弹出控制组件
class PopupSleepTimerControl extends StatefulWidget {
  final Duration? sleepTimerRemaining;
  final ValueChanged<Duration> onSetTimer;
  final VoidCallback onCancelTimer;

  const PopupSleepTimerControl({
    super.key,
    required this.sleepTimerRemaining,
    required this.onSetTimer,
    required this.onCancelTimer,
  });

  @override
  State<PopupSleepTimerControl> createState() => _PopupSleepTimerControlState();
}

class _PopupSleepTimerControlState extends State<PopupSleepTimerControl> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  bool get _hasTimer => widget.sleepTimerRemaining != null;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showSleepTimerPanel() {
    _removeOverlay();

    final RenderBox? renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder:
          (context) => _SleepTimerOverlayPanel(
            sleepTimerRemaining: widget.sleepTimerRemaining,
            onSetTimer: (duration) {
              widget.onSetTimer(duration);
              _removeOverlay();
            },
            onCancelTimer: () {
              widget.onCancelTimer();
              _removeOverlay();
            },
            onDismiss: _removeOverlay,
            anchorPosition: position,
            anchorSize: size,
            formatDuration: _formatDuration,
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      key: _buttonKey,
      onPressed: _showSleepTimerPanel,
      icon: Icon(
        _hasTimer ? Icons.alarm_on_rounded : Icons.alarm_rounded,
        size: 20,
        color: _hasTimer ? theme.colorScheme.primary : null,
      ),
      tooltip:
          _hasTimer
              ? '睡眠定时：${_formatDuration(widget.sleepTimerRemaining!)}'
              : '睡眠定时',
      visualDensity: VisualDensity.compact,
    );
  }
}

/// 睡眠定时弹出面板
class _SleepTimerOverlayPanel extends StatelessWidget {
  final Duration? sleepTimerRemaining;
  final ValueChanged<Duration> onSetTimer;
  final VoidCallback onCancelTimer;
  final VoidCallback onDismiss;
  final Offset anchorPosition;
  final Size anchorSize;
  final String Function(Duration) formatDuration;

  const _SleepTimerOverlayPanel({
    required this.sleepTimerRemaining,
    required this.onSetTimer,
    required this.onCancelTimer,
    required this.onDismiss,
    required this.anchorPosition,
    required this.anchorSize,
    required this.formatDuration,
  });

  static const _timerOptions = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(hours: 1),
    Duration(hours: 2),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final hasTimer = sleepTimerRemaining != null;

    // 响应式面板尺寸
    final itemHeight = context.responsive<double>(
      mobile: 44,
      tablet: 48,
      desktop: 48,
      tv: 56,
    );
    final panelWidth = context.responsive<double>(
      mobile: 140,
      tablet: 160,
      desktop: 160,
      tv: 200,
    );
    final fontSize = context.responsive<double>(
      mobile: 14,
      tablet: 14,
      desktop: 14,
      tv: 16,
    );

    // 精确计算面板高度
    // 每个选项高度 + padding (vertical: 8)
    double panelHeight = 16; // 上下 padding 各 8

    if (hasTimer) {
      // 剩余时间显示
      panelHeight += itemHeight;
      // 取消按钮
      panelHeight += itemHeight;
      // 分隔线（Divider 默认高度包含上下 margin）
      panelHeight += 16;
    }
    // 定时选项
    panelHeight += _timerOptions.length * itemHeight;

    // 计算面板位置（居中对齐按钮）
    double left = anchorPosition.dx + anchorSize.width / 2 - panelWidth / 2;
    // 确保不超出屏幕
    if (left < 16) left = 16;
    if (left + panelWidth > screenSize.width - 16) {
      left = screenSize.width - panelWidth - 16;
    }

    // 面板从按钮上方弹出
    double top = anchorPosition.dy - panelHeight - 8;

    // 移动端特殊处理：底部工具栏上方空间有限
    // 如果面板会超出屏幕可见区域，显示在按钮下方
    final safeAreaTop = MediaQuery.of(context).padding.top;
    if (top < safeAreaTop + 16) {
      top = anchorPosition.dy + anchorSize.height + 8;
    }

    return Stack(
      children: [
        // 透明背景层，点击关闭
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        // 睡眠定时面板
        Positioned(
          left: left,
          top: top,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHigh,
            child: Container(
              width: panelWidth,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 如果已设定定时器，显示剩余时间和取消选项
                  if (hasTimer) ...[
                    // 剩余时间显示
                    Container(
                      width: double.infinity,
                      height: itemHeight,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Center(
                        child: Text(
                          '剩余：${formatDuration(sleepTimerRemaining!)}',
                          style: TextStyle(
                            fontSize: fontSize,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    // 取消按钮
                    InkWell(
                      onTap: onCancelTimer,
                      child: Container(
                        width: double.infinity,
                        height: itemHeight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Center(
                          child: Text(
                            '取消定时',
                            style: TextStyle(
                              fontSize: fontSize,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 分隔线
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ],
                  // 定时选项
                  for (final duration in _timerOptions)
                    InkWell(
                      onTap: () => onSetTimer(duration),
                      child: Container(
                        width: double.infinity,
                        height: itemHeight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Center(
                          child: Text(
                            duration.inMinutes >= 60
                                ? '${duration.inHours} 小时'
                                : '${duration.inMinutes} 分钟',
                            style: TextStyle(
                              fontSize: fontSize,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
