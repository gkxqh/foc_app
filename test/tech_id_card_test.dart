import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/models/user_model.dart';
import 'package:foc_app/providers/auth_provider.dart';
import 'package:foc_app/views/common/flip_card.dart';
import 'package:foc_app/views/home/tech_id_card_page.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

// 卡面按宽高比 0.615 定版式，测试用固定尺寸画布验证渲染内容
final _demoUser = UserModel(
  uid: 'T2024',
  nickname: '小飞',
  campus: '江安',
  role: 'technician',
);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

double _scrollOffset(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .pixels;

void main() {
  testWidgets('正面渲染俱乐部名、职务、姓名/校区信息栏与编号', (tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 340,
          height: 340 / 0.615,
          child: TechIdCardFront(user: _demoUser),
        ),
      ),
    );
    // 推进 700ms：PopIn 弹入与内容交错入场（最慢 320+55*6=650ms）播完
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('飞扬俱乐部'), findsOneWidget);
    expect(find.text('技 术 员'), findsOneWidget);
    expect(find.text('姓名'), findsOneWidget);
    expect(find.text('小飞'), findsOneWidget);
    expect(find.text('校区'), findsOneWidget);
    expect(find.text('江安'), findsOneWidget);
    expect(find.text('No.T2024'), findsOneWidget);
  });

  testWidgets('背面渲染二维码与维修履历数据（数字滚动到位）', (tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 340,
          height: 340 / 0.615,
          child: TechIdCardBack(
            user: _demoUser,
            stats: const TechRepairStats(
              doneCount: 36,
              firstDate: '2024-10-01',
            ),
          ),
        ),
      ),
    );
    // CountUpText 数字滚动 1200ms 走完后再断言终值
    await tester.pump(const Duration(milliseconds: 1300));

    expect(find.byType(QrImageView), findsOneWidget);
    // 二维码载荷为纯文本身份信息，任何扫码器可读、与卡面比对核验
    expect(techIdQrPayload(_demoUser), '云上飞扬技术员证\n工号 T2024\n姓名 小飞\n校区 江安');
    expect(find.text('FEIYANG CLUB'), findsOneWidget);
    expect(find.text('扫码识别技术员身份'), findsOneWidget);
    expect(find.text('维修履历'), findsOneWidget);
    expect(find.text('初次接单'), findsOneWidget);
    expect(find.text('2024-10-01'), findsOneWidget);
    expect(find.text('累计维修'), findsOneWidget);
    expect(find.text('36'), findsOneWidget);
  });

  testWidgets('背面无履历数据时显示寄语，不显示履历数据项', (tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 340,
          height: 340 / 0.615,
          child: TechIdCardBack(user: _demoUser, stats: null),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('轻装上阵，未来可期'), findsOneWidget);
    expect(find.text('初次接单'), findsNothing);
    expect(find.text('累计维修'), findsNothing);
  });

  testWidgets('按住卡片上缘小步拖动：顶边下压、页面不滚动、不触发翻转', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 600));
    final auth = AuthProvider()..setUserForTest(_demoUser);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: TechIdCardPage()),
      ),
    );
    // 推进入场动画播完
    await tester.pump(const Duration(milliseconds: 700));

    final offsetBefore = _scrollOffset(tester);
    final restRect = tester.getRect(find.byType(FlipCard));

    // 模拟真机连续手指：每步 12px（小于拖拽容差 18px），从卡心上方
    // 按住向上拖。触点一侧应被"按下"——透视投影中后退的一侧向卡心
    // 收缩，顶边应向下（卡心方向）移动；若旋转符号反了会变成对角
    // （底边）下沉、顶边反而翘起放大，该断言可捕获。
    final cardCenter = tester.getCenter(find.byType(FlipCard));
    final gesture = await tester.startGesture(cardCenter - const Offset(0, 80));
    await tester.pump(const Duration(milliseconds: 80));
    for (var i = 0; i < 15; i++) {
      await gesture.moveBy(const Offset(0, -12));
      await tester.pump(const Duration(milliseconds: 30));
    }

    expect(_scrollOffset(tester), offsetBefore, reason: '按住卡片拖动页面不应滚动');
    expect(
      tester.getRect(find.byType(FlipCard)).top,
      greaterThan(restRect.top + 4.0),
      reason: '按住上缘时顶边应向卡心收缩（下压），而非反向翘起',
    );

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 500));
    // 松手后未翻面（拖动不属于轻点）
    expect(find.text('轻触卡片查看背面'), findsOneWidget);
  });

  testWidgets('对照组：在卡片外的页面留白处小步拖动，页面正常滚动', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 600));
    final auth = AuthProvider()..setUserForTest(_demoUser);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: TechIdCardPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    // 左侧留白（页面水平 padding 内）起点，小步向上拖动应驱动滚动
    final gesture = await tester.startGesture(const Offset(8, 400));
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 15; i++) {
      await gesture.moveBy(const Offset(0, -12));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));

    expect(_scrollOffset(tester), greaterThan(0), reason: '卡片外拖动页面应正常滚动');
  });
}
