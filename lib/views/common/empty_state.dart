import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'pop_in.dart';

/// 统一空态组件：吉祥物插画或图标 + 标题 + 可选说明 + 可选操作按钮。
/// 替代各页面手写的"图标+文案"竖排组合，保证全 App 空态观感一致。
///
/// [image] 传入吉祥物插画路径（如飞扬娘 Q 版），此时 [icon] 不展示；
/// 错误类空态建议保留语义图标（cloud_off 等），插画留给"确实没有内容"的场景。
///
/// [minHeight] 用于列表页场景：直接作为 ListView 子项时给定最小高度并垂直居中，
/// 页面不再需要外包 SizedBox 手动撑高。
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String? image;
  final String title;
  final String? subtitle;
  final Widget? action;
  final double? minHeight;

  const EmptyState({
    super.key,
    required this.icon,
    this.image,
    required this.title,
    this.subtitle,
    this.action,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (image != null)
            _FloatingMascot(asset: image!, fallbackIcon: icon)
          else
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: AppText.captionSm.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.xl),
            action!,
          ],
        ],
      ),
    );

    if (minHeight != null) {
      content = SizedBox(
        height: minHeight,
        child: Center(child: content),
      );
    }

    return Center(child: content);
  }
}

/// 吉祥物插画动效：入场弹跳（PopIn）+ 轻微上下浮动待机。
/// 仅用于"确实没有内容"的场景，系统开启"减弱动态"时全部静止。
class _FloatingMascot extends StatefulWidget {
  final String asset;
  final IconData fallbackIcon;

  const _FloatingMascot({required this.asset, required this.fallbackIcon});

  @override
  State<_FloatingMascot> createState() => _FloatingMascotState();
}

class _FloatingMascotState extends State<_FloatingMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late final Animation<double> _float = Tween(begin: -4.0, end: 4.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

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
      height: 110,
      fit: BoxFit.contain,
      // 插画加载失败兜底回语义图标
      errorBuilder: (_, _, _) => Icon(
        widget.fallbackIcon,
        size: 64,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(
          alpha: 0.5,
        ),
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
