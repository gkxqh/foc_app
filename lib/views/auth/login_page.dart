import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../common/responsive_center.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../models/saved_account.dart';
import '../../providers/auth_provider.dart';
import '../common/app_snackbar.dart';
import '../common/confirm_dialog.dart';
import '../common/page_insets.dart';
import 'privacy_consent.dart';
import 'register_page.dart';

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
    // 长度 + 纯数字双重校验，防止含非数字字符的输入透传到服务端
    if (!RegExp(r'^\d{11}$').hasMatch(phone)) {
      showAppSnackBar(context, '请输入正确的11位手机号码', type: SnackBarType.error);
      return;
    }

    final auth = context.read<AuthProvider>();
    final res = await auth.sendSmsCode(phone);

    if (!mounted) return;

    if (res.success) {
      // phonesend 对未注册/待迁移用户直接返回 success:false 与中文提示，
      // 这里只处理发码成功；失败分支统一展示服务端 message
      showAppSnackBar(context, '验证码已发送，请注意查收', type: SnackBarType.success);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.message ?? '验证码发送失败')));
    }
  }

  // 首次登录前展示个人信息收集与使用声明（合规要求，文案与小程序注册页一致；
  // 声明弹窗抽到 privacy_consent.dart 与注册页共用）
  Future<bool> _ensurePrivacyAgreed() => ensurePrivacyAgreed(context);

  void _login() async {
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

    if (!await _ensurePrivacyAgreed()) return;
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyAndLogin(phone, code);
    if (!mounted) return;

    if (ok) {
      showAppSnackBar(context, '登录成功！', type: SnackBarType.success);
      Navigator.pop(context);
    } else {
      showAppSnackBar(context, '验证码错误或登录失败', type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('手机验证码登录')),
      body: ResponsiveCenter(
        child: SingleChildScrollView(
          padding: pageListPadding(context, horizontal: 24, top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 88,
                    height: 88,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text(
                  '云上飞扬',
                  style: AppText.titleApp.copyWith(color: AppTheme.primaryBlue),
                ),
              ),
              Center(
                child: Text(
                  '四川大学飞扬俱乐部设备报修一体化平台',
                  style: AppText.caption.copyWith(
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
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      onTap: isSwitching
                          ? null
                          : () => _switchToAccount(account),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryBlue.withValues(
                          alpha: 0.12,
                        ),
                        backgroundImage: account.avatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(account.avatarUrl)
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
                        style: AppText.titleSm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Text(
                            account.maskedPhone,
                            style: AppText.captionSm.copyWith(
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
                                borderRadius: BorderRadius.circular(
                                  AppRadius.badge,
                                ),
                              ),
                              child: Text(
                                '技术员',
                                style: AppText.tag.copyWith(
                                  color: AppTheme.accentColor,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(
                        '或使用其他手机号登录',
                        style: AppText.captionSm.copyWith(
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
                onPressed: auth.isLoading ? null : _login,
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
                    : const Text('验证码登录', style: AppText.bodyLg),
              ),
              const SizedBox(height: AppSpacing.sm),
              // 「记住登录」：开启时备份 30 天 token，退出登录后重开 App 免验证码
              CheckboxListTile(
                value: _rememberLogin,
                onChanged: (v) async {
                  setState(() => _rememberLogin = v ?? true);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('remember_enabled', _rememberLogin);
                },
                title: const Text('记住此设备', style: AppText.body),
                subtitle: const Text(
                  '30 天内在本机重新打开无需验证码',
                  style: AppText.captionSm,
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: AppSpacing.md),
              // 注册入口：App 内直接手机号注册（2026-09-14 起不再跳转小程序）
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '还没有账号？',
                    style: AppText.captionSm.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('手机号注册'),
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
