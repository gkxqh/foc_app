import 'package:flutter/material.dart';

/// 弹跳入场：缩放从 [fromScale] 过冲到 1（easeOutBack），用于庆祝卡、
/// 弹窗卡片等需要"跳出来"的元素。每次进入页面播放一次。
class PopIn extends StatefulWidget {
  final Widget child;
  final double fromScale;
  final Duration duration;

  const PopIn({
    super.key,
    required this.child,
    this.fromScale = 0.6,
    this.duration = const Duration(milliseconds: 420),
  });

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  late final Animation<double> _scale = Tween(
    begin: widget.fromScale,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  late final Animation<double> _opacity = Tween(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.5, curve: Curves.easeOut),
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: FadeTransition(opacity: _opacity, child: widget.child),
    );
  }
}
