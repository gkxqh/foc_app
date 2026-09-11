import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

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
    if (phone.length != 11) {
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
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('第一步：输入新手机号', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          enabled: !_codeSent,
                          decoration: const InputDecoration(
                            labelText: '新手机号',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _isLoading || (_codeSent && _countdown > 0) ? null : _sendCode,
                        child: Text(
                          _codeSent ? (_countdown > 0 ? '${_countdown}s' : '重新发送') : '发送验证码',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('第二步：输入收到的验证码', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                    enabled: _codeSent,
                    decoration: const InputDecoration(
                      labelText: '验证码',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading || !_codeSent ? null : _submit,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('确认换绑'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              '换绑成功后，维修进度短信将发送至新手机号；原手机号将无法再登录本应用。',
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
