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
import '../common/app_snackbar.dart';
import '../common/page_insets.dart';
import 'about_page.dart';

/// 软件设置：界面外观（主题模式、文字大小、应用图标）与关于信息。
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
  String _currentIcon = 'character'; // character: 飞扬娘（默认主图标）/ red: 飞扬娘头像

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

  // 四个图标选项的元数据（每行两个，顺序即展示顺序）。
  // 说明：LogoLight/LogoArt 两个变体已下架，但其系统别名与回显分支保留
  // （兼容曾切换到这两个图标的设备），此处不再提供入口。
  static const List<({String value, String asset, String label})> _iconOptions =
      [
        (value: 'red', asset: 'assets/preview/red_avatar.png', label: '飞扬娘头像'),
        (
          value: 'character',
          asset: 'assets/preview/character_icon.png',
          label: '飞扬娘',
        ),
        (value: 'logo', asset: 'assets/preview/logo_alt.png', label: '黑底标志'),
        (value: 'fyLogo', asset: 'assets/preview/fy_logo.png', label: '白底标志'),
      ];

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadRememberEnabled();
    _loadCurrentIcon();
  }

  // 用 try/catch 而非 catchError：catchError 回调返回 null 会让
  // Future<PackageInfo> 以 null 完成，触发非空类型断言错误
  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {
      // 读取失败保持空串，界面展示兜底文案
    }
  }

  Future<void> _loadRememberEnabled() async {
    try {
      final v = await context.read<AuthProvider>().isRememberEnabled();
      if (mounted) setState(() => _rememberLogin = v);
    } catch (_) {
      // 读取失败保持默认开启
    }
  }

  Future<void> _loadCurrentIcon() async {
    if (!_canSwitchIcon) return;
    try {
      final name = await FlutterDynamicIconPlus.alternateIconName;
      if (!mounted) return;
      // Android 返回 alias 完整类名（含包名前缀），iOS 返回备用图标名，
      // null = 默认主图标（飞扬娘）。注意派生名需先于其前缀判断。
      setState(() {
        if (name == null) {
          _currentIcon = 'character';
        } else if (name.contains('LogoLight') ||
            name.contains('foc_logo_light')) {
          _currentIcon = 'logoLight';
        } else if (name.contains('LogoArt') || name.contains('foc_logoart')) {
          _currentIcon = 'logoArt';
        } else if (name.contains('MainActivityLogo') ||
            name.contains('foc_logo')) {
          _currentIcon = 'logo';
        } else if (name.contains('FyLogo') || name.contains('foc_fylogo')) {
          _currentIcon = 'fyLogo';
        } else if (name.contains('MainActivityCharacter') ||
            name.contains('foc_character')) {
          _currentIcon = 'character';
        } else {
          // MainActivityRed / foc_red（飞扬娘头像）及未知值兜底
          _currentIcon = 'red';
        }
      });
    } catch (_) {
      // 读取失败保持默认显示
    }
  }

  // 切换应用图标。Android 传 activity-alias 完整类名（包的 String 构造不展开
  // 点前缀）；iOS 传备用图标名，null = 恢复默认主图标。
  Future<void> _switchIcon(String target) async {
    if (_iconSwitching || target == _currentIcon) return;
    if (!_canSwitchIcon) {
      showAppSnackBar(
        context,
        '当前平台（桌面端）暂不支持应用内切换图标',
        type: SnackBarType.error,
      );
      return;
    }
    setState(() => _iconSwitching = true);
    try {
      if (Platform.isAndroid) {
        final pkg = (await PackageInfo.fromPlatform()).packageName;
        final alias = switch (target) {
          'logo' => 'MainActivityLogo',
          'fyLogo' => 'MainActivityFyLogo',
          'red' => 'MainActivityRed',
          _ => 'MainActivityCharacter',
        };
        await FlutterDynamicIconPlus.setAlternateIconName(
          iconName: '$pkg.$alias',
          blacklistBrands: _immediateBrands,
          blacklistManufactures: _immediateBrands,
        );
      } else if (Platform.isIOS) {
        final iconName = switch (target) {
          'logo' => 'foc_logo',
          'logoLight' => 'foc_logo_light',
          'logoArt' => 'foc_logoart',
          'fyLogo' => 'foc_fylogo',
          'character' => null, // null = 恢复默认主图标（飞扬娘）
          'red' => 'foc_red',
          _ => 'foc_character',
        };
        await FlutterDynamicIconPlus.setAlternateIconName(iconName: iconName);
      }
      if (mounted) {
        setState(() => _currentIcon = target);
        showAppSnackBar(
          context,
          '图标已更换，桌面可能需要几秒刷新',
          type: SnackBarType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, '图标更换失败，请重试', type: SnackBarType.error);
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
        padding: pageListPadding(context),
        children: [
          _groupTitle('界面设置'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('深色模式', style: AppText.titleSm),
                  const SizedBox(height: AppSpacing.md),
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
                  const SizedBox(height: AppSpacing.xl),
                  const Text('文字大小', style: AppText.titleSm),
                  const SizedBox(height: AppSpacing.md),
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
                  const SizedBox(height: AppSpacing.lg),
                  // 实时预览
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppRadius.banner),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('预览：笔记本 · 设备清灰', style: AppText.title),
                        const SizedBox(height: AppSpacing.xs),
                        const Text('戴尔 G15', style: AppText.body),
                        const SizedBox(height: 2),
                        Text(
                          '小风扇嗡嗡嗡叫不停',
                          style: AppText.captionSm.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (auth.isTechnician) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.sm),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: config.showAnnouncement,
                      onChanged: (v) => config.setShowAnnouncement(v),
                      title: const Text('首页显示公告'),
                      subtitle: Text(
                        config.showAnnouncement
                            ? '首页顶部展示最新公告与服务须知'
                            : '首页顶部不展示公告栏',
                        style: AppText.captionSm.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: config.showTechRank,
                      onChanged: (v) => config.setShowTechRank(v),
                      title: const Text('首页显示技术员排行榜'),
                      subtitle: Text(
                        config.showTechRank ? '展示技术员排行榜' : '仅展示进行中工单',
                        style: AppText.captionSm.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _groupTitle('应用图标'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _canSwitchIcon
                        ? '选择桌面图标的样式，切换后桌面可能需要几秒刷新'
                        : '当前平台暂不支持应用内切换图标',
                    style: AppText.captionSm.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // 每行两个；奇数个选项时末位用空位填充，避免最后一项被拉伸占满整行
                  Column(
                    children: [
                      for (var i = 0; i < _iconOptions.length; i += 2)
                        Row(
                          children: [
                            for (final option in _iconOptions.sublist(
                              i,
                              i + 2 > _iconOptions.length
                                  ? _iconOptions.length
                                  : i + 2,
                            ))
                              Expanded(
                                child: _buildIconOption(context, option),
                              ),
                            if (_iconOptions.length - i == 1)
                              const Expanded(child: SizedBox.shrink()),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _groupTitle('登录'),
          Card(
            child: SwitchListTile(
              value: _rememberLogin,
              onChanged: (v) async {
                setState(() => _rememberLogin = v);
                await context.read<AuthProvider>().setRememberEnabled(v);
              },
              title: const Text('记住登录状态'),
              subtitle: Text(
                _rememberLogin
                    ? '退出登录后，30 天内在本机重新打开无需验证码；已保存账号可在登录页快速切换'
                    : '已关闭：已保存账号将被清空，退出后需重新验证码登录',
                style: AppText.captionSm.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
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
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              '以上设置仅保存在本设备',
              style: AppText.captionSm.copyWith(
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
    BuildContext context,
    ({String value, String asset, String label}) option,
  ) {
    final selected = _currentIcon == option.value;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: _iconSwitching ? null : () => _switchIcon(option.value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
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
              borderRadius: BorderRadius.circular(AppRadius.card - 2),
              child: Image.asset(
                option.asset,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(Icons.broken_image_outlined, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.captionSm.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 14,
              color: selected
                  ? AppTheme.primaryBlue
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        title,
        style: AppText.caption.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
