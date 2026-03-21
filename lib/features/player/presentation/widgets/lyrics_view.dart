import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/lyric_parser.dart';

/// 歌词显示组件
///
/// 支持自动滚动到当前歌词行，高亮显示当前行。
/// 用户手动滚动时会暂停自动滚动，几秒后自动恢复。
class LyricsView extends StatefulWidget {
  /// 歌词文本（LRC 格式）
  final String? lyricText;

  /// 当前播放位置
  final Duration currentPosition;

  const LyricsView({
    super.key,
    this.lyricText,
    required this.currentPosition,
  });

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  /// 滚动控制器
  final ScrollController _scrollController = ScrollController();

  /// 解析后的歌词列表
  List<LyricLine> _lyrics = [];

  /// 当前高亮的歌词行索引
  int _currentLineIndex = -1;

  /// 是否正在用户手动滚动
  bool _isUserScrolling = false;

  /// 恢复自动滚动的定时器
  Timer? _resumeTimer;

  /// 每行歌词的估算高度
  static const double _lineHeight = 48.0;

  /// 用户手动滚动后恢复自动滚动的延迟时间
  static const Duration _resumeDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _parseLyrics();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 歌词内容变化时重新解析
    if (widget.lyricText != oldWidget.lyricText) {
      _parseLyrics();
    }

    // 播放位置变化时更新高亮行并滚动
    if (widget.currentPosition != oldWidget.currentPosition) {
      _updateCurrentLine();
    }
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 解析歌词
  void _parseLyrics() {
    if (widget.lyricText == null || widget.lyricText!.isEmpty) {
      _lyrics = [];
      _currentLineIndex = -1;
      return;
    }

    _lyrics = LyricParser.parse(widget.lyricText!);
    _currentLineIndex = -1;
    _updateCurrentLine();
  }

  /// 更新当前歌词行
  void _updateCurrentLine() {
    final newIndex = LyricParser.findCurrentLine(_lyrics, widget.currentPosition);
    if (newIndex != _currentLineIndex) {
      setState(() {
        _currentLineIndex = newIndex;
      });

      // 如果不是用户手动滚动，自动滚动到当前行
      if (!_isUserScrolling && newIndex >= 0) {
        _scrollToLine(newIndex);
      }
    }
  }

  /// 滚动到指定歌词行
  void _scrollToLine(int index) {
    if (!_scrollController.hasClients) return;

    // 计算目标偏移量（将当前行滚动到视图中央）
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = (index * _lineHeight) - (viewportHeight / 2) + (_lineHeight / 2);
    final clampedOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// 监听滚动事件
  void _onScroll() {
    // 检测用户是否正在手动滚动
    if (_scrollController.position.isScrollingNotifier.value) {
      _onUserScrollStart();
    }
  }

  /// 用户开始手动滚动
  void _onUserScrollStart() {
    _isUserScrolling = true;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeDelay, _onResumeAutoScroll);
  }

  /// 恢复自动滚动
  void _onResumeAutoScroll() {
    _isUserScrolling = false;
    // 立即滚动到当前行
    if (_currentLineIndex >= 0) {
      _scrollToLine(_currentLineIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 无歌词时显示占位
    if (_lyrics.isEmpty) {
      return Center(
        child: Text(
          '暂无歌词',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          // 用户开始滚动
          if (notification.dragDetails != null) {
            _onUserScrollStart();
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 24),
        itemCount: _lyrics.length,
        itemBuilder: (context, index) {
          final lyric = _lyrics[index];
          final isCurrent = index == _currentLineIndex;

          return GestureDetector(
            onTap: () {
              // 点击歌词行时可以触发跳转（可选功能，暂不实现）
            },
            child: Container(
              height: _lineHeight,
              alignment: Alignment.center,
              child: Text(
                lyric.text.isEmpty ? '...' : lyric.text,
                style: TextStyle(
                  fontSize: isCurrent ? 18 : 15,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),
    );
  }
}
