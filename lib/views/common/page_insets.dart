import 'package:flutter/material.dart';

/// edge-to-edge 下滚动列表页的通用内边距：内容会延伸到透明导航栏/手势条之后，
/// 列表尾部需按系统栏高度补白，避免最后一项被遮挡。
/// 主框架 Tab 页的底部由 NavigationBar 自行消费该 inset，不需要使用本工具。
EdgeInsets pageListPadding(
  BuildContext context, {
  double horizontal = 16,
  double top = 16,
  double extraBottom = 0,
}) {
  return EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    extraBottom + MediaQuery.viewPaddingOf(context).bottom,
  );
}
