import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../models/saved_account.dart';
import '../../providers/auth_provider.dart';
import '../common/confirm_dialog.dart';

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
  bool _rememberLogin = true; // 记住此设备：登录成功后保存账号到本机列表
  List<SavedAccount> _savedAccounts = [];
  String? _switchingPhone; // 正在切换的账号（显示 loading）

  @override
  void initState() {
    super.initState();
    // 读取用户的记住登录偏好（默认开启）与本机已保存账号
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(
          () => _rememberLogin = prefs.getBool('remember_enabled') ?? true,
        );
      }
    });
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    final list = await context.read<AuthProvider>().loadSavedAccounts();
    if (mounted) setState(() => _savedAccounts = list);
  }

  // 点击已保存账号：静默验证 token 直接进入
  Future<void> _switchToAccount(SavedAccount account) async {
    if (_switchingPhone != null) return;
    setState(() => _switchingPhone = account.phone);

    final auth = context.read<AuthProvider>();
    final err = await auth.switchToSavedAccount(account);

    if (!mounted) return;
    setState(() => _switchingPhone = null);

    if (err == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      await _loadSavedAccounts(); // 过期账号已被移除，刷新列表
    }
  }

  Future<void> _removeAccount(SavedAccount account) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除保存的账号',
      content: '删除后（${account.maskedPhone}）再次登录需要重新验证码，确认删除？',
      confirmText: '删除',
      danger: true,
    );
    if (ok != true || !mounted) return;
    await context.read<AuthProvider>().removeSavedAccount(account.phone);
    await _loadSavedAccounts();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 11) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入正确的11位手机号码')));
      return;
    }

    final auth = context.read<AuthProvider>();
    final res = await auth.sendSmsCode(phone);

    if (!mounted) return;

    if (res.success) {
      // phonesend 对未注册/待迁移用户直接返回 success:false 与中文提示，
      // 这里只处理发码成功；失败分支统一展示服务端 message
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('验证码已发送，请注意查收')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.message ?? '验证码发送失败')));
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
          child: Text(
            _privacyText,
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('不同意'),
          ),
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
    if (!mounted) return false;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('需同意隐私声明后才能登录使用报修功能')));
    return false;
  }

  void _login() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写手机号码')));
      return;
    }
    if (code.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入短信验证码')));
      return;
    }

    if (!await _ensurePrivacyAgreed()) return;
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyAndLogin(phone, code);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('登录成功！')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('验证码错误或登录失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('手机验证码登录')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 88,
                  height: 88,
                  fit: BoxFit.contain,
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
            Center(
              child: Text(
                '四川大学飞扬俱乐部设备报修一体化平台',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 28),
            // 已保存账号（QQ 式快速切换）：点击直接进入，可单独删除
            if (_savedAccounts.isNotEmpty) ...[
              ..._savedAccounts.map((account) {
                final isSwitching = _switchingPhone == account.phone;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: isSwitching ? null : () => _switchToAccount(account),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryBlue.withValues(
                        alpha: 0.12,
                      ),
                      backgroundImage: account.avatarUrl.isNotEmpty
                          ? NetworkImage(account.avatarUrl)
                          : null,
                      child: account.avatarUrl.isNotEmpty
                          ? null
                          : Text(
                              account.nickname.isNotEmpty
                                  ? account.nickname.characters.first
                                  : account.maskedPhone.substring(0, 1),
                              style: const TextStyle(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    title: Text(
                      account.nickname.isNotEmpty
                          ? account.nickname
                          : account.maskedPhone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        Text(
                          account.maskedPhone,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        if (account.role == 'technician') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '技术员',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: _switchingPhone != null
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            tooltip: '删除此账号',
                            onPressed: () => _removeAccount(account),
                          ),
                  ),
                );
              }),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '或使用其他手机号登录',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: '手机号码',
                hintText: '请输入手机号',
                prefixIcon: const Icon(Icons.phone_android_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                      hintText: '',
                      prefixIcon: const Icon(Icons.lock_clock_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: auth.isCountingDown ? null : _sendCode,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      auth.isCountingDown ? '${auth.countdown}s' : '发送',
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                  : const Text('验证码登录', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
            // 「记住登录」：开启时备份 30 天 token，退出登录后重开 App 免验证码
            CheckboxListTile(
              value: _rememberLogin,
              onChanged: (v) async {
                setState(() => _rememberLogin = v ?? true);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('remember_enabled', _rememberLogin);
                if (!_rememberLogin) {
                  await prefs.remove('remembered_token');
                }
              },
              title: const Text('记住此设备', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                '30 天内在本机重新打开无需验证码',
                style: TextStyle(fontSize: 12),
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 12),
            Text(
              '未注册用户请先前往微信小程序「云上飞扬」完成注册',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
