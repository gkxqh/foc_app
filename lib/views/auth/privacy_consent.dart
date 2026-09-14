import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../common/app_snackbar.dart';

const String kPrivacyText = '''
1. 本应用会收集您的手机号、邮箱地址和昵称。
　- 手机号用于给您发送维修进度的短信通知；
　- 邮箱地址用于接收维修进度的邮件通知；
　- 您的昵称和头像将会显示在工单中，提供给技术员。
2. 本应用不会在未经用户同意的情况下，存储或公开用户的任何隐私信息。
3. 本应用不会向用户发送任何广告、推销或与维修工单无关的信息。
4. 本应用不会向任何无关人员（包括其他用户和技术员）和第三方机构提供您的任何信息。
5. 您的个人信息会在您主动注销账号或者撤回同意本隐私协议时被永久删除。
6. 您不同意本隐私条例仅仅限制您使用报修功能，但不会影响您使用其他功能，例如报名活动等。您也可以选择线下维修、参与校区大型维修等其他方式。
''';

/// 首次登录/注册前展示个人信息收集与使用声明（合规要求，文案与小程序注册页一致）。
/// 同意一次后持久化，后续不再弹出；登录页与注册页共用。
Future<bool> ensurePrivacyAgreed(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('privacy_agreed') == true) return true;
  if (!context.mounted) return false;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('隐私保护声明'),
      content: SingleChildScrollView(
        child: Text(kPrivacyText, style: AppText.caption.copyWith(height: 1.6)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('不同意')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('同意并继续'),
        ),
      ],
    ),
  );

  if (ok == true) {
    await prefs.setBool('privacy_agreed', true);
    return true;
  }
  if (!context.mounted) return false;
  showAppSnackBar(context, '需同意隐私声明后才能登录使用报修功能', type: SnackBarType.error);
  return false;
}
