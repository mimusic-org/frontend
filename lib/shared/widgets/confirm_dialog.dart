import 'package:flutter/material.dart';

/// 确认对话框组件
class ConfirmDialog extends StatelessWidget {
  /// 对话框标题
  final String title;

  /// 对话框内容（可选）
  final String? content;

  /// 确认按钮文字
  final String confirmText;

  /// 取消按钮文字
  final String cancelText;

  /// 是否为破坏性操作（确认按钮显示为红色）
  final bool isDestructive;

  const ConfirmDialog({
    super.key,
    required this.title,
    this.content,
    this.confirmText = '确认',
    this.cancelText = '取消',
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(title),
      content: content != null ? Text(content!) : null,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: isDestructive
              ? TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                )
              : null,
          child: Text(confirmText),
        ),
      ],
    );
  }

  /// 显示确认对话框
  /// 返回 true 表示用户确认，false 表示取消
  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? content,
    String confirmText = '确认',
    String cancelText = '取消',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }
}
