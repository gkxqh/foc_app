import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/config_provider.dart';
import 'providers/ticket_provider.dart';
import 'providers/theme_provider.dart';
import 'views/main_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authProvider = AuthProvider();
  await authProvider.initialize();

  final themeProvider = ThemeProvider();
  await themeProvider.load();

  runApp(FeiyangApp(authProvider: authProvider, themeProvider: themeProvider));
}

class FeiyangApp extends StatelessWidget {
  final AuthProvider? authProvider;
  final ThemeProvider? themeProvider;

  const FeiyangApp({super.key, this.authProvider, this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider ?? AuthProvider()),
        ChangeNotifierProvider.value(value: themeProvider ?? ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ConfigProvider()),
        ChangeNotifierProvider(create: (_) => TicketProvider()),
      ],
      // Consumer 必须位于 MultiProvider 内部：订阅主题偏好变化，
      // 保证软件设置页切换深色模式/文字大小时 MaterialApp 立即重建生效
      child: Consumer<ThemeProvider>(
        builder: (context, theme, child) {
          return MaterialApp(
            title: '云上飞扬',
            debugShowCheckedModeBanner: false,
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
        child: const MainScaffold(),
      ),
    );
  }
}
