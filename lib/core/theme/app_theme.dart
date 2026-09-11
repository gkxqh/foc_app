import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors
  static const Color primaryBlue = Color(0xFF4187F2);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF57BE6A);
  
  // Ticket Status Colors
  static const Color statusPending = Color(0xFF4187F2);      // 待分配
  static const Color statusRepairing = Color(0xFFF27F41);    // 维修中
  static const Color statusDone = Color(0xFF57BE6A);         // 已完成
  static const Color statusCanceled = Color(0xFFBF1D9C);     // 已取消
  static const Color statusClosed = Color(0xFFDA3231);       // 已关闭
  static const Color statusConfirming = Color(0xFFCFBE06);   // 双方确认中

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
        return '等待技工确认';
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
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
        primary: primaryBlue,
        surface: const Color(0xFFF7F8FA),
      ),
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
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.dark,
        primary: primaryBlue,
        surface: const Color(0xFF1F1F1F),
      ),
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
      cardTheme: CardThemeData(
        color: const Color(0xFF1F1F1F),
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }
}
