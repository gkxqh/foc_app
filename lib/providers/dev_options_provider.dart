import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/layout/window_class.dart';

/// 开发者选项（本地持久化，仅影响本设备）。
/// 所有实验开关默认关闭/自动：偏好键不存在即视为默认，老版本升级后同样是默认态。
class DevOptionsProvider extends ChangeNotifier {
  static const _keyDirectFinish = 'pref_dev_direct_finish';
  static const _keyLayoutMode = 'pref_dev_layout_mode';

  bool _directFinishEnabled = false;
  LayoutMode? _layoutMode;

  /// 是否显示技术员的「无需确认直接结束工单」按钮
  /// （维修中 / 等待用户确认两个状态共用）
  bool get directFinishEnabled => _directFinishEnabled;

  /// 布局覆盖模式：auto 跟随窗口宽度，其余强制对应断点布局
  LayoutMode get layoutMode => _layoutMode ?? LayoutMode.auto;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _directFinishEnabled = prefs.getBool(_keyDirectFinish) ?? false;
      _layoutMode = _parseLayoutMode(prefs.getString(_keyLayoutMode));
    } catch (_) {
      // 读取失败保持默认
    }
    notifyListeners();
  }

  Future<void> setDirectFinishEnabled(bool enabled) async {
    _directFinishEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDirectFinish, enabled);
    } catch (_) {}
  }

  Future<void> setLayoutMode(LayoutMode mode) async {
    _layoutMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLayoutMode, mode.name);
    } catch (_) {}
  }

  // 未知/损坏的持久化值一律退回 auto，避免老版本残留值把布局锁死
  static LayoutMode _parseLayoutMode(String? raw) {
    for (final mode in LayoutMode.values) {
      if (mode.name == raw) return mode;
    }
    return LayoutMode.auto;
  }
}
