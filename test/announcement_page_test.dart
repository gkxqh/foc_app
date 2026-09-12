import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/views/home/announcement_page.dart';

void main() {
  testWidgets('公告页渲染标题栏与 Markdown 正文', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AnnouncementPage(body: '# 公告标题\n\n正文第一段测试内容。\n\n- 列表项一\n- 列表项二'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('公告与服务须知'), findsOneWidget);
    expect(find.text('正文第一段测试内容。'), findsOneWidget);
    expect(find.text('列表项一'), findsOneWidget);
    final rect = tester.getRect(find.byType(Markdown));
    expect(rect.height, greaterThan(0));
    expect(rect.width, greaterThan(0));
  });

  testWidgets('空公告内容时不抛异常', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AnnouncementPage(body: '')));
    await tester.pumpAndSettle();
    expect(find.text('公告与服务须知'), findsOneWidget);
  });
}
