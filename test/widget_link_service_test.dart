import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/services/widget_link_service.dart';

void main() {
  group('WidgetLinkService.parse', () {
    test('扫码链接解析出 /scan 路径', () {
      final r = WidgetLinkService.parse(Uri.parse('focapp://widget/scan'));
      expect(r.path, '/scan');
      expect(r.ticketId, isNull);
    });

    test('工单链接解析出 id 参数', () {
      final r = WidgetLinkService.parse(
        Uri.parse('focapp://widget/ticket?id=20260912'),
      );
      expect(r.path, '/ticket');
      expect(r.ticketId, '20260912');
    });

    test('home 链接仅用于拉起 App', () {
      final r = WidgetLinkService.parse(Uri.parse('focapp://widget/home'));
      expect(r.path, '/home');
    });

    test('报修链接解析出 /report 路径', () {
      final r = WidgetLinkService.parse(Uri.parse('focapp://widget/report'));
      expect(r.path, '/report');
      expect(r.ticketId, isNull);
    });

    test('非 focapp scheme 返回空路径（防外部恶意 URI 误路由）', () {
      final r = WidgetLinkService.parse(Uri.parse('other://widget/scan'));
      expect(r.path, '');
    });

    test('host 不匹配返回空路径', () {
      final r = WidgetLinkService.parse(Uri.parse('focapp://other/scan'));
      expect(r.path, '');
    });

    test('缺少 id 的工单链接返回 null id，由路由层拦截', () {
      final r = WidgetLinkService.parse(Uri.parse('focapp://widget/ticket'));
      expect(r.path, '/ticket');
      expect(r.ticketId, isNull);
    });
  });
}
