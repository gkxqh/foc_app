import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../common/app_snackbar.dart';
import '../common/page_insets.dart';
import '../common/responsive_center.dart';

/// 注册成功后的资料完善引导（2026-09-14 新增）：昵称 + 校区，可跳过。
/// 头像等其他资料稍后在「设置」页补充，此处保持最短路径进 App。
class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  late final TextEditingController _nicknameController;
  late String _campus;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _campus =
        user != null &&
            user.campus.isNotEmpty &&
            ApiConstants.campuses.contains(user.campus)
        ? user.campus
        : ApiConstants.campuses.first;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  // 保存或跳过后一路退回首页（登录页、注册页随之出栈，Auth 状态已登录）
  void _finish() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _save() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      showAppSnackBar(context, '昵称不能为空', type: SnackBarType.error);
      return;
    }

    final auth = context.read<AuthProvider>();
    final current = auth.user;
    if (current == null) {
      _finish();
      return;
    }

    final UserModel updated = current.copyWith(
      nickname: nickname,
      campus: _campus,
    );
    final ok = await auth.updateUserInfo(updated);
    if (!mounted) return;

    if (ok) {
      showAppSnackBar(context, '资料已保存', type: SnackBarType.success);
      _finish();
    } else {
      showAppSnackBar(context, '保存失败，请稍后可在设置中修改', type: SnackBarType.error);
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('完善资料'),
        actions: [
          TextButton(
            onPressed: _finish,
            child: Text(
              '跳过',
              style: AppText.body.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: SingleChildScrollView(
          padding: pageListPadding(context, horizontal: 24, top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  '欢迎使用云上飞扬 🎉',
                  style: AppText.titleApp.copyWith(color: AppTheme.primaryBlue),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Text(
                  '昵称和校区会展示在报修工单中，方便技术员联系您（可稍后在设置中修改）',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              TextField(
                controller: _nicknameController,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: '用户昵称',
                  hintText: '怎么称呼您？',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _campus,
                decoration: const InputDecoration(
                  labelText: '所在校区',
                  prefixIcon: Icon(Icons.school_rounded),
                ),
                items: ApiConstants.campuses
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _campus = v!),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton(
                onPressed: auth.isLoading ? null : _save,
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
                    : const Text('保存并进入', style: AppText.bodyLg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
