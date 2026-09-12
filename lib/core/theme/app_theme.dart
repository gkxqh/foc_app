import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 布局间距 token：页面留白统一从这里取值（4 的倍数节奏），不再散落魔法数。
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// 圆角 token：取值与 _baseTheme 中各组件默认值保持一致。
class AppRadius {
  AppRadius._();

  static const double badge = 4; // 状态/类型小徽章
  static const double thumb = 8; // 故障图等缩略图
  static const double banner = 10; // 公告/错误横幅
  static const double card = 12; // 卡片与输入框（同 cardTheme/inputDecorationTheme）
  static const double modal = 16; // 大数据卡、庆祝卡
  static const double pill = 24; // 按钮（同 elevated/outlined buttonTheme）
}

/// 阴影 token：浅色模式下的两档海拔投影与品牌色光晕。
/// 深色模式阴影不可见，深色卡片层次由 _cardTheme 的 hairline 描边承担，
/// 不提供深色版 BoxShadow。
class AppShadow {
  AppShadow._();

  // 卡片级：极轻投影（与 cardTheme 浅色卡片一致，供 Container 版卡片使用）
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  // 悬浮级：横幅、浮层等需要明显脱离背景的元素
  static const List<BoxShadow> elevated = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  // 品牌色光晕：渐变英雄卡用主色投影替代中性阴影（年度总结总台数卡）
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.3),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ];
}

/// 文字样式 token：页面级 TextStyle 统一引用，保证字号层级一致；
/// token 不携带颜色，文字颜色交给主题继承或调用处 copyWith 补充。
class AppText {
  AppText._();

  // 超大数字（年度总结总台数、抽奖号码）
  static const TextStyle displayNumber = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.bold,
  );
  // 应用名（登录页/关于页）
  static const TextStyle titleApp = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );
  // 页面大标题（欢迎语、关于页标题）
  static const TextStyle titleXl = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );
  // 强调文本（个人中心昵称，与 AppBar 标题同层级）
  static const TextStyle heading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );
  // 卡片主标题（活动卡标题等）
  static const TextStyle titleLg = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.bold,
  );
  // 区块/表单分组标题
  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle bodyLg = TextStyle(fontSize: 16);
  // 小节标题（设置项标题）
  static const TextStyle titleSm = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle body = TextStyle(fontSize: 14);
  static const TextStyle caption = TextStyle(fontSize: 13);
  static const TextStyle captionSm = TextStyle(fontSize: 12);
  static const TextStyle micro = TextStyle(fontSize: 11);
  // 最小号标签（角标）
  static const TextStyle tag = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
  );
}

class AppTheme {
  // Brand colors
  static const Color primaryBlue = Color(0xFF4187F2);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF57BE6A);

  // 英雄榜领奖台配色（领奖台色柱与 RankBadge 徽章共用，改这里全局生效）
  static const Color rankGold = Color(0xFFF5B301);
  static const Color rankSilver = Color(0xFF9EA7B3);
  static const Color rankBronze = Color(0xFFB07A4B);

  // edge-to-edge 系统栏样式：系统栏透明，图标明度随主题。
  // 经 AppBarTheme 挂到各页 AppBar；main() 启动时先应用浅色值兜底。
  static const SystemUiOverlayStyle lightSystemUi = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  );
  static const SystemUiOverlayStyle darkSystemUi = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  // Ticket Status Colors（2026-09-11 校准：取消并入红系、确认色加深保证白字对比度）
  // Android 小组件的色板 XML 由 tool/gen_widget_colors.dart 生成，改色后需同步该脚本
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
        systemOverlayStyle: lightSystemUi,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
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
        systemOverlayStyle: darkSystemUi,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // 两套主题共享的组件级主题：页面不再各自定义形状/颜色/内边距
  static ThemeData _baseTheme(ColorScheme colorScheme) {
    final bool isDark = colorScheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      cardTheme: _cardTheme(isDark ? const Color(0xFF1F1F1F) : Colors.white, isDark),
      // 页面转场统一：Android 用 M3 淡入前移（与 Tab 内容淡入、列表交错入场
      // 的轻动效语言一致）；iOS/macOS 保持 Cupertino 转场以保留边缘滑动返回
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.md,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white70 : Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.md,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        indicatorColor: primaryBlue.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
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

  static CardThemeData _cardTheme(Color color, bool isDark) {
    return CardThemeData(
      color: color,
      // 浅色用极轻投影分层（近扁平但保留一点空间感）；
      // 深色阴影不可见，改用 hairline 描边区分卡片与背景
      elevation: isDark ? 0 : 1.5,
      shadowColor: const Color(0x14000000),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: isDark
            ? const BorderSide(color: Color(0x0FFFFFFF))
            : BorderSide.none,
      ),
    );
  }
}
