import 'package:flutter/widgets.dart';

/// 内容区最大宽度：窄于该值时全宽铺开，宽于该值时居中留白，
/// 避免折叠屏展开/平板上卡片与表单被拉到 780dp+ 不可读宽度
const double kContentMaxWidth = 600;

/// 列表-详情双栏的最小宽度阈值。
/// 取 720 而非 M3 的 expanded(840)：折叠屏内屏展开态普遍在 673-841dp
/// （Pixel Fold 841 / Galaxy Fold 823），840 会漏掉大部分折叠屏横持展开态；
/// 600-720 之间的窄展开态继续走居中单列
const double kTwoPaneMinWidth = 720;

/// Material 3 窗口宽度分级（https://m3.material.io/foundations/layout/app-layout/window-size-classes）
enum WindowSizeClass {
  /// < 600：手机竖屏、折叠屏外屏、分屏窄半区
  compact,

  /// 600-839：折叠屏竖持展开、平板竖持、手机横屏
  medium,

  /// >= 840：折叠屏横持展开、平板横持、桌面
  expanded,
}

/// 基于窗口宽度取分级。内部走 MediaQuery.sizeOf，
/// 调用方 build 中使用即可在折叠/展开、旋转、分屏拖动时自动重建
WindowSizeClass windowClassOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 840) return WindowSizeClass.expanded;
  if (width >= 600) return WindowSizeClass.medium;
  return WindowSizeClass.compact;
}

/// 是否达到列表-详情双栏的最小宽度
bool useTwoPane(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kTwoPaneMinWidth;

/// 是否应使用侧边导航（NavigationRail）而非底部导航栏
bool useSideNavigation(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 600;
