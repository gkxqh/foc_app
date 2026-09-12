import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../common/page_insets.dart';

/// 换绑手机号：向新手机号发送验证码（newphone），回填验证码完成换绑
/// （服务端 phonechange_verify 只校验 vcode，新号码已在第一步绑定待验证状态）
class NewPhonePage extends StatefulWidget {
  const NewPhonePage({super.key});

  @override
  State<NewPhonePage> createState() => _NewPhonePageState();
}

class _NewPhonePageState extends State<NewPhonePage> {
  final AuthService _authService = AuthService();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  int _countdown = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    // 长度 + 纯数字双重校验，防止含非数字字符的输入透传到服务端
    if (!RegExp(r'^\d{11}$').hasMatch(phone)) {
      _toast('请输入正确的11位新手机号');
      return;
    }

    setState(() => _isLoading = true);
    final res = await _authService.newPhone(phone);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      setState(() {
        _codeSent = true;
        _countdown = 60;
      });
      _tick();
      _toast('验证码已发送至新手机号');
    } else {
      _toast(res.message ?? '发送失败，请稍后重试');
    }
  }

  void _tick() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _toast('请输入6位验证码');
      return;
    }

    setState(() => _isLoading = true);
    final ok = await _authService.verifyNewPhone(code);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      await context.read<AuthProvider>().refreshUserInfo();
      if (!mounted) return;
      _toast('手机号换绑成功');
      Navigator.pop(context);
    } else {
      _toast('验证码错误或已过期');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('更换手机号')),
      body: ListView(
        padding: pageListPadding(context),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('第一步：输入新手机号', style: AppText.titleSm),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          enabled: !_codeSent,
                          decoration: const InputDecoration(labelText: '新手机号'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      OutlinedButton(
                        onPressed: _isLoading || (_codeSent && _countdown > 0)
                            ? null
                            : _sendCode,
                        child: Text(
                          _codeSent
                              ? (_countdown > 0 ? '${_countdown}s' : '重新发送')
                              : '发送验证码',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('第二步：输入收到的验证码', style: AppText.titleSm),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    enabled: _codeSent,
                    decoration: const InputDecoration(labelText: '验证码'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading || !_codeSent ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('确认换绑'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              '换绑成功后，维修进度短信将发送至新手机号；原手机号将无法再登录本应用。',
              style: AppText.captionSm.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
