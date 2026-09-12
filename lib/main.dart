import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/config_provider.dart';
import 'providers/ticket_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/update_provider.dart';
import 'services/widget_link_service.dart';
import 'views/splash/launch_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 全局 edge-to-edge：内容延伸到系统栏之后（系统栏透明）。
  // Android 15+ 本就会强制该行为，显式开启让 Android 14 及以下表现一致，
  // 页面 inset 由 AppBarTheme 与 SafeArea 统一消费。
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.lightSystemUi);

  final authProvider = AuthProvider();
  await authProvider.initialize();
  // 使用中 token 失效被登出时给出可见反馈，避免"突然回到未登录态"无解释
  authProvider.onSessionExpiredHint = () {
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('登录已过期，请重新登录'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  };

  final themeProvider = ThemeProvider();
  await themeProvider.load();

  runApp(FeiyangApp(authProvider: authProvider, themeProvider: themeProvider));
}

/// 全局 SnackBar 入口：与页面级 ScaffoldMessenger 解耦，
/// 供 401 登出等无页面上下文的场景使用。
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class FeiyangApp extends StatefulWidget {
  final AuthProvider? authProvider;
  final ThemeProvider? themeProvider;

  const FeiyangApp({super.key, this.authProvider, this.themeProvider});

  @override
  State<FeiyangApp> createState() => _FeiyangAppState();
}

class _FeiyangAppState extends State<FeiyangApp> {
  @override
  void initState() {
    super.initState();
    // 桌面小组件点击回跳：冷启动落点登记 + 热点击订阅
    WidgetLinkService.init();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: widget.authProvider ?? AuthProvider(),
        ),
        ChangeNotifierProvider.value(
          value: widget.themeProvider ?? ThemeProvider(),
        ),
        ChangeNotifierProvider(create: (_) => ConfigProvider()),
        ChangeNotifierProvider(create: (_) => TicketProvider()),
        ChangeNotifierProvider(create: (_) => UpdateProvider()),
      ],
      // Consumer 必须位于 MultiProvider 内部：订阅主题偏好变化，
      // 保证软件设置页切换深色模式/文字大小时 MaterialApp 立即重建生效
      child: Consumer<ThemeProvider>(
        builder: (context, theme, child) {
          return MaterialApp(
            title: '云上飞扬',
            debugShowCheckedModeBanner: false,
            // 小组件深链统一经此 key 跳转（WidgetLinkService）
            navigatorKey: WidgetLinkService.navigatorKey,
            // 全局 SnackBar：401 登出提示在无页面上下文时也能弹出
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: theme.themeMode,
            builder: (context, child) {
              // 全局文字缩放（软件设置 → 界面设置）
              return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(theme.textScale)),
                child: child!,
              );
            },
            home: child,
          );
        },
        child: const LaunchGate(),
      ),
    );
  }
}
