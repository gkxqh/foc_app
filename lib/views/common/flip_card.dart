import 'dart:math';

import 'package:flutter/material.dart';

/// 双面 3D 翻转卡：点击整卡绕 Y 轴翻转（透视投影 + rotateY 0→π，
/// easeInOutCubic 500ms），转过半程切换显示 [back]，且背面自身预旋转 π
/// 消除镜像，使翻至正对视角时内容朝向正确。
///
/// [onFlip] 在当前应显示的面发生变化时回调，true 表示正在展示背面
/// （含中途反向回翻的 crossing），供宿主同步页面级提示文案。
/// 系统开启"减弱动态"时点击直接切换显示面，不做动画。
class FlipCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final ValueChanged<bool>? onFlip;

  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    this.onFlip,
  });

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );

  // 已回调过的显示面（true=背面），用于在半程 crossing 时通知宿主
  bool _notifiedBack = false;
  // 减弱动态模式下动画不可用，直接以该状态切换显示面
  bool _showBackDirect = false;

  @override
  void initState() {
    super.initState();
    // 半程通知需逐帧监听，与 AnimatedBuilder 的重建并行
    _controller.addListener(_handleTick);
  }

  void _toggle() {
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _showBackDirect = !_showBackDirect);
      _notifiedBack = _showBackDirect;
      widget.onFlip?.call(_showBackDirect);
      return;
    }
    // 正在翻转中再次点击：向反方向回翻（半程通知仍随 crossing 触发）
    if (_controller.status == AnimationStatus.forward ||
        _controller.status == AnimationStatus.completed) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  void _handleTick() {
    final showBack = _curve.value >= 0.5;
    if (showBack != _notifiedBack) {
      _notifiedBack = showBack;
      widget.onFlip?.call(showBack);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: _showBackDirect ? widget.back : widget.front,
      );
    }
    // 半程通知已在 initState 注册监听
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final angle = _curve.value * pi;
          final showBack = _curve.value >= 0.5;
          final face = showBack ? widget.back : widget.front;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY(angle),
            child: showBack
                // 背面预旋转 π：与外层合成后恰好回正，消除镜像
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: face,
                  )
                : face,
          );
        },
      ),
    );
  }
}
