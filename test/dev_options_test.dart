import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/core/layout/window_class.dart';
import 'package:foc_app/models/user_model.dart';
import 'package:foc_app/providers/auth_provider.dart';
import 'package:foc_app/providers/dev_options_provider.dart';
import 'package:foc_app/views/profile/developer_options_page.dart';
import 'package:provider/provider.dart';

Widget _host(DevOptionsProvider dev, {UserModel? user}) {
  final auth = AuthProvider();
  auth.setUserForTest(user);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<DevOptionsProvider>.value(value: dev),
    ],
    child: const MaterialApp(home: DeveloperOptionsPage()),
  );
}

void main() {
  group('DevOptionsProvider', () {
    test('直接结束开关默认关闭（偏好键不存在即关闭，覆盖老版本升级场景）', () {
      expect(DevOptionsProvider().directFinishEnabled, isFalse);
    });

    test('切换开关立即通知监听者', () async {
      final dev = DevOptionsProvider();
      var notified = 0;
      dev.addListener(() => notified++);
      await dev.setDirectFinishEnabled(true);
      expect(dev.directFinishEnabled, isTrue);
      expect(notified, 1);
      await dev.setDirectFinishEnabled(false);
      expect(dev.directFinishEnabled, isFalse);
      expect(notified, 2);
    });

    test('load 在无偏好存储时保持默认且不抛异常', () async {
      final dev = DevOptionsProvider();
      await dev.load();
      expect(dev.directFinishEnabled, isFalse);
      expect(dev.layoutMode, LayoutMode.auto);
    });

    test('布局模式默认 auto，切换后通知监听者', () async {
      final dev = DevOptionsProvider();
      expect(dev.layoutMode, LayoutMode.auto);
      var notified = 0;
      dev.addListener(() => notified++);
      await dev.setLayoutMode(LayoutMode.compact);
      expect(dev.layoutMode, LayoutMode.compact);
      expect(notified, 1);
    });
  });

  group('开发者选项页', () {
    testWidgets('渲染实验开关、诊断信息与复制按钮', (tester) async {
      final dev = DevOptionsProvider();
      await tester.pumpWidget(
        _host(
          dev,
          user: UserModel(uid: '42', id: '42', role: 'technician', campus: '江安'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('开发者选项'), findsOneWidget);
      expect(find.text('显示「无需确认直接结束工单」'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
      for (final label in ['版本', '构建模式', '平台', '布局', '登录', 'API 地址']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.textContaining('uid 42'), findsOneWidget);
      expect(find.text('复制诊断信息'), findsOneWidget);
    });

    testWidgets('点击开关切换 Provider 状态', (tester) async {
      final dev = DevOptionsProvider();
      await tester.pumpWidget(_host(dev));
      await tester.pumpAndSettle();

      expect(dev.directFinishEnabled, isFalse);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(dev.directFinishEnabled, isTrue);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
    });

    testWidgets('未登录时诊断信息显示未登录，复制后弹出提示', (tester) async {
      await tester.pumpWidget(_host(DevOptionsProvider()));
      await tester.pumpAndSettle();

      expect(find.text('未登录'), findsOneWidget);
      // 复制按钮位于页面底部，600px 测试视口下需先滚入可见区再点击
      await tester.ensureVisible(find.text('复制诊断信息'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('复制诊断信息'));
      await tester.pump();
      expect(find.text('诊断信息已复制'), findsOneWidget);
    });

    testWidgets('布局模式分段按钮：点「手机」切为强制手机布局', (tester) async {
      final dev = DevOptionsProvider();
      await tester.pumpWidget(_host(dev));
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<LayoutMode>), findsOneWidget);
      expect(dev.layoutMode, LayoutMode.auto);

      await tester.tap(find.text('手机'));
      await tester.pumpAndSettle();

      expect(dev.layoutMode, LayoutMode.compact);
      expect(
        tester
            .widget<SegmentedButton<LayoutMode>>(
              find.byType(SegmentedButton<LayoutMode>),
            )
            .selected,
        {LayoutMode.compact},
      );
    });
  });
}
