import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_page.dart';
import 'about_page.dart';
import 'feedback_page.dart';
import 'history_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('个人中心')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.grey.shade200,
                    // 无头像时显示本地图标兜底，不向第三方图床发起请求
                    backgroundImage: (user?.avatarUrl.isNotEmpty ?? false)
                        ? NetworkImage(user!.avatarUrl)
                        : null,
                    child: (user?.avatarUrl.isNotEmpty ?? false)
                        ? null
                        : const Icon(
                            Icons.person_rounded,
                            size: 40,
                            color: Colors.grey,
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.isLoggedIn
                              ? (user?.nickname.isNotEmpty == true
                                    ? user!.nickname
                                    : '同学')
                              : '点击登录',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (auth.isLoggedIn) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: user?.isTechnician == true
                                      ? AppTheme.accentColor.withValues(
                                          alpha: 0.15,
                                        )
                                      : AppTheme.primaryBlue.withValues(
                                          alpha: 0.15,
                                        ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  user?.isTechnician == true
                                      ? '技术员 ${user?.uid ?? ''}'
                                      : '普通用户',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: user?.isTechnician == true
                                        ? Colors.green
                                        : AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                              if (user?.campus.isNotEmpty == true) ...[
                                const SizedBox(width: 6),
                                Text(
                                  user!.campus,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ] else ...[
                          const Text(
                            '登录后查看工单与个性化设置',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!auth.isLoggedIn)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      child: const Text('登录'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.history_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  title: const Text('历史工单'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    if (!auth.isLoggedIn) {
                      _showLoginPrompt(context);
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryPage()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.settings_outlined,
                    color: AppTheme.primaryBlue,
                  ),
                  title: const Text('个人设置'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    if (!auth.isLoggedIn) {
                      _showLoginPrompt(context);
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  title: const Text('问题反馈'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FeedbackPage()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  title: const Text('关于云上飞扬'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    );
                  },
                ),
              ],
            ),
          ),
          if (auth.isLoggedIn) ...[
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () async {
                await auth.logout();
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('已退出登录')));
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('退出当前账号'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showLoginPrompt(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    if (!context.mounted) return;
    // 返回后仍未登录才提示，避免登录成功后的多余打扰
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('登录后即可使用该功能')));
    }
  }
}
