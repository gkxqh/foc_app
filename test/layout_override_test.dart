import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/core/layout/window_class.dart';

/// 断点函数在各窗口宽度 × 布局覆盖模式下的取值。
/// 未挂 LayoutOverride 时退回纯宽度判断（既有页面测试不受影响）。
void main() {
  Future<({bool side, bool twoPane, WindowSizeClass cls})> probe(
    WidgetTester tester, {
    required double width,
    LayoutMode? mode,
  }) async {
    late bool side;
    late bool twoPane;
    late WindowSizeClass cls;
    Widget child = Builder(
      builder: (context) {
        side = useSideNavigation(context);
        twoPane = useTwoPane(context);
        cls = windowClassOf(context);
        return const SizedBox.shrink();
      },
    );
    if (mode != null) {
      child = LayoutOverride(mode: mode, child: child);
    }
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: child,
      ),
    );
    return (side: side, twoPane: twoPane, cls: cls);
  }

  testWidgets('无覆盖：按宽度阈值判断（600 侧栏 / 720 双栏）', (tester) async {
    var r = await probe(tester, width: 390);
    expect((r.side, r.twoPane, r.cls), (false, false, WindowSizeClass.compact));

    r = await probe(tester, width: 650);
    expect((r.side, r.twoPane, r.cls), (true, false, WindowSizeClass.medium));

    r = await probe(tester, width: 1000);
    expect((r.side, r.twoPane, r.cls), (true, true, WindowSizeClass.expanded));
  });

  testWidgets('auto 覆盖等价于无覆盖', (tester) async {
    final r = await probe(tester, width: 1000, mode: LayoutMode.auto);
    expect((r.side, r.twoPane), (true, true));
  });

  testWidgets('强制手机布局：宽屏也走底部导航 + 单栏', (tester) async {
    final r = await probe(tester, width: 1200, mode: LayoutMode.compact);
    expect((r.side, r.twoPane, r.cls), (false, false, WindowSizeClass.compact));
  });

  testWidgets('强制侧栏：有侧边导航但不双栏', (tester) async {
    final r = await probe(tester, width: 1200, mode: LayoutMode.medium);
    expect((r.side, r.twoPane, r.cls), (true, false, WindowSizeClass.medium));
  });

  testWidgets('强制双栏：宽度足够时双栏，不足 600 时退回单栏但保留侧栏', (tester) async {
    var r = await probe(tester, width: 650, mode: LayoutMode.expanded);
    expect((r.side, r.twoPane, r.cls), (true, true, WindowSizeClass.expanded));

    r = await probe(tester, width: 390, mode: LayoutMode.expanded);
    expect(r.side, isTrue);
    expect(r.twoPane, isFalse);
  });
}
