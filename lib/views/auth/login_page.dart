import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

const String _privacyText = '''
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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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
    if (phone.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入正确的11位手机号码')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final res = await auth.sendSmsCode(phone);

    if (!mounted) return;

    if (res.success) {
      // phonesend 对未注册/待迁移用户直接返回 success:false 与中文提示，
      // 这里只处理发码成功；失败分支统一展示服务端 message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('验证码已发送，请注意查收')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? '验证码发送失败')),
      );
    }
  }

  // 首次登录前展示个人信息收集与使用声明（合规要求，文案与小程序注册页一致）
  Future<bool> _ensurePrivacyAgreed() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('privacy_agreed') == true) return true;
    if (!mounted) return false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('隐私保护声明'),
        content: SingleChildScrollView(
          child: Text(_privacyText, style: const TextStyle(fontSize: 13, height: 1.6)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('不同意')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('同意并继续')),
        ],
      ),
    );

    if (ok == true) {
      await prefs.setBool('privacy_agreed', true);
      return true;
    }
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('需同意隐私声明后才能登录使用报修功能')),
    );
    return false;
  }

  void _login() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写手机号码')),
      );
      return;
    }
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入短信验证码')),
      );
      return;
    }

    if (!await _ensurePrivacyAgreed()) return;
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyAndLogin(phone, code);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录成功！')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('验证码错误或登录失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('登录 / 注册')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
                  size: 44,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                '云上飞扬',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
            const Center(
              child: Text(
                '四川大学飞扬俱乐部设备报修一体化平台',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: '手机号码',
                hintText: '请输入手机号',
                prefixIcon: const Icon(Icons.phone_android_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '短信验证码',
                      hintText: '请输入收到的6位验证码',
                      prefixIcon: const Icon(Icons.lock_clock_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: auth.isCountingDown ? null : _sendCode,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      auth.isCountingDown ? '${auth.countdown}s' : '发送真实短信',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: auth.isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: auth.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      '验证码登录',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 20),
            const Text(
              '首次使用请先在微信小程序「云上飞扬」注册并绑定手机号',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
