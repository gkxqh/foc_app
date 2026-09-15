import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/models/ticket_model.dart';
import 'package:foc_app/models/user_model.dart';
import 'package:foc_app/providers/auth_provider.dart';
import 'package:foc_app/providers/config_provider.dart';
import 'package:foc_app/providers/ticket_provider.dart';
import 'package:foc_app/providers/update_provider.dart';
import 'package:foc_app/views/home/ticket_detail_view.dart';
import 'package:provider/provider.dart';

/// 工单双向确认的中间状态按钮冒烟测试：
/// UserConfirming/TechConfirming 下用户与技术员各自应有可点确认或灰置等待提示，
/// 与小程序端 ticketDetail 的按钮行为对齐。
void main() {
  TicketModel ticketWithStatus(String status) => TicketModel(
    id: 'T-2026-0001',
    deviceType: '笔记本',
    faultType: '系统软件问题',
    repairDescription: '开不了机',
    repairStatus: status,
    repairImageUrl: 'https://example.com/fault.png',
    campus: '江安校区',
    computerBrand: '联想',
    createTime: '2026-09-13 12:00',
    phone: '13800138000',
    qqNumber: '123456789',
    warrantyStatus: 'under',
    model: '联想小新Pro 16 2024',
    purchaseDate: '2024-09-01',
    transcode: '654321',
  );

  Widget host(TicketModel ticket, {required String role}) {
    final auth = AuthProvider();
    auth.setUserForTest(UserModel(role: role, nickname: '测试用户'));
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<ConfigProvider>(create: (_) => ConfigProvider()),
        ChangeNotifierProvider<TicketProvider>(create: (_) => TicketProvider()),
        ChangeNotifierProvider<UpdateProvider>(create: (_) => UpdateProvider()),
      ],
      child: MaterialApp(home: TicketDetailView(ticket: ticket)),
    );
  }

  Future<void> pumpDetail(
    WidgetTester tester,
    TicketModel ticket, {
    required String role,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(host(ticket, role: role));
    // 固定时长推进：视图初始化含网络请求，测试环境快速失败，避免 pumpAndSettle 卡计时器
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  /// 视图主体是懒加载 ListView，底部操作区需滚入视口后才会构建
  Future<void> scrollToText(WidgetTester tester, String text) async {
    await tester.dragUntilVisible(
      find.text(text),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pump();
  }

  bool elevatedButtonEnabled(WidgetTester tester, String label) {
    final finder = find.ancestor(
      of: find.text(label),
      matching: find.byType(ElevatedButton),
    );
    return tester.widget<ElevatedButton>(finder).onPressed != null;
  }

  testWidgets('技术员在等待技术员确认时可见可点的「确认维修完成」', (tester) async {
    await pumpDetail(
      tester,
      ticketWithStatus('TechConfirming'),
      role: 'technician',
    );
    await scrollToText(tester, '确认维修完成');
    expect(find.text('确认维修完成'), findsOneWidget);
    expect(elevatedButtonEnabled(tester, '确认维修完成'), isTrue);
    // 回归：凭证上传入口与强制关闭保留，维修中专属按钮不出现
    expect(find.text('上传维修完成凭证图片'), findsOneWidget);
    expect(find.text('请求用户确认完成'), findsNothing);
  });

  testWidgets('技术员在等待用户确认时仅见灰置「等待用户确认」', (tester) async {
    await pumpDetail(
      tester,
      ticketWithStatus('UserConfirming'),
      role: 'technician',
    );
    await scrollToText(tester, '等待用户确认');
    expect(find.text('等待用户确认'), findsOneWidget);
    expect(elevatedButtonEnabled(tester, '等待用户确认'), isFalse);
    expect(find.text('请求用户确认完成'), findsNothing);
  });

  testWidgets('用户在等待用户确认时可见可点的「确认电脑维修完成」', (tester) async {
    await pumpDetail(
      tester,
      ticketWithStatus('UserConfirming'),
      role: 'user',
    );
    await scrollToText(tester, '确认电脑维修完成');
    expect(find.text('确认电脑维修完成'), findsOneWidget);
    expect(elevatedButtonEnabled(tester, '确认电脑维修完成'), isTrue);
  });

  testWidgets('用户在等待技术员确认时仅见灰置「等待技术员确认」', (tester) async {
    await pumpDetail(
      tester,
      ticketWithStatus('TechConfirming'),
      role: 'user',
    );
    await scrollToText(tester, '等待技术员确认');
    expect(find.text('等待技术员确认'), findsOneWidget);
    expect(elevatedButtonEnabled(tester, '等待技术员确认'), isFalse);
    expect(find.text('确认电脑维修完成'), findsNothing);
  });

  testWidgets('回归：维修中状态两侧确认按钮保持不变', (tester) async {
    await pumpDetail(tester, ticketWithStatus('Repairing'), role: 'technician');
    await scrollToText(tester, '请求用户确认完成');
    expect(find.text('请求用户确认完成'), findsOneWidget);
    expect(find.text('无需确认直接结束工单'), findsOneWidget);

    await pumpDetail(tester, ticketWithStatus('Repairing'), role: 'user');
    await scrollToText(tester, '确认电脑维修完成');
    expect(find.text('确认电脑维修完成'), findsOneWidget);
    expect(elevatedButtonEnabled(tester, '确认电脑维修完成'), isTrue);
  });
}
