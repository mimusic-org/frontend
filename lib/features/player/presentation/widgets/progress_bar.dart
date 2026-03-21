import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';

/// 播放进度条组件
class PlayerProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final bool mini; // true=迷你版（仅线条），false=完整版（含时间显示）
  final Color? activeColor;
  final Color? inactiveColor;

  const PlayerProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.mini = false,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  bool _isDragging = false;
  double _dragValue = 0;

  double get _progress {
    if (widget.duration.inMilliseconds <= 0) return 0;
    return (widget.position.inMilliseconds / widget.duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  String _formatDuration(Duration duration) {
    return Formatters.formatDuration(duration.inSeconds.toDouble());
  }

  void _onDragStart(double value) {
    setState(() {
      _isDragging = true;
      _dragValue = value;
    });
  }

  void _onDragUpdate(double value) {
    setState(() {
      _dragValue = value;
    });
  }

  void _onDragEnd() {
    final newPosition = Duration(
      milliseconds: (_dragValue * widget.duration.inMilliseconds).round(),
    );
    widget.onSeek(newPosition);
    setState(() {
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mini) {
      return _buildMiniProgressBar(context);
    }
    return _buildFullProgressBar(context);
  }

  /// 迷你进度条（仅线条）
  Widget _buildMiniProgressBar(BuildContext context) {
    final theme = Theme.of(context);
    return LinearProgressIndicator(
      value: _progress,
      backgroundColor:
          widget.inactiveColor ?? theme.colorScheme.surfaceContainerHighest,
      valueColor: AlwaysStoppedAnimation<Color>(
        widget.activeColor ?? theme.colorScheme.primary,
      ),
      minHeight: 2,
    );
  }

  /// 完整进度条（含时间显示）
  Widget _buildFullProgressBar(BuildContext context) {
    final theme = Theme.of(context);
    final currentValue = _isDragging ? _dragValue : _progress;

    // 计算显示的时间
    final displayPosition = _isDragging
        ? Duration(
            milliseconds:
                (_dragValue * widget.duration.inMilliseconds).round())
        : widget.position;

    return Row(
      children: [
        // 当前时间
        SizedBox(
          width: 45,
          child: Text(
            _formatDuration(displayPosition),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 8),
        // 进度条
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 6,
                pressedElevation: 4,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: widget.activeColor ?? theme.colorScheme.primary,
              inactiveTrackColor: widget.inactiveColor ??
                  theme.colorScheme.surfaceContainerHighest,
              thumbColor: widget.activeColor ?? theme.colorScheme.primary,
              overlayColor:
                  (widget.activeColor ?? theme.colorScheme.primary).withValues(alpha: 0.2),
            ),
            child: Slider(
              value: currentValue,
              onChangeStart: _onDragStart,
              onChanged: _onDragUpdate,
              onChangeEnd: (value) => _onDragEnd(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 总时长
        SizedBox(
          width: 45,
          child: Text(
            _formatDuration(widget.duration),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// 可点击的进度条（用于桌面端顶部）
class ClickableProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final double height;
  final Color? activeColor;
  final Color? inactiveColor;

  const ClickableProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.height = 4,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<ClickableProgressBar> createState() => _ClickableProgressBarState();
}

class _ClickableProgressBarState extends State<ClickableProgressBar> {
  bool _isHovering = false;

  double get _progress {
    if (widget.duration.inMilliseconds <= 0) return 0;
    return (widget.position.inMilliseconds / widget.duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  void _seekTo(Offset localPosition, double width) {
    final progress = (localPosition.dx / width).clamp(0.0, 1.0);
    final newPosition = Duration(
      milliseconds: (progress * widget.duration.inMilliseconds).round(),
    );
    widget.onSeek(newPosition);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTapDown: (details) {
          final box = context.findRenderObject() as RenderBox;
          _seekTo(details.localPosition, box.size.width);
        },
        onHorizontalDragUpdate: (details) {
          final box = context.findRenderObject() as RenderBox;
          _seekTo(details.localPosition, box.size.width);
        },
        child: Container(
          height: _isHovering ? widget.height + 2 : widget.height,
          decoration: BoxDecoration(
            color: widget.inactiveColor ??
                theme.colorScheme.surfaceContainerHighest,
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progress,
            child: Container(
              decoration: BoxDecoration(
                color: widget.activeColor ?? theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
