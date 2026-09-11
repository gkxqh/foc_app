import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/theme_provider.dart';
import 'about_page.dart';

/// 软件设置：界面外观（主题模式、文字大小）与关于信息。
/// 偏好持久化在本地，仅影响本设备。
class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  String _version = '';
  bool _rememberLogin = true;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) setState(() => _version = info.version);
        })
        .catchError((_) {});
    context.read<AuthProvider>().isRememberEnabled().then((v) {
      if (mounted) setState(() => _rememberLogin = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final config = context.watch<ConfigProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('软件设置')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _groupTitle('界面设置'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '深色模式',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_rounded, size: 18),
                        label: Text('跟随系统'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded, size: 18),
                        label: Text('浅色'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded, size: 18),
                        label: Text('深色'),
                      ),
                    ],
                    selected: {theme.themeMode},
                    onSelectionChanged: (set) =>
                        context.read<ThemeProvider>().setThemeMode(set.first),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '文字大小',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    segments: [
                      for (
                        var i = 0;
                        i < ThemeProvider.textScaleLabels.length;
                        i++
                      )
                        ButtonSegment(
                          value: i,
                          label: Text(
                            ThemeProvider.textScaleLabels[i],
                            style: TextStyle(
                              fontSize: 12 + i * 1.5, // 档位示意：越靠右字越大
                            ),
                          ),
                        ),
                    ],
                    selected: {theme.textScaleIndex},
                    onSelectionChanged: (set) => context
                        .read<ThemeProvider>()
                        .setTextScale(ThemeProvider.textScales[set.first]),
                  ),
                  const SizedBox(height: 16),
                  // 实时预览
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '预览：笔记本 · 设备清灰',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '戴尔 G15',
                          style: TextStyle(fontSize: 14),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '小风扇嗡嗡嗡叫不停',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (auth.isTechnician) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: config.showTechRank,
                      onChanged: (v) async {
                        await config.setShowTechRank(v);
                      },
                      title: const Text('首页显示技术员排行榜', style: TextStyle(fontSize: 15)),
                      subtitle: Text(
                        config.showTechRank
                            ? '展示技术员排行榜'
                            : '仅展示进行中工单',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _groupTitle('登录'),
          Card(
            child: SwitchListTile(
              value: _rememberLogin,
              onChanged: (v) async {
                setState(() => _rememberLogin = v);
                await context.read<AuthProvider>().setRememberEnabled(v);
              },
              title: const Text('记住登录状态', style: TextStyle(fontSize: 15)),
              subtitle: Text(
                _rememberLogin ? '退出登录后，30 天内在本机重新打开无需验证码' : '已关闭：退出后需重新验证码登录',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _groupTitle('关于'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(
                Icons.info_outline_rounded,
                color: AppTheme.primaryBlue,
              ),
              title: const Text('关于云上飞扬'),
              subtitle: Text(_version.isEmpty ? '查看版本与项目信息' : '版本 $_version'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              '以上仅保存在本设备',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }
}
