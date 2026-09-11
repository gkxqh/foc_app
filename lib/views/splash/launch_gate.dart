import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';

import '../main_scaffold.dart';

/// 启动入口：按平台决定是否续接开屏。
///
/// Android 原生开屏已通过 activity-alias 主题逐变体跟随所选图标
/// （LaunchThemeRed/FyLogo/Logo → launch_background_*），无需处理；
/// iOS 的 LaunchScreen 是编译期固定的 storyboard，无法跟随运行时切换的
/// 图标（苹果限制），因此 iOS 在 Flutter 首帧起显示"黑底 + 当前所选图标
/// 对应的图"并短暂停留，观感上开屏跟随图标。
class LaunchGate extends StatelessWidget {
  const LaunchGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isIOS) return const MainScaffold();
    return const IconSplashPage();
  }
}

class IconSplashPage extends StatefulWidget {
  const IconSplashPage({super.key});

  // 与软件设置页 _iconOptions 的预览资源一致；判定顺序需先于前缀派生名
  // （foc_logo 是 foc_logo_light / foc_logoart 的前缀）。
  static String _assetForIcon(String? name) {
    if (name == null) return 'assets/icon/character_icon.png';
    if (name.contains('foc_logo_light')) return 'assets/icon/logo_alt.png';
    if (name.contains('foc_logoart')) return 'assets/icon/logo_art.png';
    if (name.contains('foc_logo')) return 'assets/icon/logo_alt.png';
    if (name.contains('foc_fylogo')) return 'assets/icon/fy_logo.png';
    return 'assets/icon/red_avatar.png'; // foc_red 及未知值兜底
  }

  @override
  State<IconSplashPage> createState() => _IconSplashPageState();
}

class _IconSplashPageState extends State<IconSplashPage> {
  static const _holdDuration = Duration(milliseconds: 1000);
  static const _fadeDuration = Duration(milliseconds: 350);

  String _asset = 'assets/icon/character_icon.png';
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    _resolveIcon();
  }

  Future<void> _resolveIcon() async {
    try {
      final name = await FlutterDynamicIconPlus.alternateIconName;
      if (mounted && name != null) {
        setState(() => _asset = IconSplashPage._assetForIcon(name));
      }
    } catch (_) {
      // 读取失败保持默认图，不影响进入主界面
    }
    // 原生开屏刚消失就立刻进主界面会让"跟随"不可见，短暂停留后再过渡
    await Future.delayed(_holdDuration);
    if (mounted) setState(() => _entered = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: _fadeDuration,
      child: _entered
          ? const MainScaffold(key: ValueKey('main'))
          : Container(
              key: const ValueKey('splash'),
              color: Colors.black,
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Image.asset(
                  _asset,
                  key: ValueKey(_asset),
                  width: 220,
                  fit: BoxFit.contain,
                ),
              ),
            ),
    );
  }
}
