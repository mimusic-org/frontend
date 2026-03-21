import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

/// 主题选择器组件
class ThemeSelector extends ConsumerWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(
            value: ThemeMode.light,
            label: Text('浅色'),
            icon: Icon(Icons.light_mode),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            label: Text('深色'),
            icon: Icon(Icons.dark_mode),
          ),
          ButtonSegment(
            value: ThemeMode.system,
            label: Text('系统'),
            icon: Icon(Icons.phone_android),
          ),
        ],
        selected: {themeMode},
        onSelectionChanged: (Set<ThemeMode> selected) {
          if (selected.isNotEmpty) {
            ref.read(themeModeProvider.notifier).setThemeMode(selected.first);
          }
        },
        showSelectedIcon: false,
      ),
    );
  }
}
