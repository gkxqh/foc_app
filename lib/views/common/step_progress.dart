import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 步骤进度条：横向圆点 + 连接线，用于工单详情等流程展示。
///
/// 状态变化时圆点颜色平滑过渡、连接线从左向右填充；
/// 停在未完成的当前步骤时圆点带呼吸光环。
/// [abnormalLast] 为 true 时最后一步呈异常红（取消/关闭等终态），且不加光环。
class StepProgress extends StatefulWidget {
  final List<String> labels;
  final int currentStep;
  final bool abnormalLast;

  const StepProgress({
    super.key,
    required this.labels,
    required this.currentStep,
    this.abnormalLast = false,
  });

  @override
  State<StepProgress> createState() => _StepProgressState();
}

class _StepProgressState extends State<StepProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool _checkedReduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkedReduceMotion) return;
    _checkedReduceMotion = true;
    _updateBreathing();
  }

  @override
  void didUpdateWidget(covariant StepProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateBreathing();
  }

  /// 呼吸光环只在"停在某个未完成步骤"时播放：
  /// 走完全流程、异常终态或系统开启减弱动态时都静止并复位。
  void _updateBreathing() {
    final finished = widget.currentStep >= widget.labels.length - 1;
    final shouldRepeat =
        !finished && !widget.abnormalLast && !MediaQuery.disableAnimationsOf(context);
    if (shouldRepeat && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!shouldRepeat && _breath.isAnimating) {
      _breath
        ..stop()
        ..value = 0.0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weakColor = Theme.of(context)
        .colorScheme
        .onSurfaceVariant
        .withValues(alpha: 0.55);

    final children = <Widget>[];
    for (var i = 0; i < widget.labels.length; i++) {
      if (i > 0) {
        children.add(_StepDivider(done: widget.currentStep > i - 1));
      }
      children.add(
        Expanded(
          child: _StepItem(
            label: widget.labels[i],
            isDone: widget.currentStep >= i,
            isCurrent: widget.currentStep == i,
            isAbnormal: widget.abnormalLast && i == widget.labels.length - 1,
            weakColor: weakColor,
            breath: _breath,
          ),
        ),
      );
    }
    return Row(children: children);
  }
}

class _StepItem extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isCurrent;
  final bool isAbnormal;
  final Color weakColor;
  final Animation<double> breath;

  const _StepItem({
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.isAbnormal,
    required this.weakColor,
    required this.breath,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isAbnormal
        ? AppTheme.errorRed
        : isDone
        ? AppTheme.primaryBlue
        : weakColor;

    return Column(
      children: [
        _StepDot(
          color: color,
          filled: isDone,
          breathing: isCurrent && !isAbnormal,
          breath: breath,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppText.micro.copyWith(
            fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final Color color;
  final bool filled;
  final bool breathing;
  final Animation<double> breath;

  const _StepDot({
    required this.color,
    required this.filled,
    required this.breathing,
    required this.breath,
  });

  @override
  Widget build(BuildContext context) {
    Widget dot = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 24,
      height: 24,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          filled ? Icons.check : Icons.circle,
          // key 变化驱动 AnimatedSwitcher 在勾/点之间切换
          key: ValueKey(filled),
          size: 14,
          color: Colors.white,
        ),
      ),
    );

    if (breathing) {
      dot = AnimatedBuilder(
        animation: breath,
        child: dot,
        builder: (context, child) => Transform.scale(
          scale: 1 + 0.12 * breath.value,
          child: child,
        ),
      );
    }
    return dot;
  }
}

/// 连接线：弱色轨道 + 品牌色前景，完成时从左向右填充
class _StepDivider extends StatelessWidget {
  final bool done;

  const _StepDivider({required this.done});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 2,
      child: Stack(
        children: [
          Container(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          AnimatedAlign(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: Alignment.centerLeft,
            widthFactor: done ? 1.0 : 0.0,
            child: Container(height: 2, color: AppTheme.primaryBlue),
          ),
        ],
      ),
    );
  }
}
