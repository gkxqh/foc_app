import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) setState(() => _version = info.version);
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

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
                  const SizedBox(height: 4),
                  Text(
                    switch (theme.themeMode) {
                      ThemeMode.light => '当前：浅色，界面始终使用亮色主题',
                      ThemeMode.dark => '当前：深色，界面始终使用暗色主题',
                      _ => '当前：跟随系统，随系统深浅色自动切换',
                    },
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
                  const SizedBox(height: 4),
                  Text(
                    '调整应用内文字的整体大小',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
                          '预览：工单 #10086',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '笔记本 · 设备清灰 · 维修中',
                          style: TextStyle(fontSize: 14),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '技术员已接单，将尽快与您联系',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
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
              '界面偏好保存在本设备，云端账号数据不受影响',
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
