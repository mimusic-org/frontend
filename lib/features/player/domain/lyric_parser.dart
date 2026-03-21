/// 歌词行数据模型
class LyricLine {
  /// 歌词时间点
  final Duration time;

  /// 歌词文本
  final String text;

  const LyricLine({required this.time, required this.text});

  @override
  String toString() => 'LyricLine(time: $time, text: $text)';
}

/// LRC 歌词解析器
class LyricParser {
  /// 解析 LRC 格式歌词
  ///
  /// 支持标准 LRC 格式：[mm:ss.xx]歌词文本
  /// 支持多个时间标签对应同一行歌词：[00:01.00][00:02.00]歌词文本
  static List<LyricLine> parse(String lrcContent) {
    final List<LyricLine> lyrics = [];
    final lines = lrcContent.split('\n');

    // 匹配时间标签的正则表达式：[mm:ss.xx] 或 [mm:ss]
    final timeRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // 查找所有时间标签
      final matches = timeRegex.allMatches(trimmedLine).toList();
      if (matches.isEmpty) continue;

      // 提取歌词文本（去除所有时间标签后的内容）
      String text = trimmedLine;
      for (final match in matches.reversed) {
        text = text.replaceRange(match.start, match.end, '');
      }
      text = text.trim();

      // 跳过空歌词行（保留空行不影响功能，但可以选择跳过）
      // 为每个时间标签创建一个歌词行
      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millisecondsStr = match.group(3);

        // 处理毫秒：可能是 1-3 位数字
        int milliseconds = 0;
        if (millisecondsStr != null) {
          // 补齐到 3 位数字
          final padded = millisecondsStr.padRight(3, '0');
          milliseconds = int.parse(padded);
        }

        final time = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        lyrics.add(LyricLine(time: time, text: text));
      }
    }

    // 按时间排序
    lyrics.sort((a, b) => a.time.compareTo(b.time));

    return lyrics;
  }

  /// 根据当前播放位置查找应高亮的歌词行索引
  ///
  /// 返回当前时间点应该显示的歌词行索引
  /// 如果没有找到合适的歌词行，返回 -1
  static int findCurrentLine(List<LyricLine> lyrics, Duration position) {
    if (lyrics.isEmpty) return -1;

    // 如果当前位置在第一行歌词之前，返回 -1
    if (position < lyrics.first.time) return -1;

    // 二分查找最后一个时间 <= position 的歌词行
    int left = 0;
    int right = lyrics.length - 1;
    int result = 0;

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      if (lyrics[mid].time <= position) {
        result = mid;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    return result;
  }
}
