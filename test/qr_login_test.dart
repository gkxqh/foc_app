import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/providers/auth_provider.dart';
import 'package:foc_app/services/qr_login_service.dart';
import 'package:foc_app/views/auth/qr_login_page.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _sid = 'a3f1c2d4e5b6978899aabbccddeeff00112233445566778899aabbccddeeff00';

/// 可编排的假服务：createSession 可成功/失败，poll 按序返回预设结果（末项重复）
class _FakeQrLoginService extends QrLoginService {
  _FakeQrLoginService({this.session, this.results = const []});

  QrLoginSession? session;
  List<QrPollResult> results;
  int createCalls = 0;
  int pollCalls = 0;

  @override
  Future<QrLoginSession?> createSession({required String platform}) async {
    createCalls++;
    return session;
  }

  @override
  Future<QrPollResult> poll(QrLoginSession session) async {
    pollCalls++;
    if (results.isEmpty) return const QrPollResult(QrPollStatus.pending);
    final index = pollCalls - 1 < results.length ? pollCalls - 1 : results.length - 1;
    return results[index];
  }
}

QrLoginSession _session() => const QrLoginSession(
  sessionId: _sid,
  pollToken: 'poll',
  expiresIn: Duration(seconds: 120),
);

Widget _host(_FakeQrLoginService service) {
  return ChangeNotifierProvider<AuthProvider>(
    create: (_) => AuthProvider(),
    child: MaterialApp(
      home: QrLoginPage(
        service: service,
        pollInterval: const Duration(milliseconds: 100),
      ),
    ),
  );
}

/// 出码页有 1 秒倒计时与轮询周期定时器，不能 pumpAndSettle；
/// 测试结束前必须卸载页面让定时器随 dispose 取消
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  group('QrLoginCodec', () {
    test('编解码往返', () {
      final payload = QrLoginCodec.buildPayload(_sid);
      expect(payload, '[fylogin];$_sid');
      expect(QrLoginCodec.parseSessionId(payload), _sid);
      expect(QrLoginCodec.isLoginCode(payload), isTrue);
    });

    test('容忍首尾空白', () {
      expect(QrLoginCodec.parseSessionId('  [fylogin];$_sid \n'), _sid);
    });

    test('非登录码一律返回 null（接单码 / 转单码 / 乱码 / 长度或字符不合法）', () {
      expect(QrLoginCodec.parseSessionId('[give];123;abc'), isNull);
      expect(QrLoginCodec.parseSessionId('20260000097654321'), isNull);
      expect(QrLoginCodec.parseSessionId(''), isNull);
      expect(QrLoginCodec.parseSessionId('[fylogin];short'), isNull);
      expect(
        QrLoginCodec.parseSessionId('[fylogin];${_sid.substring(1)}Z'),
        isNull,
      );
      expect(QrLoginCodec.isLoginCode('[give];1;2'), isFalse);
    });
  });

  group('出码页', () {
    testWidgets('创建会话后渲染二维码与等待提示', (tester) async {
      final service = _FakeQrLoginService(session: _session());
      await tester.pumpWidget(_host(service));
      await tester.pump();
      await tester.pump();

      expect(service.createCalls, 1);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.textContaining('等待扫码'), findsOneWidget);
      expect(find.text('扫码登录'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('轮询到已扫码时切换提示文案', (tester) async {
      final service = _FakeQrLoginService(
        session: _session(),
        results: const [QrPollResult(QrPollStatus.pending, scanned: true)],
      );
      await tester.pumpWidget(_host(service));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(service.pollCalls, greaterThanOrEqualTo(1));
      expect(find.text('已扫码，请在手机上点击「允许登录」'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('轮询到过期显示遮罩，点击遮罩重新出码', (tester) async {
      final service = _FakeQrLoginService(
        session: _session(),
        results: const [QrPollResult(QrPollStatus.expired)],
      );
      await tester.pumpWidget(_host(service));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(find.text('二维码已过期'), findsOneWidget);
      expect(find.text('请点击刷新重新生成二维码'), findsOneWidget);

      await tester.tap(find.text('二维码已过期'));
      await tester.pump();
      await tester.pump();
      expect(service.createCalls, 2);
      expect(find.text('二维码已过期'), findsNothing);
      await _teardown(tester);
    });

    testWidgets('对方拒绝时提示并停止轮询', (tester) async {
      final service = _FakeQrLoginService(
        session: _session(),
        results: const [QrPollResult(QrPollStatus.cancelled)],
      );
      await tester.pumpWidget(_host(service));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      final callsAfterCancel = service.pollCalls;

      expect(find.text('对方拒绝了本次登录'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(service.pollCalls, callsAfterCancel);
      await _teardown(tester);
    });

    testWidgets('创建会话失败显示错误与重试入口', (tester) async {
      final service = _FakeQrLoginService(session: null);
      await tester.pumpWidget(_host(service));
      await tester.pump();
      await tester.pump();

      expect(find.text('二维码生成失败，请检查网络后重试'), findsOneWidget);
      expect(find.text('点击重试'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      await _teardown(tester);
    });
  });
}
