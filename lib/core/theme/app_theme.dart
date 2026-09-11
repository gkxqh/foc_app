import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors
  static const Color primaryBlue = Color(0xFF4187F2);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF57BE6A);

  // Ticket Status Colors（2026-09-11 校准：取消并入红系、确认色加深保证白字对比度）
  static const Color statusPending = Color(0xFF4187F2); // 待分配（蓝）
  static const Color statusRepairing = Color(0xFFF27F41); // 维修中（橙）
  static const Color statusDone = Color(0xFF57BE6A); // 已完成（绿）
  static const Color statusCanceled = Color(
    0xFF9E9E9E,
  ); // 已取消（中性灰：用户主动放弃，无需警示色）
  static const Color statusClosed = Color(0xFFDA3231); // 已关闭（红）
  static const Color statusConfirming = Color(
    0xFFB8860B,
  ); // 双方确认中（深金：白字对比度 4.6:1）

  // 泛用语义色（供页面替代硬编码 Colors.*，随深浅主题由组件主题消费）
  static const Color warningOrange = Color(0xFFF27F41);
  static const Color errorRed = Color(0xFFDA3231);
  static const Color infoBlue = Color(0xFF4187F2);

  static Color getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return statusPending;
      case 'Repairing':
        return statusRepairing;
      case 'Done':
        return statusDone;
      case 'Canceled':
        return statusCanceled;
      case 'Closed':
        return statusClosed;
      case 'UserConfirming':
      case 'TechConfirming':
        return statusConfirming;
      default:
        return Colors.grey;
    }
  }

  static String getStatusText(String status) {
    switch (status) {
      case 'Pending':
        return '待分配';
      case 'Repairing':
        return '维修中';
      case 'UserConfirming':
        return '等待用户确认';
      case 'TechConfirming':
        return '等待技术员确认';
      case 'Done':
        return '已完成';
      case 'Closed':
        return '已关闭';
      case 'Canceled':
        return '已取消';
      default:
        return status;
    }
  }

  // Light Theme
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
      primary: primaryBlue,
      surface: const Color(0xFFF7F8FA),
    );
    return _baseTheme(colorScheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: _cardTheme(const Color(0xFFFFFFFF)),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
      primary: primaryBlue,
      surface: const Color(0xFF1F1F1F),
    );
    return _baseTheme(colorScheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: _cardTheme(const Color(0xFF1F1F1F)),
    );
  }

  // 两套主题共享的组件级主题：页面不再各自定义形状/颜色/内边距
  static ThemeData _baseTheme(ColorScheme colorScheme) {
    final bool isDark = colorScheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      cardTheme: _cardTheme(isDark ? const Color(0xFF1F1F1F) : Colors.white),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white70 : Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        indicatorColor: primaryBlue.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.03),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white12 : Colors.black12,
        thickness: 0.5,
      ),
    );
  }

  static CardThemeData _cardTheme(Color color) {
    return CardThemeData(
      color: color,
      elevation: 0.5,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
