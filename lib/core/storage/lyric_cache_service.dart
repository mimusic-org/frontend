import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 歌词本地缓存服务
///
/// 将网络加载的歌词文本缓存到本地文件系统，避免重复请求。
/// 缓存目录：{appDocDir}/lyric_cache/
/// 文件名：URL 的 SHA1 hash + .lrc
///
/// Web 平台不支持文件缓存，降级为纯内存缓存。
class LyricCacheService {
  static final LyricCacheService _instance = LyricCacheService._();
  factory LyricCacheService() => _instance;
  LyricCacheService._();

  /// 内存缓存（所有平台通用，作为一级缓存）
  final Map<String, String> _memoryCache = {};

  /// 缓存目录（延迟初始化，仅非 Web 平台使用）
  Directory? _cacheDir;

  /// 是否已初始化缓存目录
  bool _initialized = false;

  /// 初始化缓存目录
  Future<void> _ensureInitialized() async {
    if (_initialized || kIsWeb) return;
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDocDir.path}/lyric_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[LyricCacheService] 初始化缓存目录失败: $e');
    }
  }

  /// 根据 URL 生成缓存文件名（使用简单 hash，避免额外依赖）
  String _hashUrl(String url) {
    // 使用 Dart 内置的 hashCode 组合生成足够唯一的文件名
    final bytes = utf8.encode(url);
    int hash1 = 0x811c9dc5; // FNV offset basis
    for (final byte in bytes) {
      hash1 ^= byte;
      hash1 = (hash1 * 0x01000193) & 0xFFFFFFFF; // FNV prime
    }
    int hash2 = 0;
    for (final byte in bytes) {
      hash2 = (hash2 * 31 + byte) & 0xFFFFFFFF;
    }
    return '${hash1.toRadixString(16).padLeft(8, '0')}${hash2.toRadixString(16).padLeft(8, '0')}';
  }

  /// 获取缓存文件路径
  File? _getCacheFile(String url) {
    if (_cacheDir == null) return null;
    final hash = _hashUrl(url);
    return File('${_cacheDir!.path}/$hash.lrc');
  }

  /// 获取缓存的歌词（先查内存，再查文件）
  Future<String?> get(String url) async {
    // 1. 查内存缓存
    final memCached = _memoryCache[url];
    if (memCached != null) return memCached;

    // 2. Web 平台无文件缓存
    if (kIsWeb) return null;

    // 3. 查文件缓存
    await _ensureInitialized();
    final file = _getCacheFile(url);
    if (file == null) return null;

    try {
      if (await file.exists()) {
        final content = await file.readAsString();
        // 写入内存缓存
        _memoryCache[url] = content;
        return content;
      }
    } catch (e) {
      debugPrint('[LyricCacheService] 读取缓存文件失败: $e');
    }
    return null;
  }

  /// 缓存歌词（同时写入内存和文件）
  Future<void> put(String url, String lyricText) async {
    // 写入内存缓存
    _memoryCache[url] = lyricText;

    // Web 平台不写文件
    if (kIsWeb) return;

    // 写入文件缓存
    await _ensureInitialized();
    final file = _getCacheFile(url);
    if (file == null) return;

    try {
      await file.writeAsString(lyricText);
    } catch (e) {
      debugPrint('[LyricCacheService] 写入缓存文件失败: $e');
    }
  }

  /// 清理全部歌词缓存
  Future<void> clear() async {
    _memoryCache.clear();

    if (kIsWeb) return;

    await _ensureInitialized();
    if (_cacheDir == null) return;

    try {
      if (await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }
    } catch (e) {
      debugPrint('[LyricCacheService] 清理缓存失败: $e');
    }
  }

  /// 获取歌词缓存大小（字节）
  Future<int> getCacheSize() async {
    if (kIsWeb) return 0;

    await _ensureInitialized();
    if (_cacheDir == null) return 0;

    int totalSize = 0;
    try {
      if (await _cacheDir!.exists()) {
        await for (final entity in _cacheDir!.list()) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      debugPrint('[LyricCacheService] 获取缓存大小失败: $e');
    }
    return totalSize;
  }
}
