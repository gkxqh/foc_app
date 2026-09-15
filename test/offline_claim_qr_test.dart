import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/models/ticket_model.dart';
import 'package:foc_app/models/user_model.dart';
import 'package:foc_app/providers/auth_provider.dart';
import 'package:foc_app/views/home/ticket_detail_view.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

TicketModel _ticket({required String campus, String status = 'Pending'}) {
  return TicketModel(
    id: '3301',
    createTime: '2026-09-15 10:00:00',
    deviceType: '笔记本',
    computerBrand: '联想 Lenovo',
    faultType: '设备清灰',
    repairDescription: '风扇异响',
    repairImageUrl: '',
    repairStatus: status,
    campus: campus,
    orderHash: '9f86d081884c7d65',
    transcode: '483920',
  );
}

Widget _wrap(TicketModel ticket, {bool tech = false}) {
  final auth = AuthProvider();
  auth.setUserForTest(
    UserModel(
      uid: '1',
      id: '1',
      phone: '19000000000',
      nickname: '测试用户',
      role: tech ? 'technician' : 'user',
    ),
  );
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp(
      home: Scaffold(body: TicketDetailView(ticket: ticket)),
    ),
  );
}

void main() {
  // StepProgress 在待接单状态有循环呼吸动画，pumpAndSettle 永不停止，
  // 统一用定帧 pump 驱动
  Future<void> render(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.pump();
  }

  testWidgets('线下待接单工单向用户展示现场接单二维码', (tester) async {
    await render(tester, _wrap(_ticket(campus: '线下')));

    expect(find.text('现场接单二维码'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('复制接单码'), findsOneWidget);

    await tester.tap(find.text('复制接单码'));
    await tester.pump();
    expect(find.text('接单码已复制，可发给技术员手动输码'), findsOneWidget);
  });

  testWidgets('普通校区工单不显示接单二维码', (tester) async {
    await render(tester, _wrap(_ticket(campus: '江安')));

    expect(find.text('现场接单二维码'), findsNothing);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('线下工单被接单后二维码消失', (tester) async {
    await render(tester, _wrap(_ticket(campus: '线下', status: 'Repairing')));

    expect(find.text('现场接单二维码'), findsNothing);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('技术员视角不显示用户接单二维码', (tester) async {
    await render(tester, _wrap(_ticket(campus: '线下'), tech: true));

    expect(find.text('现场接单二维码'), findsNothing);
    expect(find.byType(QrImageView), findsNothing);
  });
}
