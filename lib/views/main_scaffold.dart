import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'activity/activity_page.dart';
import 'home/home_page.dart';
import 'profile/profile_page.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    ActivityPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        indicatorColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppTheme.primaryBlue),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_activity_outlined),
            selectedIcon: Icon(Icons.local_activity_rounded, color: AppTheme.primaryBlue),
            label: '活动',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppTheme.primaryBlue),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
