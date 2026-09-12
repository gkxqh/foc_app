import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/main.dart';
import 'package:foc_app/providers/auth_provider.dart';
import 'package:foc_app/providers/config_provider.dart';
import 'package:foc_app/providers/ticket_provider.dart';
import 'package:foc_app/providers/update_provider.dart';
import 'package:foc_app/views/activity/number_page.dart';
import 'package:foc_app/views/home/home_page.dart';
import 'package:foc_app/views/home/ticket_detail_view.dart';
import 'package:foc_app/models/ticket_model.dart';
import 'package:foc_app/views/profile/about_page.dart';
import 'package:foc_app/views/profile/history_page.dart';
import 'package:provider/provider.dart';

/// 横屏/折叠屏适配回归：在各关键窗口尺寸下 pump 真实页面。
/// 任何 RenderFlex overflow（黄黑条纹）都会以异常形式冒出并使测试失败。
///
/// 覆盖尺寸：手机竖/横、折叠屏外屏（窄分屏）、折叠屏内屏展开、平板竖持。
/// 阈值语义：≥600 切 NavigationRail + 内容居中限宽；≥720 切列表-详情双栏。
void main() {
  const sizes = <String, Size>{
    'phone-portrait': Size(390, 844),
    'phone-landscape': Size(844, 390),
    'fold-cover': Size(280, 653),
    'fold-inner': Size(841, 673),
    'tablet-portrait': Size(800, 1280),
  };

  void setView(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> settle(WidgetTester tester) async {
    // 固定时长推进而非 pumpAndSettle：启动链路含网络请求与渐隐计时器，
    // 网络在测试环境快速失败，固定 pump 足以驱动 LaunchGate 进入主骨架
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  for (final entry in sizes.entries) {
    testWidgets('app shell smoke @ ${entry.key} ${entry.value}', (
      tester,
    ) async {
      setView(tester, entry.value);
      await tester.pumpWidget(const FeiyangApp());
      await settle(tester);
    });
  }

  Widget host(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ChangeNotifierProvider<ConfigProvider>(create: (_) => ConfigProvider()),
      ChangeNotifierProvider<TicketProvider>(create: (_) => TicketProvider()),
      ChangeNotifierProvider<UpdateProvider>(create: (_) => UpdateProvider()),
    ],
    child: MaterialApp(home: child),
  );

  for (final entry in sizes.entries) {
    testWidgets('home smoke @ ${entry.key}', (tester) async {
      setView(tester, entry.value);
      await tester.pumpWidget(
        host(const HomePage()),
      );
      await settle(tester);
    });

    testWidgets('about smoke @ ${entry.key}', (tester) async {
      setView(tester, entry.value);
      await tester.pumpWidget(host(const AboutPage()));
      await settle(tester);
    });

    testWidgets('number smoke @ ${entry.key}', (tester) async {
      setView(tester, entry.value);
      await tester.pumpWidget(
        MaterialApp(
          home: const NumberPage(luckyNum: '0086', isWinner: true),
        ),
      );
      await settle(tester);
    });

    testWidgets('history smoke @ ${entry.key}', (tester) async {
      setView(tester, entry.value);
      await tester.pumpWidget(host(const HistoryPage()));
      await settle(tester);
    });

    testWidgets('ticket detail smoke @ ${entry.key}', (tester) async {
      setView(tester, entry.value);
      await tester.pumpWidget(
        host(TicketDetailView(ticket: _fakeTicket)),
      );
      await settle(tester);
    });
  }
}

final TicketModel _fakeTicket = TicketModel(
  id: 'T-2026-0001',
  deviceType: '笔记本',
  faultType: '系统软件问题/蓝屏死机等极端超长故障类型用以压测换行',
  repairDescription: '一台描述特别特别特别长的机器，用来压测折行与省略号是否生效，'
      '重复一遍以加长文本：一台描述特别特别特别长的机器。',
  repairStatus: 'Repairing',
  repairImageUrl: 'https://example.com/fault.png',
  campus: '江安校区超级超级长的校区名压测',
  computerBrand: '机械革命/Thunderobot 超长品牌压测',
  createTime: '2026-09-13 12:00',
  phone: '13800138000',
  qqNumber: 'qq|123456789',
  warrantyStatus: 'under',
  model: '联想小新Pro 16 2024 / 华硕天选7 Pro Max 超长型号压测',
  purchaseDate: '2024-09-01',
  transcode: '654321',
);
