import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volume_controller/volume_controller.dart';

/// 系统音量 Provider - 监听系统音量变化并提供读写能力
/// 在 Web 平台不可用，由 PlayerNotifier 内部降级处理
final systemVolumeProvider = StreamProvider<double>((ref) {
  if (kIsWeb) {
    // Web 平台不支持系统音量控制，返回一个不发射任何值的流
    return const Stream<double>.empty();
  }

  final controller = VolumeController();

  // 不显示系统音量 UI（由应用自己的 UI 显示）
  controller.showSystemUI = false;

  // 创建一个 StreamController 来合并初始值和后续变化
  final streamController = StreamController<double>();

  // 获取初始音量
  controller.getVolume().then((volume) {
    if (!streamController.isClosed) {
      streamController.add(volume);
    }
  });

  // 监听音量变化
  final subscription = controller.listener((volume) {
    if (!streamController.isClosed) {
      streamController.add(volume);
    }
  });

  ref.onDispose(() {
    subscription.cancel();
    streamController.close();
  });

  return streamController.stream;
});
