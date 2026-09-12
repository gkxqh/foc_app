import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/layout/window_class.dart';
import '../core/theme/app_theme.dart';
import 'activity/activity_page.dart';
import 'home/home_page.dart';
import 'profile/profile_page.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // Tab 切换淡入：IndexedStack 保活页面，切换时对整个内容区做一次轻淡入
  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );

  late final Animation<double> _fade = Tween(
    begin: 0.35,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

  final List<Widget> _pages = const [HomePage(), ActivityPage(), ProfilePage()];

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _selectTab(int idx) {
    if (idx == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = idx);
    _fadeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // 宽屏（折叠屏展开/平板/横屏 ≥600dp）切侧边导航：
    // 固定 68dp 底栏在横屏会吃掉约 1/4 高度，列表可视行数骤减
    final wide = useSideNavigation(context);

    return Scaffold(
      body: Row(
        children: [
          if (wide)
            SafeArea(
              top: true,
              bottom: false,
              child: NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: _selectTab,
                labelType: NavigationRailLabelType.all,
                indicatorColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(
                      Icons.home_rounded,
                      color: AppTheme.primaryBlue,
                    ),
                    label: Text('首页'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.local_activity_outlined),
                    selectedIcon: Icon(
                      Icons.local_activity_rounded,
                      color: AppTheme.primaryBlue,
                    ),
                    label: Text('活动'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(
                      Icons.person_rounded,
                      color: AppTheme.primaryBlue,
                    ),
                    label: Text('我的'),
                  ),
                ],
              ),
            ),
          if (wide) const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: FadeTransition(
              opacity: _fade,
              child: IndexedStack(index: _currentIndex, children: _pages),
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _selectTab,
              indicatorColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(
                    Icons.home_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  label: '首页',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_activity_outlined),
                  selectedIcon: Icon(
                    Icons.local_activity_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  label: '活动',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(
                    Icons.person_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  label: '我的',
                ),
              ],
            ),
    );
  }
}
