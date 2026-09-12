import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 数字滚动文本：传入的 [text] 为纯整数时从 0 滚动到目标值，
/// 否则（含小数/非数字内容）直接静态展示。
/// 用于年度维修总台数、抽奖号码等大数字的首屏强调。
class CountUpText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;

  const CountUpText(
    this.text, {
    super.key,
    this.style,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  int? _target;
  // 抽奖号码可能带前导零（如 "0886"），按原位数补零展示，滚动中不丢位
  int _digitCount = 0;

  @override
  void initState() {
    super.initState();
    _resolveTarget(widget.text);
    if (_target != null) {
      _controller.forward();
    }
  }

  void _resolveTarget(String text) {
    final parsed = int.tryParse(text);
    if (parsed == null || text.contains('.') || text.contains('-')) {
      _target = null;
      return;
    }
    _target = parsed;
    _digitCount = text.length;
  }

  String _format(int value) => '$value'.padLeft(_digitCount, '0');

  @override
  void didUpdateWidget(CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text) return;
    _resolveTarget(widget.text);
    setState(() {});
    if (_target != null) {
      // 数据刷新（如下拉后数字变大）时重播滚动
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    if (target == null) {
      return Text(widget.text, style: widget.style);
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Text(
          _format((target * _animation.value).round()),
          style: widget.style ?? AppText.displayNumber,
        );
      },
    );
  }
}
