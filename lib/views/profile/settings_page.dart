import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../common/confirm_dialog.dart';
import 'new_phone_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();

  late TextEditingController _nicknameController;
  String _nicknameInitialValue = ''; // 云端昵称基线，用于判断用户是否编辑过
  late String _campus;
  late double _wantsSliderValue;
  late bool _canDuo;
  late int _maxConcurrent; // 同时接单上限（服务端限 1-10）
  String _avatarUrl = '';
  bool _isUploadingAvatar = false;
  bool _isSaving = false;

  final List<String> _wantsLetters = ['a', 'b', 'c', 'd', 'e'];
  final Map<String, String> _wantsLabels = {
    'a': '暂停接单 (休整)',
    'b': '减少接单',
    'c': '正常接单',
    'd': '增加接单',
    'e': '疯狂接单！🔥',
  };

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user ?? UserModel();
    _applyUser(user);
    // 进入页面时从云端重新拉取：设置可能在其他设备（如小程序）上被修改过
    _syncFromRemote();
  }

  void _applyUser(UserModel user) {
    _nicknameInitialValue = user.nickname;
    _nicknameController = TextEditingController(text: user.nickname);
    _campus =
        user.campus.isNotEmpty && ApiConstants.campuses.contains(user.campus)
        ? user.campus
        : ApiConstants.campuses.first;

    final wantsLetter = user.wants ?? 'c';
    final idx = _wantsLetters.indexOf(wantsLetter);
    _wantsSliderValue = (idx != -1 ? idx : 2).toDouble();

    _canDuo = user.canDuo == 1;
    _maxConcurrent = user.maxConcurrent.clamp(1, 10);
    _avatarUrl = user.avatarUrl;
  }

  /// 从服务端同步最新资料。昵称仅在用户尚未编辑时回填，避免冲掉正在输入的内容。
  Future<void> _syncFromRemote() async {
    try {
      await context.read<AuthProvider>().refreshUserInfo();
    } catch (_) {
      return; // 网络失败时保留本地快照
    }
    if (!mounted) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() {
      if (_nicknameController.text == _nicknameInitialValue) {
        _nicknameController.text = user.nickname;
      }
      _nicknameInitialValue = user.nickname;
      if (user.campus.isNotEmpty &&
          ApiConstants.campuses.contains(user.campus)) {
        _campus = user.campus;
      }
      final wantsLetter = user.wants ?? 'c';
      final idx = _wantsLetters.indexOf(wantsLetter);
      if (idx != -1) _wantsSliderValue = idx.toDouble();
      _canDuo = user.canDuo == 1;
      _maxConcurrent = user.maxConcurrent.clamp(1, 10);
      if (user.avatarUrl.isNotEmpty) _avatarUrl = user.avatarUrl;
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final XFile? picked;
    try {
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
    } catch (_) {
      // 相册权限被拒等场景：image_picker 会抛出异常而非返回 null
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开相册，请检查相册权限设置')));
      return;
    }
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    final res = await ApiClient().uploadImage(picked.path);

    if (!mounted) return;
    setState(() => _isUploadingAvatar = false);

    if (res.success && res.data != null) {
      setState(() => _avatarUrl = res.data!);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('头像上传成功，请保存设置')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.message ?? '头像上传失败')));
    }
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;
    final auth = context.read<AuthProvider>();
    final currentUser = auth.user;
    if (currentUser == null) return;

    final updatedUser = currentUser.copyWith(
      nickname: _nicknameController.text.trim(),
      campus: _campus,
      avatarUrl: _avatarUrl,
    );

    setState(() => _isSaving = true);
    final okProfile = await auth.updateUserInfo(updatedUser);

    bool okTech = true;
    if (currentUser.isTechnician) {
      final wantsLetter = _wantsLetters[_wantsSliderValue.round()];
      okTech = await auth.updateTechSettings(
        wants: wantsLetter,
        canDuo: _canDuo ? 1 : 0,
        maxConcurrent: _maxConcurrent,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (okProfile && okTech) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('个人资料更新成功！')));
      Navigator.pop(context);
    } else if (okProfile && !okTech) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('个人资料已保存，但技术员设置保存失败，请重试')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('保存失败，请稍后重试')));
    }
  }

  Future<void> _changeEmail() async {
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => const _EmailDialog(),
    );
    if (email == null || !mounted) return;

    final ok = await _authService.newEmail(email);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('变更失败，请稍后重试')));
      return;
    }
    // 服务端 newemail 只把新邮箱存为待验证状态并发验证邮件，验证完成后才真正生效
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('验证邮件已发送至新邮箱，请查收邮件完成验证后生效')));
    context.read<AuthProvider>().refreshUserInfo();
  }

  Future<void> _deleteAccount() async {
    final ok = await showConfirmDialog(
      context,
      title: '注销账号？',
      content: '注销后所有报修历史、技术员积分和个人数据将被永久删除且无法恢复！',
      confirmText: '确认注销',
      danger: true,
    );

    if (!ok) return;
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final deleted = await _authService.deleteAccount();
    if (!mounted) return;

    if (deleted) {
      // 注销后移除本机保存的该账号，避免残留过期凭据
      await auth.removeSavedAccount(auth.user?.phone ?? '');
      await auth.logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('账号已成功注销')));
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('注销失败，请稍后重试或联系管理员')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isTech = auth.isTechnician;

    return Scaffold(
      appBar: AppBar(title: const Text('个人设置')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isUploadingAvatar ? null : _pickAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey.shade200,
                          // 无头像时显示本地图标兜底，不向第三方图床发起请求
                          backgroundImage: _avatarUrl.isNotEmpty
                              ? NetworkImage(_avatarUrl)
                              : null,
                          child: _avatarUrl.isNotEmpty
                              ? null
                              : const Icon(
                                  Icons.person_rounded,
                                  size: 44,
                                  color: Colors.grey,
                                ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.blue,
                            child: _isUploadingAvatar
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '点击更换头像',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(
                      labelText: '用户昵称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _campus,
                    decoration: const InputDecoration(
                      labelText: '所在校区',
                      border: OutlineInputBorder(),
                    ),
                    items: ApiConstants.campuses
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _campus = v!),
                  ),
                ],
              ),
            ),
          ),
          if (isTech) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '技术员接单意愿与设置',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('接单意向：'),
                        Text(
                          _wantsLabels[_wantsLetters[_wantsSliderValue
                                  .round()]] ??
                              '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _wantsSliderValue,
                      min: 0,
                      max: 4,
                      divisions: 4,
                      onChanged: (v) => setState(() => _wantsSliderValue = v),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('同时接单上限：'),
                        Text(
                          '$_maxConcurrent 单',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _maxConcurrent.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '$_maxConcurrent',
                      onChanged: (v) =>
                          setState(() => _maxConcurrent = v.round()),
                    ),
                    Text(
                      '同时维修中的工单达到上限后，系统将暂停自动派新单给您',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('多校区接单意愿'),
                      subtitle: const Text('开启后将支持接收来自其他校区同学的设备报修工单'),
                      value: _canDuo,
                      onChanged: (v) => setState(() => _canDuo = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('接收进度通知邮箱'),
                  subtitle: Text(
                    auth.user?.email.isNotEmpty == true
                        ? auth.user!.email
                        : '未绑定',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _changeEmail,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phone_android_outlined),
                  title: const Text('更换手机号'),
                  subtitle: Text(
                    auth.user?.phone.isNotEmpty == true
                        ? auth.user!.phone
                        : '未绑定',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NewPhonePage()),
                    );
                    if (mounted) _syncFromRemote();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent_outlined),
                  title: const Text('联系客服'),
                  subtitle: Text(
                    isTech
                        ? '请在技术员群中联系群主或管理员'
                        : '请在会员群中联系群主或管理员',
                  ),
                  onTap: () {
                    Clipboard.setData(
                      const ClipboardData(text: ApiConstants.supportPhone),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('客服电话 ${ApiConstants.supportPhone} 已复制'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: Colors.red,
                  ),
                  title: const Text(
                    '注销云上飞扬账号',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: _deleteAccount,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存修改'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// 独立的邮箱修改弹窗：controller 由 State 持有并释放，提交前做格式校验
class _EmailDialog extends StatefulWidget {
  const _EmailDialog();

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改接收通知邮箱'),
      content: TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: '新邮箱地址',
          hintText: 'example@scu.edu.cn',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final email = _emailController.text.trim();
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('请输入有效的邮箱地址')));
              return;
            }
            Navigator.pop(context, email);
          },
          child: const Text('确认'),
        ),
      ],
    );
  }
}
