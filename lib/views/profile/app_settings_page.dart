import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';
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
  bool _iconSwitching = false;
  String _currentIcon = 'red'; // red: 红发形象 / logo: 飞扬标志

  bool get _canSwitchIcon => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  // flutter_dynamic_icon_plus 在非黑名单品牌上走 Service 延迟应用（需用户划掉
  // 最近任务才生效）。传入全量主流品牌强制走同步切换分支，切换立即生效。
  static const List<String> _immediateBrands = [
    'huawei',
    'honor',
    'xiaomi',
    'redmi',
    'samsung',
    'oppo',
    'vivo',
    'oneplus',
    'realme',
    'meizu',
    'lenovo',
    'motorola',
    'google',
    'asus',
    'nubia',
    'zte',
    'sony',
    'htc',
    'lg',
    'nothing',
    'nokia',
    'hmd',
    'tecno',
    'infinix',
    'itel',
    'sharp',
    'fujitsu',
  ];

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
    _loadCurrentIcon();
  }

  Future<void> _loadCurrentIcon() async {
    if (!_canSwitchIcon) return;
    try {
      final name = await FlutterDynamicIconPlus.alternateIconName;
      if (!mounted) return;
      // Android 返回 alias 完整类名（如 cn.ac.feiyang.foc_app.MainActivityLogo），
      // iOS 返回备用图标名 foc_logo，默认（红发）时为 null
      setState(() {
        _currentIcon =
            (name != null &&
                (name.contains('MainActivityLogo') ||
                    name.contains('foc_logo')))
            ? 'logo'
            : 'red';
      });
    } catch (_) {
      // 读取失败保持默认显示
    }
  }

  // 切换应用图标：Android 传 activity-alias 类名，iOS 传备用图标名（null = 默认红发）
  Future<void> _switchIcon(String target) async {
    if (_iconSwitching || target == _currentIcon) return;
    if (!_canSwitchIcon) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('当前平台（桌面端）暂不支持应用内切换图标')));
      return;
    }
    setState(() => _iconSwitching = true);
    try {
      if (Platform.isAndroid) {
        // 包的 Android 实现用 ComponentName(pkg, name) 的 String 构造，
        // 不展开点前缀，必须传完整类名（点前缀会报 Component does not exist）
        final pkg = (await PackageInfo.fromPlatform()).packageName;
        await FlutterDynamicIconPlus.setAlternateIconName(
          iconName: target == 'logo'
              ? '$pkg.MainActivityLogo'
              : '$pkg.MainActivityRed',
          blacklistBrands: _immediateBrands,
          blacklistManufactures: _immediateBrands,
        );
      } else if (Platform.isIOS) {
        await FlutterDynamicIconPlus.setAlternateIconName(
          iconName: target == 'logo' ? 'foc_logo' : null,
        );
      }
      if (mounted) {
        setState(() => _currentIcon = target);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('图标已更换，桌面可能需要几秒刷新')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('图标更换失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _iconSwitching = false);
    }
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
                        Text('戴尔 G15', style: TextStyle(fontSize: 14)),
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
                      title: const Text(
                        '首页显示技术员排行榜',
                        style: TextStyle(fontSize: 15),
                      ),
                      subtitle: Text(
                        config.showTechRank ? '展示技术员排行榜' : '仅展示进行中工单',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: config.showAnnouncement,
                      onChanged: (v) async {
                        await config.setShowAnnouncement(v);
                      },
                      title: const Text(
                        '首页显示公告',
                        style: TextStyle(fontSize: 15),
                      ),
                      subtitle: Text(
                        config.showAnnouncement ? '展示顶部公告栏' : '隐藏顶部公告栏',
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
          _groupTitle('应用图标'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _canSwitchIcon
                        ? '选择桌面图标的样式，切换后桌面可能需要几秒刷新'
                        : '当前平台暂不支持应用内切换图标',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildIconOption(
                        context,
                        value: 'red',
                        asset: 'assets/icon/icon.png',
                        label: '飞扬娘',
                      ),
                      const SizedBox(width: 16),
                      _buildIconOption(
                        context,
                        value: 'logo',
                        asset: 'assets/icon/logo_alt.png',
                        label: '飞扬标志',
                      ),
                    ],
                  ),
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

  // 应用图标选项：预览图 + 名称，选中加高亮边框
  Widget _buildIconOption(
    BuildContext context, {
    required String value,
    required String asset,
    required String label,
  }) {
    final selected = _currentIcon == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _iconSwitching ? null : () => _switchIcon(value),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.primaryBlue : Colors.transparent,
              width: 2,
            ),
            color: selected
                ? AppTheme.primaryBlue.withValues(alpha: 0.06)
                : Theme.of(context).colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  asset,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 15,
                      color: AppTheme.primaryBlue,
                    )
                  else
                    Icon(
                      Icons.circle_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
