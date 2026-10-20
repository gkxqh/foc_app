import 'package:flutter/widgets.dart';

/// 内容区最大宽度：窄于该值时全宽铺开，宽于该值时居中留白，
/// 避免折叠屏展开/平板上卡片与表单被拉到 780dp+ 不可读宽度
const double kContentMaxWidth = 600;

/// 列表-详情双栏的最小宽度阈值。
/// 取 720 而非 M3 的 expanded(840)：折叠屏内屏展开态普遍在 673-841dp
/// （Pixel Fold 841 / Galaxy Fold 823），840 会漏掉大部分折叠屏横持展开态；
/// 600-720 之间的窄展开态继续走居中单列
const double kTwoPaneMinWidth = 720;

/// 侧边导航（NavigationRail）的最小宽度阈值
const double kSideNavMinWidth = 600;

/// Material 3 窗口宽度分级（https://m3.material.io/foundations/layout/app-layout/window-size-classes）
enum WindowSizeClass {
  /// < 600：手机竖屏、折叠屏外屏、分屏窄半区
  compact,

  /// 600-839：折叠屏竖持展开、平板竖持、手机横屏
  medium,

  /// >= 840：折叠屏横持展开、平板横持、桌面
  expanded,
}

/// 布局覆盖模式（开发者选项）：auto 跟随窗口宽度，其余强制对应布局，
/// 用于在任意尺寸的设备上预演各断点下的界面
enum LayoutMode {
  /// 跟随窗口宽度（默认）
  auto,

  /// 强制手机布局：底部导航 + 单栏
  compact,

  /// 强制侧边导航 + 单栏
  medium,

  /// 强制侧边导航 + 列表-详情双栏
  expanded,
}

/// 向下游断点函数提供布局覆盖；由 main 放在 MaterialApp.builder 中，
/// 未挂载时所有函数退回按窗口宽度判断
class LayoutOverride extends InheritedWidget {
  const LayoutOverride({super.key, required this.mode, required super.child});

  final LayoutMode mode;

  static LayoutMode of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LayoutOverride>()?.mode ??
      LayoutMode.auto;

  @override
  bool updateShouldNotify(LayoutOverride oldWidget) => oldWidget.mode != mode;
}

/// 基于窗口宽度取分级（受布局覆盖影响）。内部走 MediaQuery.sizeOf，
/// 调用方 build 中使用即可在折叠/展开、旋转、分屏拖动时自动重建
WindowSizeClass windowClassOf(BuildContext context) {
  switch (LayoutOverride.of(context)) {
    case LayoutMode.compact:
      return WindowSizeClass.compact;
    case LayoutMode.medium:
      return WindowSizeClass.medium;
    case LayoutMode.expanded:
      return WindowSizeClass.expanded;
    case LayoutMode.auto:
      final width = MediaQuery.sizeOf(context).width;
      if (width >= 840) return WindowSizeClass.expanded;
      if (width >= kSideNavMinWidth) return WindowSizeClass.medium;
      return WindowSizeClass.compact;
  }
}

/// 是否使用列表-详情双栏
bool useTwoPane(BuildContext context) {
  switch (LayoutOverride.of(context)) {
    case LayoutMode.compact:
    case LayoutMode.medium:
      return false;
    case LayoutMode.expanded:
      // 强制双栏在过窄窗口会把右栏挤到不可用并溢出，保留 600dp 下限兜底
      return MediaQuery.sizeOf(context).width >= kSideNavMinWidth;
    case LayoutMode.auto:
      return MediaQuery.sizeOf(context).width >= kTwoPaneMinWidth;
  }
}

/// 是否应使用侧边导航（NavigationRail）而非底部导航栏
bool useSideNavigation(BuildContext context) {
  switch (LayoutOverride.of(context)) {
    case LayoutMode.compact:
      return false;
    case LayoutMode.medium:
    case LayoutMode.expanded:
      return true;
    case LayoutMode.auto:
      return MediaQuery.sizeOf(context).width >= kSideNavMinWidth;
  }
}
