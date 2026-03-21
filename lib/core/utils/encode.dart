import 'dart:convert';
import 'dart:typed_data';

/// Base62 字符集
const String _base62Chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

/// 将字符串编码为 Base62
/// @param str 原始字符串
/// @returns Base62 编码后的字符串
String encodeBase62(String str) {
  if (str.isEmpty) return _base62Chars[0];

  // 将字符串转为 UTF-8 字节数组
  final Uint8List bytes = utf8.encode(str);

  // 转为大整数
  BigInt num = BigInt.zero;
  for (final byte in bytes) {
    num = num * BigInt.from(256) + BigInt.from(byte);
  }

  // 转为 Base62
  if (num == BigInt.zero) return _base62Chars[0];

  String result = '';
  while (num > BigInt.zero) {
    result = _base62Chars[(num % BigInt.from(62)).toInt()] + result;
    num = num ~/ BigInt.from(62);
  }
  return result;
}

/// 获取不带扩展名的路径
String getPathWithoutExtension(String filePath) {
  final int lastDotIndex = filePath.lastIndexOf('.');
  final int lastSlashIndex = filePath.lastIndexOf('/').compareTo(filePath.lastIndexOf('\\')) > 0
      ? filePath.lastIndexOf('/')
      : filePath.lastIndexOf('\\');
  // 确保点号在最后一个路径分隔符之后（是扩展名而非目录名中的点）
  if (lastDotIndex > lastSlashIndex && lastDotIndex > 0) {
    return filePath.substring(0, lastDotIndex);
  }
  return filePath;
}

/// 获取文件扩展名（包含点号）
String getExtension(String filePath) {
  final int lastDotIndex = filePath.lastIndexOf('.');
  final int lastSlashIndex = filePath.lastIndexOf('/').compareTo(filePath.lastIndexOf('\\')) > 0
      ? filePath.lastIndexOf('/')
      : filePath.lastIndexOf('\\');
  if (lastDotIndex > lastSlashIndex && lastDotIndex > 0) {
    return filePath.substring(lastDotIndex);
  }
  return '';
}
