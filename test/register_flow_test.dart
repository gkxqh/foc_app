import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/core/constants/api_constants.dart';
import 'package:foc_app/models/user_model.dart';
import 'package:foc_app/providers/auth_provider.dart';
import 'package:foc_app/views/auth/complete_profile_page.dart';
import 'package:foc_app/views/auth/register_page.dart';
import 'package:provider/provider.dart';

Widget _wrap(Widget child, {AuthProvider? auth}) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth ?? AuthProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('RegisterPage 渲染：手机号/验证码输入与注册按钮', (tester) async {
    await tester.pumpWidget(_wrap(const RegisterPage()));
    await tester.pumpAndSettle();

    expect(find.text('创建云上飞扬账号'), findsOneWidget);
    expect(find.text('手机号码'), findsOneWidget);
    expect(find.text('短信验证码'), findsOneWidget);
    expect(find.text('注册并登录'), findsOneWidget);
    expect(find.text('返回登录'), findsOneWidget);
    // 发送按钮存在且未倒计时时可点
    expect(find.text('发送'), findsOneWidget);
  });

  testWidgets('RegisterPage 手机号非法时点发送不触发倒计时', (tester) async {
    await tester.pumpWidget(_wrap(const RegisterPage()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '手机号码'),
      '123',
    );
    await tester.tap(find.text('发送'));
    await tester.pump();

    expect(find.text('请输入正确的11位手机号码'), findsOneWidget);
    // 倒计时未启动，发送按钮仍可点
    expect(find.text('发送'), findsOneWidget);
  });

  testWidgets('CompleteProfilePage 渲染：昵称/校区默认值与跳过', (tester) async {
    final auth = AuthProvider();
    auth.setUserForTest(
      UserModel(
        uid: '1',
        id: '1',
        phone: '19000000000',
        campus: '江安',
        nickname: '',
      ),
    );    await tester.pumpWidget(_wrap(const CompleteProfilePage(), auth: auth));
    await tester.pumpAndSettle();

    expect(find.text('完善资料'), findsOneWidget);
    expect(find.text('用户昵称'), findsOneWidget);
    expect(find.text('所在校区'), findsOneWidget);
    expect(find.text('江安'), findsOneWidget);
    expect(find.text('保存并进入'), findsOneWidget);
    expect(find.text('跳过'), findsOneWidget);

    // 跳过：一路退回（此处仅根路由，popUntil 结束即停在首页桩）
    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();
  });

  testWidgets('CompleteProfilePage 昵称为空时保存被拦截', (tester) async {
    final auth = AuthProvider();
    auth.setUserForTest(UserModel(
      uid: '1',
      id: '1',
      phone: '19000000000',
      campus: '江安',
    ));
    await tester.pumpWidget(_wrap(const CompleteProfilePage(), auth: auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存并进入'));
    await tester.pump();

    expect(find.text('昵称不能为空'), findsOneWidget);
  });

  test('ApiConstants 注册端点路径与服务端文件名一致', () {
    expect(ApiConstants.phoneRegSend, '/v1/user/phoneregsend');
    expect(ApiConstants.phoneRegister, '/v1/user/phoneregister');
  });
}
