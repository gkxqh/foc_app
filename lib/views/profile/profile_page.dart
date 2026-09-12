import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_page.dart';
import 'app_settings_page.dart';
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    // 底色随主题翻转，深色模式下不再是刺眼亮灰圆盘
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    // 无头像时显示本地图标兜底，不向第三方图床发起请求
                    backgroundImage: (user?.avatarUrl.isNotEmpty ?? false)
                        ? CachedNetworkImageProvider(user!.avatarUrl)
                        : null,
                    child: (user?.avatarUrl.isNotEmpty ?? false)
                        ? null
                        : Icon(
                            Icons.person_rounded,
                            size: 40,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
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
                          style: AppText.heading,
                        ),
                        const SizedBox(height: 6),
                        if (auth.isLoggedIn) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
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
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.badge,
                                  ),
                                ),
                                child: Text(
                                  user?.isTechnician == true
                                      ? '技术员 ${user?.uid ?? ''}'
                                      : '普通用户',
                                  style: AppText.micro.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: user?.isTechnician == true
                                        ? AppTheme.accentColor
                                        : AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                              if (user?.campus.isNotEmpty == true) ...[
                                const SizedBox(width: 6),
                                // 长校区名折行省略而非内部溢出
                                Flexible(
                                  child: Text(
                                    user!.campus,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.captionSm.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ] else ...[
                          Text(
                            '登录后查看工单与个性化设置',
                            style: AppText.captionSm.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
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
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.history_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  title: const Text('历史工单'),
                  subtitle: const Text('已结束的报修记录', style: AppText.captionSm),
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
                  subtitle: const Text('修改个人资料', style: AppText.captionSm),
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
                    Icons.tune_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  title: const Text('软件设置'),
                  subtitle: Text(
                    '主题与文字大小',
                    style: AppText.captionSm.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AppSettingsPage(),
                      ),
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
                  subtitle: const Text('意见与建议', style: AppText.captionSm),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FeedbackPage()),
                    );
                  },
                ),
              ],
            ),
          ),
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
