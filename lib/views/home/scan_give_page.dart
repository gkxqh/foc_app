import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../services/qr_login_service.dart';
import '../common/confirm_dialog.dart';

import 'give_order_page.dart';

/// 扫码页（技术员「扫码接单」/ 所有用户「扫一扫」共用）
/// 识别三类二维码：
/// 1. 服务端 getTicket 下发的 `[give];单号;order_hash` 接单码（仅技术员）
/// 2. 工单详情页分享的 "单号+6位tvcode" 转单文本（仅技术员）
/// 3. 待登录设备出码页的 `[fylogin];session_id` 登录码（所有已登录用户，确认后授权该设备登录）
/// 支持实时相机扫描、相册图片二维码识别与手动输入转单码
class ScanGivePage extends StatefulWidget {
  const ScanGivePage({super.key, this.title = '扫码接单'});

  final String title;

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

  // 结果用振动强化反馈：成功中振、失败强振（视线可能还停在取景框上）
  void _showResult(bool success, String message) {
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _success = success;
      _resultMessage = message;
    });
    if (success) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _processCode(String code) async {
    setState(() => _submitting = true);

    final loginSessionId = QrLoginCodec.parseSessionId(code);
    if (loginSessionId != null) {
      await _processLoginCode(loginSessionId);
      return;
    }
    if (!context.read<AuthProvider>().isTechnician) {
      _showResult(false, '这不是登录二维码；工单接单码仅技术员可用');
      return;
    }

    final ticketProvider = context.read<TicketProvider>();
    final err = await ticketProvider.transferTicket(code);
    if (!mounted) return;
    _showResult(err == null, err ?? '接单成功！');

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

  /// 登录码：先 scan 取出码设备信息 → 确认弹窗 → confirm/cancel。
  /// 服务端只在出码方轮询时签发 token，本机不会接触到任何凭据。
  Future<void> _processLoginCode(String sessionId) async {
    final service = QrLoginService();
    final requester = await service.scan(sessionId);
    if (!mounted) return;
    if (requester == null) {
      _showResult(false, service.lastError ?? '登录码无效或已过期');
      return;
    }
    final platform = requester.platform.isEmpty ? '未知设备' : requester.platform;
    final ip = requester.maskedIp.isEmpty ? '未知' : requester.maskedIp;
    final ok = await showConfirmDialog(
      context,
      title: '允许在新设备上登录？',
      content:
          '设备：$platform\nIP：$ip\n\n'
          '确认后该设备将直接登录你的账号。如果不是你本人在操作，请点「取消」。',
      confirmText: '允许登录',
    );
    if (!mounted) return;
    if (!ok) {
      await service.cancel(sessionId);
      if (!mounted) return;
      _showResult(false, '已拒绝本次登录请求');
      return;
    }
    final err = await service.confirm(sessionId);
    if (!mounted) return;
    _showResult(err == null, err ?? '已允许登录，请在另一台设备上继续');
    if (err == null) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_submitting) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    // 识别到码立即停相机：二维码留在取景框内会反复触发 onDetect，形成请求循环。
    // 必须先同步置位 _submitting 再停相机：stop 挂起期间连帧 onDetect 仍会进入，
    // 若等 _processCode 内才置位，同一单号会被并发重复提交
    setState(() => _submitting = true);
    try {
      await _controller.stop();
    } catch (_) {}
    if (!mounted) return;

    await _processCode(code);
  }

  // 从相册选取图片并识别二维码
  Future<void> _pickImageFromGallery() async {
    if (_submitting) return;
    // 与 _handleBarcode 同理，入口先置位，防止停相机挂起期间并发进入
    setState(() => _submitting = true);

    try {
      await _controller.stop();
      if (!mounted) return;

      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        // 用户取消选图，恢复相机取景
        await _resumeScan();
        return;
      }

      setState(() {
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
    } catch (_) {
      // 不向用户展示原始异常文本
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _success = false;
        _resultMessage = '识别图片失败，请换一张更清晰的二维码图片重试';
      });
    }
  }

  // 失败后允许手动恢复取景重扫
  Future<void> _resumeScan() async {
    setState(() {
      _submitting = false;
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
    final isTech = context.watch<AuthProvider>().isTechnician;
    final hint = isTech
        ? '对准工单二维码即可接单；对准登录二维码可授权其他设备登录'
        : '对准另一台设备上的登录二维码，即可授权其登录你的账号';
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              color: _success
                  ? AppTheme.accentColor.withValues(alpha: 0.12)
                  : (_resultMessage == null
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.35)
                        : AppTheme.warningOrange.withValues(alpha: 0.12)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _resultMessage ?? hint,
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(
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
                    // 横屏/分屏宽度不足时换行，避免按钮行 RenderFlex 溢出
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 14,
                      runSpacing: 8,
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
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.sm,
                            ),
                          ),
                        ),
                        // 手动输码只对转单码有意义，非技术员不展示
                        if (isTech)
                          OutlinedButton.icon(
                            onPressed: _openManualInput,
                            icon: const Icon(
                              Icons.keyboard_alt_outlined,
                              size: 18,
                            ),
                            label: const Text('手动输码'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.sm,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  // 失败后相机已暂停，提供手动重扫、相册重试或手动输码入口
                  if (!_success && _resultMessage != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _resumeScan,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('重新扫描'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: AppSpacing.sm,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickImageFromGallery,
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            size: 18,
                          ),
                          label: const Text('相册'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                          ),
                        ),
                        if (isTech)
                          OutlinedButton.icon(
                            onPressed: _openManualInput,
                            icon: const Icon(
                              Icons.keyboard_alt_outlined,
                              size: 18,
                            ),
                            label: const Text('输码'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
