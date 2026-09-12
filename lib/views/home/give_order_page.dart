import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ticket_provider.dart';
import '../common/app_snackbar.dart';
import '../common/page_insets.dart';

class GiveOrderPage extends StatefulWidget {
  final String? transcodeToShare; // 如果传入，则展示该转单码和二维码

  const GiveOrderPage({super.key, this.transcodeToShare});

  @override
  State<GiveOrderPage> createState() => _GiveOrderPageState();
}

class _GiveOrderPageState extends State<GiveOrderPage> {
  final TextEditingController _codeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.transcodeToShare != null) {
      _codeController.text = widget.transcodeToShare!;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitTransfer() async {
    if (_isSubmitting) return;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      showAppSnackBar(context, '请填写完整的转单码', type: SnackBarType.error);
      return;
    }

    setState(() => _isSubmitting = true);
    final ticketProvider = context.read<TicketProvider>();
    final authProvider = context.read<AuthProvider>();

    final err = await ticketProvider.transferTicket(code);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (err == null) {
      HapticFeedback.mediumImpact();
      showAppSnackBar(context, '接单成功！', type: SnackBarType.success);
      if (authProvider.user != null) {
        ticketProvider.fetchTickets(
          role: authProvider.user!.role,
          uid: authProvider.user!.uid,
        );
      }
      Navigator.pop(context, true);
    } else {
      showAppSnackBar(context, '接单失败: $err', type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isShowingShare =
        widget.transcodeToShare != null && widget.transcodeToShare!.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final qrColor = isDark ? Colors.white : Colors.black87;
    final qrEyeColor = isDark ? Colors.white : AppTheme.primaryBlue;

    return Scaffold(
      appBar: AppBar(title: Text(isShowingShare ? '转单凭证' : '手动接单')),
      body: SingleChildScrollView(
        padding: pageListPadding(context, horizontal: 24, top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isShowingShare) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    children: [
                      Text(
                        '请其他技术员扫码或输入转单码接单',
                        style: AppText.body.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      QrImageView(
                        data: widget.transcodeToShare!,
                        version: QrVersions.auto,
                        size: 200.0,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: qrEyeColor,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: qrColor,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SelectableText(
                        '转单码：${widget.transcodeToShare}',
                        style: AppText.bodyLg.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: widget.transcodeToShare!),
                          );
                          HapticFeedback.selectionClick();
                          showAppSnackBar(
                            context,
                            '转单码已复制到剪贴板',
                            type: SnackBarType.error,
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('复制转单码'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Text('技术员接单', style: AppText.title),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '如需接收其他技术员转让的工单，请在下方粘贴或输入转单码：',
                style: AppText.caption.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: '转单码',
                  hintText: '单号',
                  prefixIcon: Icon(Icons.qr_code_2_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitTransfer,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.handyman_rounded),
                label: const Text('确认接单'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
