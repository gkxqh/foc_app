import 'package:flutter/material.dart';

/// 统一的确认弹窗：返回 true 表示用户确认。
/// danger 为 true 时确认按钮呈红色（用于取消/强制关闭等破坏性操作）。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmText = '确定',
  String cancelText = '取消',
  bool danger = false,
}) async {
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
          style: danger ? ElevatedButton.styleFrom(backgroundColor: Colors.red) : null,
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return ok == true;
}
