import 'package:flutter/material.dart';

/// 列表骨架屏：模拟工单卡片的结构占位，替代全屏转圈。
/// 闪烁动画由系统主题的 disabledColor 驱动，深浅色自适应。
class SkeletonList extends StatefulWidget {
  final int itemCount;
  final double itemHeight;

  const SkeletonList({super.key, this.itemCount = 4, this.itemHeight = 108});

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: Tween(
        begin: 0.45,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: widget.itemCount,
        itemBuilder: (_, _) => Container(
          height: widget.itemHeight,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _bone(baseColor, width: 64, height: 20),
                    const Spacer(),
                    _bone(baseColor, width: 44, height: 12),
                  ],
                ),
                const SizedBox(height: 14),
                _bone(baseColor, width: 180, height: 18),
                const SizedBox(height: 10),
                _bone(baseColor, width: 240, height: 13),
                const Spacer(),
                Row(
                  children: [
                    _bone(baseColor, width: 52, height: 22, radius: 4),
                    const SizedBox(width: 8),
                    _bone(baseColor, width: 64, height: 22, radius: 4),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bone(
    Color color, {
    required double width,
    required double height,
    double radius = 6,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
