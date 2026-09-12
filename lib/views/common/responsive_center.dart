import 'package:flutter/material.dart';

import '../../core/layout/window_class.dart';

/// 页面内容居中限宽：窄视口全宽铺开，宽视口（折叠屏展开/平板/横屏）
/// 限制在 [maxWidth] 内水平居中，避免单列内容被拉满整屏。
///
/// 用法：包在滚动视图外层（如 `ResponsiveCenter(child: ListView(...))`），
/// 高度约束原样下发，不影响 ListView 滚动语义与 RefreshIndicator。
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveCenter({
    super.key,
    this.maxWidth = kContentMaxWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
