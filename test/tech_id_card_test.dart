import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/models/user_model.dart';
import 'package:foc_app/views/home/tech_id_card_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

// 卡面按宽高比 0.615 定版式，测试用固定尺寸画布验证渲染内容
final _demoUser = UserModel(
  uid: 'T2024',
  nickname: '小飞',
  campus: '江安',
  role: 'technician',
);

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

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
    await tester.pump();

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
            stats: const TechRepairStats(doneCount: 36, firstDate: '2024-10-01'),
          ),
        ),
      ),
    );
    // CountUpText 数字滚动 1200ms 走完后再断言终值
    await tester.pump(const Duration(milliseconds: 1300));

    expect(find.byType(QrImageView), findsOneWidget);
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
    await tester.pump();

    expect(find.text('轻装上阵，未来可期'), findsOneWidget);
    expect(find.text('初次接单'), findsNothing);
    expect(find.text('累计维修'), findsNothing);
  });
}
