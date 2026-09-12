import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum SnackBarType { success, error, warning, info }

/// 统一结果反馈 SnackBar：按类型带语义色图标，成功/失败一眼可辨。
/// 校验提示类轻文案可继续使用默认 SnackBar，结果类一律走这里。
void showAppSnackBar(
  BuildContext context,
  String message, {
  SnackBarType type = SnackBarType.info,
}) {
  showAppSnackBarOn(ScaffoldMessenger.of(context), message, type: type);
}

/// async 回调中无法安全持有 BuildContext 时的入口：调用方在 await 前先
/// 取好 ScaffoldMessengerState 再传入。
void showAppSnackBarOn(
  ScaffoldMessengerState messenger,
  String message, {
  SnackBarType type = SnackBarType.info,
}) {
  final (IconData icon, Color color) = switch (type) {
    SnackBarType.success => (Icons.check_circle_rounded, AppTheme.accentColor),
    SnackBarType.error => (Icons.error_rounded, AppTheme.errorRed),
    SnackBarType.warning => (
      Icons.warning_amber_rounded,
      AppTheme.warningOrange,
    ),
    SnackBarType.info => (Icons.info_rounded, AppTheme.primaryBlue),
  };

  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
