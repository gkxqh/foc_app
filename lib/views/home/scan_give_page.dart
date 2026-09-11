import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ticket_provider.dart';

/// 技术员扫码接单页
/// 识别两类二维码：
/// 1. 服务端 getTicket 下发的 `[give];单号;order_hash` 接单码
/// 2. 工单详情页分享的 "单号+6位tvcode" 转单文本
class ScanGivePage extends StatefulWidget {
  const ScanGivePage({super.key});

  @override
  State<ScanGivePage> createState() => _ScanGivePageState();
}

class _ScanGivePageState extends State<ScanGivePage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _submitting = false;
  String? _resultMessage;
  bool _success = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_submitting) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    // 识别到码立即停相机：二维码留在取景框内会反复触发 onDetect，形成请求循环
    await _controller.stop();
    if (!mounted) return;

    setState(() => _submitting = true);
    final ticketProvider = context.read<TicketProvider>();
    final err = await ticketProvider.transferTicket(code);

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _success = err == null;
      _resultMessage = err ?? '接单成功！';
    });

    if (err == null) {
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        ticketProvider.fetchTickets(role: auth.user!.role, uid: auth.user!.uid);
      }
      // 成功后稍作停留让用户看到结果，再返回上一页
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.pop(context, true);
    }
  }

  // 失败后允许手动恢复取景重扫
  Future<void> _resumeScan() async {
    setState(() {
      _resultMessage = null;
      _success = false;
    });
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫码接单')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleBarcode,
                ),
                if (_submitting)
                  Container(
                    color: Colors.black38,
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _success
                ? AppTheme.accentColor.withValues(alpha: 0.12)
                : (_resultMessage == null
                    ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
                    : Colors.orange.withValues(alpha: 0.12)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _resultMessage ?? '对准工单二维码即可接单，支持服务端接单码与转单文本',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: _resultMessage == null ? Colors.grey : null,
                    fontWeight: _resultMessage == null ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                // 失败后相机已暂停，提供手动重扫入口
                if (!_success && _resultMessage != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _resumeScan,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('重新扫描'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
