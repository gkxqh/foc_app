import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 骨架屏占位的卡片形态，与真实页面的卡片结构一一对应。
enum SkeletonVariant {
  /// 工单卡：状态徽章 + 标题 + 描述 + 标签行（首页/历史工单）。
  ticket,

  /// 活动卡：海报大图 + 标题 + 描述 + 按钮行（活动页）。
  activity,

  /// 统计页：大数据块 + 四行图标统计（技术员年度总结）。
  stats,

  /// 领奖台：三列色柱（首页英雄榜）。
  podium,
}

/// 列表骨架屏：模拟对应页面卡片的结构占位，替代全屏转圈。
/// 呼吸动画由整体透明度驱动；底色取主题 surfaceContainerHighest，深浅色自适应。
///
/// 单卡占位（领奖台/统计页加载）时传 `shrinkWrap: true` 并配合外部 padding。
class SkeletonList extends StatefulWidget {
  final SkeletonVariant variant;
  final int itemCount;
  final double itemHeight; // 仅 ticket 形态生效
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;

  const SkeletonList({
    super.key,
    this.variant = SkeletonVariant.ticket,
    this.itemCount = 4,
    this.itemHeight = 108,
    this.padding,
    this.shrinkWrap = false,
  });

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
        padding: widget.padding ?? const EdgeInsets.all(AppSpacing.lg),
        shrinkWrap: widget.shrinkWrap,
        physics: widget.shrinkWrap
            ? const NeverScrollableScrollPhysics()
            : null,
        itemCount: widget.itemCount,
        itemBuilder: (_, _) => switch (widget.variant) {
          SkeletonVariant.ticket => _ticketCard(baseColor),
          SkeletonVariant.activity => _activityCard(baseColor),
          SkeletonVariant.stats => _statsCard(baseColor),
          SkeletonVariant.podium => _podiumCard(baseColor),
        },
      ),
    );
  }

  Widget _cardContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double? height,
    EdgeInsetsGeometry? margin = const EdgeInsets.only(bottom: AppSpacing.md),
  }) {
    return Container(
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _ticketCard(Color baseColor) {
    return _cardContainer(
      height: widget.itemHeight,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
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
                const SizedBox(width: AppSpacing.sm),
                _bone(baseColor, width: 64, height: 22, radius: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _activityCard(Color baseColor) {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 150, width: double.infinity, color: baseColor),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _bone(baseColor, width: 150, height: 18),
                    const Spacer(),
                    _bone(baseColor, width: 52, height: 20, radius: 6),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _bone(baseColor, width: 220, height: 13),
                const SizedBox(height: AppSpacing.sm),
                _bone(baseColor, width: 160, height: 13),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    const Spacer(),
                    _bone(
                      baseColor,
                      width: 92,
                      height: 32,
                      radius: AppSpacing.lg,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsCard(Color baseColor) {
    return _cardContainer(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(AppRadius.modal),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (var i = 0; i < 4; i++) ...[
              Row(
                children: [
                  _bone(baseColor, width: 40, height: 40, radius: 20),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: _bone(baseColor, width: double.infinity, height: 13),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  _bone(baseColor, width: 72, height: 13),
                ],
              ),
              if (i < 3) const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ),
      ),
    );
  }

  Widget _podiumCard(Color baseColor) {
    return _cardContainer(
      height: 180,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _podiumColumn(baseColor, height: 44),
            _podiumColumn(baseColor, height: 72),
            _podiumColumn(baseColor, height: 32),
          ],
        ),
      ),
    );
  }

  Widget _podiumColumn(Color baseColor, {required double height}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _bone(baseColor, width: 40, height: 40, radius: 20),
        const SizedBox(height: AppSpacing.sm),
        _bone(baseColor, width: 64, height: 12),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: 64,
          height: height,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: 0.6),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.thumb),
            ),
          ),
        ),
      ],
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
