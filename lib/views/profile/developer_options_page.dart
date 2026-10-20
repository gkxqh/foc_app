import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, kProfileMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/layout/window_class.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dev_options_provider.dart';
import '../../services/widget_snapshot_service.dart';
import '../common/app_snackbar.dart';
import '../common/page_insets.dart';

/// 开发者选项：实验功能开关 + 只读诊断信息。
/// 全部内容发布版可带：不含任何鉴权绕过，诊断信息不展示 token / 手机号 / 接单凭据。
class DeveloperOptionsPage extends StatefulWidget {
  const DeveloperOptionsPage({super.key});

  @override
  State<DeveloperOptionsPage> createState() => _DeveloperOptionsPageState();
}

class _DeveloperOptionsPageState extends State<DeveloperOptionsPage> {
  PackageInfo? _packageInfo;
  String _widgetSummary = '—';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadWidgetSummary();
  }

  // 用 try/catch 而非 catchError（见 about_page 同名注释）
  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _packageInfo = info);
    } catch (_) {
      // 读取失败保持 null，界面显示兜底
    }
  }

  /// 桌面小组件快照摘要（仅 Android 有小组件；其他平台与读取失败显示 "—"）
  Future<void> _loadWidgetSummary() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final raw = await HomeWidget.getWidgetData<String>(
        WidgetSnapshotService.payloadKey,
      );
      if (!mounted) return;
      if (raw == null || raw.isEmpty) {
        setState(() => _widgetSummary = '无快照');
        return;
      }
      final map = jsonDecode(raw);
      if (map is! Map) {
        setState(() => _widgetSummary = '快照格式异常');
        return;
      }
      final ts = map['ts'];
      final written = ts is int
          ? DateTime.fromMillisecondsSinceEpoch(ts).toString().split('.').first
          : '未知时间';
      final count = map['countTotal'] ?? (map['tickets'] as List?)?.length ?? 0;
      setState(
        () => _widgetSummary = 'schema v${map['v'] ?? '?'} · $written · 工单 $count 条',
      );
    } catch (_) {
      if (mounted) setState(() => _widgetSummary = '读取失败');
    }
  }

  String get _buildMode =>
      kDebugMode ? 'debug' : (kProfileMode ? 'profile' : 'release');

  String get _platformText {
    if (kIsWeb) return 'Web';
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  }

  String _layoutText(BuildContext context) {
    if (useTwoPane(context)) return '侧边导航 + 列表-详情双栏';
    if (useSideNavigation(context)) return '侧边导航 + 单栏';
    return '底部导航 + 单栏';
  }


  /// 诊断行：label → value（有序；复制时按同一顺序逐行输出）
  List<(String, String)> _diagnostics(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final info = _packageInfo;
    return [
      (
        '版本',
        info == null ? '读取中…' : '${info.version} (${info.buildNumber})',
      ),
      ('构建模式', _buildMode),
      ('平台', _platformText),
      (
        '屏幕',
        '${size.width.toStringAsFixed(0)} × ${size.height.toStringAsFixed(0)} dp'
            ' @${dpr.toStringAsFixed(1)}x · 文字 ${textScale.toStringAsFixed(2)}x',
      ),
      ('布局', _layoutText(context)),
      (
        '登录',
        !auth.isLoggedIn || user == null
            ? '未登录'
            : 'uid ${user.uid} · ${user.role} · ${user.campus.isEmpty ? '校区未设' : user.campus}',
      ),
      ('API 地址', ApiConstants.rootApiUrl),
      ('小组件快照', _widgetSummary),
    ];
  }

  void _copyDiagnostics(BuildContext context) {
    final lines = _diagnostics(context).map((e) => '${e.$1}: ${e.$2}');
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    HapticFeedback.selectionClick();
    showAppSnackBar(context, '诊断信息已复制', type: SnackBarType.success);
  }

  @override
  Widget build(BuildContext context) {
    final dev = context.watch<DevOptionsProvider>();
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('开发者选项')),
      body: ListView(
        padding: pageListPadding(context),
        children: [
          _groupTitle('实验功能'),
          Card(
            child: SwitchListTile(
              value: dev.directFinishEnabled,
              onChanged: (v) =>
                  context.read<DevOptionsProvider>().setDirectFinishEnabled(v),
              title: const Text('显示「无需确认直接结束工单」'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _groupTitle('布局调试'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('布局模式', style: AppText.titleSm),
                  const SizedBox(height: AppSpacing.md),
                  SegmentedButton<LayoutMode>(
                    segments: const [
                      ButtonSegment(value: LayoutMode.auto, label: Text('自动')),
                      ButtonSegment(
                        value: LayoutMode.compact,
                        label: Text('手机'),
                      ),
                      ButtonSegment(
                        value: LayoutMode.medium,
                        label: Text('侧栏'),
                      ),
                      ButtonSegment(
                        value: LayoutMode.expanded,
                        label: Text('双栏'),
                      ),
                    ],
                    selected: {dev.layoutMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (set) => context
                        .read<DevOptionsProvider>()
                        .setLayoutMode(set.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _groupTitle('诊断信息'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final row in _diagnostics(context))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 88,
                            child: Text(
                              row.$1,
                              style: AppText.caption.copyWith(
                                color: onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(row.$2, style: AppText.body),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '不含 token、手机号与接单凭据，可直接粘贴到意见反馈中',
                    style: AppText.captionSm.copyWith(color: onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _copyDiagnostics(context),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('复制诊断信息'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              '以上设置仅保存在本设备',
              style: AppText.captionSm.copyWith(color: onSurfaceVariant),
            ),
          ),
        ],
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
