import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/core/theme/app_theme.dart';
import 'package:foc_app/views/common/step_progress.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

Finder _dotContainers() => find.descendant(
  of: find.byType(StepProgress),
  matching: find.byWidgetPredicate(
    (w) =>
        w is AnimatedContainer &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).shape == BoxShape.circle,
  ),
);

void main() {
  testWidgets('进行中步骤条：勾/点切换、连接线填充与圆点颜色', (tester) async {
    // 呼吸光环循环播放，不能 pumpAndSettle（永不停止），改用定量 pump
    await tester.pumpWidget(
      _host(
        StepProgress(
          labels: const ['报修', '接单', '确认', '完成'],
          currentStep: 2,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('报修'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    // 第 0、1、2 步已完成（当前步也算已完成，均显示勾），仅第 3 步未开始（点）
    expect(find.byIcon(Icons.check), findsNWidgets(3));
    expect(find.byIcon(Icons.circle), findsOneWidget);
    // 三条连接线：前两条填满、最后一条空置
    final fills = tester
        .widgetList<AnimatedAlign>(
          find.descendant(
            of: find.byType(StepProgress),
            matching: find.byType(AnimatedAlign),
          ),
        )
        .map((a) => a.widthFactor)
        .toList();
    expect(fills, [1.0, 1.0, 0.0]);
    // 圆点颜色：已完成与当前步品牌蓝，仅未来步骤弱化
    final dots = tester
        .widgetList<AnimatedContainer>(_dotContainers())
        .map((c) => (c.decoration! as BoxDecoration).color)
        .toList();
    expect(dots.length, 4);
    expect(dots[0], AppTheme.primaryBlue);
    expect(dots[1], AppTheme.primaryBlue);
    expect(dots[2], AppTheme.primaryBlue);
    expect(dots[3], isNot(AppTheme.primaryBlue));
  });

  testWidgets('异常终态：最后一步红色并整体走完', (tester) async {
    await tester.pumpWidget(
      _host(
        StepProgress(
          labels: const ['报修', '接单', '确认', '已关闭'],
          currentStep: 3,
          abnormalLast: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dots = tester
        .widgetList<AnimatedContainer>(_dotContainers())
        .map((c) => (c.decoration! as BoxDecoration).color)
        .toList();
    expect(dots.last, AppTheme.errorRed);
    // 全部步骤视为已过：四个勾、无圆点
    expect(find.byIcon(Icons.check), findsNWidgets(4));
    expect(find.byIcon(Icons.circle), findsNothing);
  });
}
