import 'package:flutter/material.dart';

/// 列表入场动画：按 [index] 依次淡入并上滑（staggered），
/// 前 [maxStaggerIndex] 个逐个延迟，之后的同步播放避免长列表等待。
/// 用于首页工单卡、活动卡、历史工单卡的首屏呈现。
class StaggeredIn extends StatelessWidget {
  final int index;
  final Widget child;
  final int maxStaggerIndex;

  const StaggeredIn({
    super.key,
    required this.index,
    required this.child,
    this.maxStaggerIndex = 6,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIndex = index.clamp(0, maxStaggerIndex);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + effectiveIndex * 55),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
