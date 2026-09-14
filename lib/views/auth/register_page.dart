import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../common/app_snackbar.dart';
import '../common/page_insets.dart';
import '../common/responsive_center.dart';
import 'complete_profile_page.dart';
import 'privacy_consent.dart';

/// 新用户手机号注册页（2026-09-14 新增）：手机号 + 短信验证码直接注册，
/// 无需前往微信小程序。注册即登录（服务端 phoneregister 签发 30 天 token），
/// 之后引导完善昵称/校区（CompleteProfilePage，可跳过）。
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _sendCode() async {
    final phone = _phoneController.text.trim();
    // 长度 + 纯数字双重校验，防止含非数字字符的输入透传到服务端
    if (!RegExp(r'^\d{11}$').hasMatch(phone)) {
      showAppSnackBar(context, '请输入正确的11位手机号码', type: SnackBarType.error);
      return;
    }

    final auth = context.read<AuthProvider>();
    // 已注册手机号服务端直接拒绝（already_registered），此处只处理发码成功
    final res = await auth.sendRegisterSmsCode(phone);

    if (!mounted) return;
    if (res.success) {
      showAppSnackBar(context, '验证码已发送，请注意查收', type: SnackBarType.success);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.message ?? '验证码发送失败')));
    }
  }

  void _register() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();

    if (phone.isEmpty) {
      showAppSnackBar(context, '请填写手机号码', type: SnackBarType.error);
      return;
    }
    if (code.isEmpty) {
      showAppSnackBar(context, '请输入短信验证码', type: SnackBarType.error);
      return;
    }

    if (!await ensurePrivacyAgreed(context)) return;
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final res = await auth.registerAndLogin(phone, code);
    if (!mounted) return;

    if (res.success) {
      showAppSnackBar(context, '注册成功！', type: SnackBarType.success);
      // 完善资料后一路退回首页；跳过也在该页内完成
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CompleteProfilePage()),
      );
    } else if (res.raw?['status'] == 'already_registered') {
      showAppSnackBar(context, '该手机号已注册，请返回直接登录', type: SnackBarType.warning);
    } else {
      showAppSnackBar(context, res.message ?? '验证码错误或注册失败', type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('新用户注册')),
      body: ResponsiveCenter(
        child: SingleChildScrollView(
          padding: pageListPadding(context, horizontal: 24, top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 72,
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text(
                  '创建云上飞扬账号',
                  style: AppText.titleApp.copyWith(color: AppTheme.primaryBlue),
                ),
              ),
              Center(
                child: Text(
                  '注册后即可报修，账号与微信小程序互通',
                  style: AppText.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                decoration: InputDecoration(
                  labelText: '手机号码',
                  hintText: '请输入手机号',
                  prefixIcon: const Icon(Icons.phone_android_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '短信验证码',
                        hintText: '',
                        prefixIcon: const Icon(Icons.lock_clock_outlined),
                        // 短信验证码常需跨应用取：一键粘贴并校验 4-6 位数字
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.content_paste_rounded,
                            size: 18,
                          ),
                          tooltip: '粘贴验证码',
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final data = await Clipboard.getData('text/plain');
                            final code = data?.text?.trim() ?? '';
                            if (RegExp(r'^\d{4,6}$').hasMatch(code)) {
                              _codeController.text = code;
                            } else {
                              showAppSnackBarOn(
                                messenger,
                                '剪贴板中没有可用的验证码',
                                type: SnackBarType.warning,
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // 不固定 56 高：验证码输入框随文字缩放变高时按钮同步对齐
                  OutlinedButton(
                    onPressed: auth.isCountingDown ? null : _sendCode,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    child: Text(
                      auth.isCountingDown ? '${auth.countdown}s' : '发送',
                      style: AppText.captionSm,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton(
                onPressed: auth.isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: auth.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('注册并登录', style: AppText.bodyLg),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '已有账号？',
                    style: AppText.captionSm.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('返回登录'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
