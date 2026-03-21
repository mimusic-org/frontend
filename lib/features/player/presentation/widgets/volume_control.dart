import 'package:flutter/material.dart';

/// 音量控制组件
class VolumeControl extends StatefulWidget {
  final double volume; // 0-100
  final ValueChanged<double> onVolumeChanged;
  final bool showSlider; // 桌面端显示滑块，移动端可只显示图标
  final double sliderWidth;

  const VolumeControl({
    super.key,
    required this.volume,
    required this.onVolumeChanged,
    this.showSlider = true,
    this.sliderWidth = 100,
  });

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  double? _previousVolume;

  /// 获取音量图标
  IconData get _volumeIcon {
    if (widget.volume <= 0) {
      return Icons.volume_off_rounded;
    } else if (widget.volume < 30) {
      return Icons.volume_mute_rounded;
    } else if (widget.volume < 70) {
      return Icons.volume_down_rounded;
    } else {
      return Icons.volume_up_rounded;
    }
  }

  /// 切换静音/恢复
  void _toggleMute() {
    if (widget.volume > 0) {
      // 静音
      _previousVolume = widget.volume;
      widget.onVolumeChanged(0);
    } else {
      // 恢复
      widget.onVolumeChanged(_previousVolume ?? 50);
      _previousVolume = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!widget.showSlider) {
      return IconButton(
        onPressed: _toggleMute,
        icon: Icon(_volumeIcon),
        tooltip: widget.volume > 0 ? '静音' : '恢复音量',
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _toggleMute,
          icon: Icon(_volumeIcon),
          tooltip: widget.volume > 0 ? '静音' : '恢复音量',
          style: IconButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurfaceVariant,
          ),
          visualDensity: VisualDensity.compact,
        ),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.sliderWidth),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: theme.colorScheme.primary,
                inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
                thumbColor: theme.colorScheme.primary,
                overlayColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: widget.volume,
                min: 0,
                max: 100,
                onChanged: widget.onVolumeChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 弹出式音量控制（用于移动端，使用内联下拉面板）
class PopupVolumeControl extends StatefulWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;

  const PopupVolumeControl({
    super.key,
    required this.volume,
    required this.onVolumeChanged,
  });

  @override
  State<PopupVolumeControl> createState() => _PopupVolumeControlState();
}

class _PopupVolumeControlState extends State<PopupVolumeControl> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  double? _previousVolume;

  IconData get _volumeIcon {
    if (widget.volume <= 0) {
      return Icons.volume_off_rounded;
    } else if (widget.volume < 30) {
      return Icons.volume_mute_rounded;
    } else if (widget.volume < 70) {
      return Icons.volume_down_rounded;
    } else {
      return Icons.volume_up_rounded;
    }
  }

  /// 切换静音/恢复
  void _toggleMute() {
    if (widget.volume > 0) {
      _previousVolume = widget.volume;
      widget.onVolumeChanged(0);
    } else {
      widget.onVolumeChanged(_previousVolume ?? 50);
      _previousVolume = null;
    }
  }

  void _showVolumePanel() {
    _removeOverlay();

    final RenderBox? renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => _VolumeOverlayPanel(
        volume: widget.volume,
        onVolumeChanged: (value) {
          widget.onVolumeChanged(value);
          // 强制重建 overlay 以更新音量值
          _overlayEntry?.markNeedsBuild();
        },
        onToggleMute: _toggleMute,
        onDismiss: _removeOverlay,
        anchorPosition: position,
        anchorSize: size,
        volumeIcon: _volumeIcon,
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
    return IconButton(
      key: _buttonKey,
      onPressed: _showVolumePanel,
      icon: Icon(_volumeIcon),
      tooltip: '音量',
    );
  }
}

/// 音量控制弹出面板
class _VolumeOverlayPanel extends StatefulWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onToggleMute;
  final VoidCallback onDismiss;
  final Offset anchorPosition;
  final Size anchorSize;
  final IconData volumeIcon;

  const _VolumeOverlayPanel({
    required this.volume,
    required this.onVolumeChanged,
    required this.onToggleMute,
    required this.onDismiss,
    required this.anchorPosition,
    required this.anchorSize,
    required this.volumeIcon,
  });

  @override
  State<_VolumeOverlayPanel> createState() => _VolumeOverlayPanelState();
}

class _VolumeOverlayPanelState extends State<_VolumeOverlayPanel> {
  late double _currentVolume;

  @override
  void initState() {
    super.initState();
    _currentVolume = widget.volume;
  }

  @override
  void didUpdateWidget(_VolumeOverlayPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.volume != widget.volume) {
      _currentVolume = widget.volume;
    }
  }

  IconData get _volumeIcon {
    if (_currentVolume <= 0) {
      return Icons.volume_off_rounded;
    } else if (_currentVolume < 30) {
      return Icons.volume_mute_rounded;
    } else if (_currentVolume < 70) {
      return Icons.volume_down_rounded;
    } else {
      return Icons.volume_up_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    // 计算面板位置，在按钮上方显示
    const panelWidth = 200.0;
    const panelHeight = 80.0;

    double left = widget.anchorPosition.dx +
        widget.anchorSize.width / 2 -
        panelWidth / 2;
    // 确保不超出屏幕
    if (left < 16) left = 16;
    if (left + panelWidth > screenSize.width - 16) {
      left = screenSize.width - panelWidth - 16;
    }

    double top = widget.anchorPosition.dy - panelHeight - 8;
    // 如果上方空间不足，显示在下方
    if (top < 16) {
      top = widget.anchorPosition.dy + widget.anchorSize.height + 8;
    }

    return Stack(
      children: [
        // 透明背景层，点击关闭
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        // 音量控制面板
        Positioned(
          left: left,
          top: top,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHigh,
            child: Container(
              width: panelWidth,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // 静音按钮
                  IconButton(
                    onPressed: () {
                      widget.onToggleMute();
                      setState(() {
                        _currentVolume = _currentVolume > 0 ? 0 : 50;
                      });
                    },
                    icon: Icon(
                      _volumeIcon,
                      color: theme.colorScheme.onSurface,
                    ),
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                  ),
                  // 音量滑块
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: theme.colorScheme.primary,
                        inactiveTrackColor:
                            theme.colorScheme.surfaceContainerHighest,
                        thumbColor: theme.colorScheme.primary,
                        overlayColor:
                            theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _currentVolume,
                        min: 0,
                        max: 100,
                        onChanged: (value) {
                          setState(() => _currentVolume = value);
                          widget.onVolumeChanged(value);
                        },
                      ),
                    ),
                  ),
                  // 音量百分比
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${_currentVolume.round()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.end,
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
