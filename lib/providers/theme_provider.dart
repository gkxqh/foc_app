import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 界面偏好（本地持久化）：主题模式与文字缩放。
/// 由 main 初始化后注入，MaterialApp 与软件设置页共同消费。
class ThemeProvider extends ChangeNotifier {
  static const _keyThemeMode = 'pref_theme_mode';
  static const _keyTextScale = 'pref_text_scale';

  /// 文字缩放档位（乘数）
  static const List<double> textScales = [0.85, 1.0, 1.15, 1.3];
  static const List<String> textScaleLabels = ['小', '标准', '大', '特大'];

  ThemeMode _themeMode = ThemeMode.system;
  double _textScale = 1.0;

  ThemeMode get themeMode => _themeMode;
  double get textScale => _textScale;
  int get textScaleIndex {
    final idx = textScales.indexOf(_textScale);
    return idx == -1 ? 1 : idx;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString(_keyThemeMode);
      if (mode == 'light') {
        _themeMode = ThemeMode.light;
      } else if (mode == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
      final scale = prefs.getDouble(_keyTextScale);
      if (scale != null && textScales.contains(scale)) {
        _textScale = scale;
      }
    } catch (_) {
      // 读取失败保持默认
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyThemeMode, switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      });
    } catch (_) {}
  }

  Future<void> setTextScale(double scale) async {
    _textScale = scale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyTextScale, scale);
    } catch (_) {}
  }
}
