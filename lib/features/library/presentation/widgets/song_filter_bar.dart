import 'package:flutter/material.dart';

import '../../../../config/constants.dart';

/// 歌曲类型筛选栏
class SongFilterBar extends StatelessWidget {
  final String? currentType;
  final ValueChanged<String?> onTypeChanged;

  const SongFilterBar({
    super.key,
    this.currentType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _FilterChip(
            label: '全部',
            isSelected: currentType == null,
            onTap: () => onTypeChanged(null),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '本地',
            isSelected: currentType == AppConstants.songTypeLocal,
            onTap: () => onTypeChanged(AppConstants.songTypeLocal),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '网络',
            isSelected: currentType == AppConstants.songTypeRemote,
            onTap: () => onTypeChanged(AppConstants.songTypeRemote),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '电台',
            isSelected: currentType == AppConstants.songTypeRadio,
            onTap: () => onTypeChanged(AppConstants.songTypeRadio),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurface,
      ),
    );
  }
}
