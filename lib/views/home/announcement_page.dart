import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../core/theme/app_theme.dart';
import '../common/page_insets.dart';

/// 公告与服务须知页：整页呈现替代此前的弹窗，
/// 避免弹窗多层内边距的局促观感；长公告随页面自然滚动。
class AnnouncementPage extends StatelessWidget {
  final String body;

  const AnnouncementPage({super.key, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('公告与服务须知')),
      body: SingleChildScrollView(
        padding: pageListPadding(context),
        child: Markdown(
          data: body,
          selectable: true,
          // 外层 SingleChildScrollView 提供滚动；Markdown 若再渲染为视口，
          // 会因无限高度约束直接布局崩溃（页面空白），必须渲染为 Column
          noScroll: true,
          // 横向留白交给页面级 pageListPadding，Markdown 自身归零避免叠加
          padding: EdgeInsets.zero,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: AppText.body.copyWith(
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            listBullet: AppText.body.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            h1: AppText.title,
            h2: AppText.title,
            h3: AppText.titleSm,
          ),
        ),
      ),
    );
  }
}
