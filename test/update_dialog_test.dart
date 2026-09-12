import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/models/app_update_model.dart';
import 'package:foc_app/providers/update_provider.dart';
import 'package:foc_app/views/common/update_dialog.dart';
import 'package:provider/provider.dart';

/// 用真实的 v1.1.0 Release body 渲染更新弹窗，
/// 复现真机「只有暗色屏障、弹窗内容不可见」的问题。
void main() {
  Future<UpdateProvider> seedAndOpenDialog(
    WidgetTester tester, {
    required String changelog,
  }) async {
    final update = UpdateProvider();
    update.debugSeed(
      status: UpdateStatus.available,
      currentVersion: '1.0.9',
      info: AppUpdateInfo(
        tagName: 'v1.1.0',
        version: '1.1.0',
        releaseName: 'v1.1.0',
        changelog: changelog,
        downloadUrl: 'https://example.com/foc_app_v1.1.0_arm64.apk',
        fileName: 'foc_app_v1.1.0_arm64.apk',
        downloadSize: 36700160,
        htmlUrl: 'https://example.com/releases/tag/v1.1.0',
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<UpdateProvider>.value(
        value: update,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () =>
                      showUpdateDialog(context, fromAutoCheck: true),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return update;
  }

  testWidgets('简单文案：弹窗渲染标题、版本行与操作按钮', (tester) async {
    await seedAndOpenDialog(tester, changelog: '## 更新\n\n- 修复若干问题');

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('最新版本 v1.1.0，当前 v1.0.9'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);
    expect(find.text('以后再说'), findsOneWidget);
    expect(find.text('忽略此版本'), findsOneWidget);
    // 弹窗内容有实际尺寸（不是不可见的零尺寸框）
    final rect = tester.getRect(find.byType(AlertDialog));
    expect(rect.width, greaterThan(100));
    expect(rect.height, greaterThan(100));
  });

  testWidgets('真实 v1.1.0 Release 文案：Markdown 渲染不抛异常且弹窗可见', (tester) async {
    final changelog = File(
      'test/fixtures/release_v1.1.0_body.md',
    ).readAsStringSync();
    // 夹具必须非空，防止静默退化成空内容假通过
    expect(changelog, isNotEmpty);

    await seedAndOpenDialog(tester, changelog: changelog);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);
    final rect = tester.getRect(find.byType(AlertDialog));
    expect(rect.width, greaterThan(100));
    expect(rect.height, greaterThan(100));
    // Markdown 内容在限高区域内正常布局
    final markdownRect = tester.getRect(find.byType(Markdown));
    expect(markdownRect.height, greaterThan(0));
  });
}
