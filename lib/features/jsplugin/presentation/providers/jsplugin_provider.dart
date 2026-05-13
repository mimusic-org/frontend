import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/jsplugin_api.dart';

// ============================================================================
// JS Plugin API Provider
// ============================================================================

/// JSPluginApi Provider
final jsPluginApiProvider = Provider<JSPluginApi>((ref) {
  final dio = ref.watch(dioProvider);
  return JSPluginApi(dio: dio);
});

// ============================================================================
// JS Plugin Data Providers
// ============================================================================

/// 获取 JS 插件列表
final jsPluginsProvider = FutureProvider<List<JSPlugin>>((ref) async {
  final api = ref.watch(jsPluginApiProvider);
  return api.getPlugins();
});
