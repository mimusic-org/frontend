import 'package:flutter/material.dart';

/// 自动滚动文本组件
/// 当文本溢出时自动水平滚动显示完整内容
class ScrollingText extends StatefulWidget {
  /// 要显示的文本
  final String text;

  /// 文本样式
  final TextStyle? style;

  /// 滚动速度（像素/秒）
  final double velocity;

  /// 滚动前后的暂停时间
  final Duration pauseDuration;

  const ScrollingText({
    super.key,
    required this.text,
    this.style,
    this.velocity = 30.0,
    this.pauseDuration = const Duration(seconds: 2),
  });

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _isOverflowing = false;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverflow();
    });
  }

  @override
  void didUpdateWidget(ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _isScrolling = false;
      _scrollController.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkOverflow();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkOverflow() {
    if (!mounted) return;
    
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final overflow = maxScrollExtent > 0;
    
    if (overflow != _isOverflowing) {
      setState(() {
        _isOverflowing = overflow;
      });
    }
    
    if (_isOverflowing && !_isScrolling) {
      _startScrolling();
    }
  }

  Future<void> _startScrolling() async {
    if (!mounted || !_isOverflowing) return;
    _isScrolling = true;

    while (mounted && _isOverflowing && _isScrolling) {
      // 暂停在开头
      await Future.delayed(widget.pauseDuration);
      if (!mounted || !_isScrolling) return;

      // 计算滚动时长
      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      final duration = Duration(
        milliseconds: (maxScrollExtent / widget.velocity * 1000).round(),
      );

      // 滚动到末尾
      await _scrollController.animateTo(
        maxScrollExtent,
        duration: duration,
        curve: Curves.linear,
      );
      if (!mounted || !_isScrolling) return;

      // 暂停在末尾
      await Future.delayed(widget.pauseDuration);
      if (!mounted || !_isScrolling) return;

      // 滚动回开头
      await _scrollController.animateTo(
        0,
        duration: duration,
        curve: Curves.linear,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            softWrap: false,
          ),
        );
      },
    );
  }
}
