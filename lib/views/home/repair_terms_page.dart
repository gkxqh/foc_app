import 'package:flutter/material.dart';

import '../common/responsive_center.dart';

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/service_texts.dart';
import '../../providers/config_provider.dart';
import 'submit_ticket_page.dart';

class RepairTermsPage extends StatefulWidget {
  const RepairTermsPage({super.key});

  @override
  State<RepairTermsPage> createState() => _RepairTermsPageState();
}

class _RepairTermsPageState extends State<RepairTermsPage> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScroll();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    _checkScroll();
  }

  void _checkScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // 如果内容未超出视口高度，或已滑动到底部附近（20px 容差）
    if (pos.maxScrollExtent <= 20 || pos.pixels >= pos.maxScrollExtent - 20) {
      if (!_hasScrolledToBottom) {
        setState(() {
          _hasScrolledToBottom = true;
        });
      }
    }
  }

  void _onCheckboxChanged(bool? value) {
    if (!_hasScrolledToBottom) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('看都没看完点什么点(#`Д´)ﾉ'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _agreed = value ?? false;
    });
  }

  void _proceedToSubmit() {
    if (!_agreed) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SubmitTicketPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final config = context.watch<ConfigProvider>();
    final tips = config.globalTips.isNotEmpty
        ? config.globalTips
        : ServiceTexts.fallbackRepairTerms;

    return Scaffold(
      appBar: AppBar(title: const Text('报修须知与服务条款')),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部提示条
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 10,
              ),
              color: AppTheme.primaryBlue.withValues(alpha: 0.08),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '报修前请务必仔细阅读以下服务须知与免责条款',
                      style: AppText.captionSm.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 条款正文滚动区（滚动到底检测由 _scrollController 监听统一负责）
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: ResponsiveCenter(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: MarkdownBody(
                      data: tips,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        p: AppText.body.copyWith(
                          height: 1.6,
                          color: colorScheme.onSurface,
                        ),
                        listBullet: AppText.body.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 底部操作区
            Material(
              color: theme.cardColor,
              elevation: 4,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      value: _agreed,
                      onChanged: _onCheckboxChanged,
                      title: Text(
                        '我已阅读并同意上述报修须知与服务条款',
                        style: AppText.caption.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _agreed ? _proceedToSubmit : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: colorScheme.onSurface
                              .withValues(alpha: 0.12),
                          disabledForegroundColor: colorScheme.onSurface
                              .withValues(alpha: 0.38),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: Text('我已知晓并同意，开始报修', style: AppText.titleSm),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
