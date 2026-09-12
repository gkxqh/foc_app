import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// 统一的确认弹窗：返回 true 表示用户确认。
/// danger 为 true 时确认按钮呈错误红色，并在弹出时强振动提示破坏性操作。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmText = '确定',
  String cancelText = '取消',
  bool danger = false,
}) async {
  if (danger) {
    HapticFeedback.heavyImpact();
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: danger
              ? ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed)
              : null,
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return ok == true;
}
