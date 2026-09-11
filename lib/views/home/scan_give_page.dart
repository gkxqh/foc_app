import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ticket_provider.dart';

import 'give_order_page.dart';

/// 技术员扫码接单页
/// 识别两类二维码：
/// 1. 服务端 getTicket 下发的 `[give];单号;order_hash` 接单码
/// 2. 工单详情页分享的 "单号+6位tvcode" 转单文本
/// 支持实时相机扫描、相册图片二维码识别与手动输入转单码
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

  Future<void> _processCode(String code) async {
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

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_submitting) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    // 识别到码立即停相机：二维码留在取景框内会反复触发 onDetect，形成请求循环
    await _controller.stop();
    if (!mounted) return;

    await _processCode(code);
  }

  // 从相册选取图片并识别二维码
  Future<void> _pickImageFromGallery() async {
    if (_submitting) return;
    await _controller.stop();
    if (!mounted) return;

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        // 用户取消选图，恢复相机取景
        _resumeScan();
        return;
      }

      setState(() {
        _submitting = true;
        _resultMessage = '正在解析图片中的二维码...';
      });

      final BarcodeCapture? capture = await _controller.analyzeImage(
        image.path,
      );
      final code = capture?.barcodes.firstOrNull?.rawValue;

      if (code == null || code.isEmpty) {
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _success = false;
          _resultMessage = '未能从所选图片中识别到有效二维码';
        });
        return;
      }

      await _processCode(code);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _success = false;
        _resultMessage = '识别图片失败: $e';
      });
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

  // 打开手动输码页面，成功接单则直接回退首页
  Future<void> _openManualInput() async {
    await _controller.stop();
    if (!mounted) return;
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const GiveOrderPage()),
    );
    if (!mounted) return;
    if (success == true) {
      Navigator.pop(context, true);
    } else {
      _resumeScan();
    }
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
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: _success
                ? AppTheme.accentColor.withValues(alpha: 0.12)
                : (_resultMessage == null
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35)
                      : Colors.orange.withValues(alpha: 0.12)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _resultMessage ?? '将取景框对准工单二维码即可自动接单',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: _resultMessage == null
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : null,
                    fontWeight: _resultMessage == null
                        ? FontWeight.normal
                        : FontWeight.bold,
                  ),
                ),
                if (_resultMessage == null) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickImageFromGallery,
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: const Text('相册导入'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      OutlinedButton.icon(
                        onPressed: _openManualInput,
                        icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                        label: const Text('手动输码'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // 失败后相机已暂停，提供手动重扫、相册重试或手动输码入口
                if (!_success && _resultMessage != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _resumeScan,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('重新扫描'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _pickImageFromGallery,
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: const Text('相册'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _openManualInput,
                        icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                        label: const Text('输码'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
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
