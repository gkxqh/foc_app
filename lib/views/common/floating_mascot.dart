import 'package:flutter/material.dart';

import 'pop_in.dart';

/// 吉祥物插画动效：入场弹跳（PopIn）+ 轻微上下浮动待机。
/// 用于"确实没有内容"的空态插画与未登录迎宾图等静态展示场景，
/// 系统开启"减弱动态"时全部静止；插画加载失败兜底回语义图标。
class FloatingMascot extends StatefulWidget {
  final String asset;
  final IconData fallbackIcon;
  final double height;

  const FloatingMascot({
    super.key,
    required this.asset,
    required this.fallbackIcon,
    this.height = 110,
  });

  @override
  State<FloatingMascot> createState() => _FloatingMascotState();
}

class _FloatingMascotState extends State<FloatingMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late final Animation<double> _float = Tween(
    begin: -4.0,
    end: 4.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  bool _checkedReduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkedReduceMotion) return;
    _checkedReduceMotion = true;
    // dependOnInheritedWidget 只能在 build/didChangeDependencies 中调用，
    // 首次进入时按辅助功能设置决定是否循环播放
    if (!MediaQuery.disableAnimationsOf(context)) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      widget.asset,
      height: widget.height,
      fit: BoxFit.contain,
      // 插画加载失败兜底回语义图标
      errorBuilder: (_, _, _) => Icon(
        widget.fallbackIcon,
        size: 64,
        color: Theme.of(context).colorScheme.onSurfaceVariant
            .withValues(alpha: 0.5),
      ),
    );
    // 减弱动态：跳过入场与浮动，直接静态展示
    if (MediaQuery.disableAnimationsOf(context)) {
      return image;
    }
    return PopIn(
      child: AnimatedBuilder(
        animation: _float,
        child: image,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, _float.value), child: child),
      ),
    );
  }
}
