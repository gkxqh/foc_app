import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/qr_login_service.dart';
import '../common/responsive_center.dart';

/// 扫码登录出码页（待登录设备）：展示 `[fylogin];session_id` 二维码并轮询会话，
/// 已登录设备在「个人中心 → 扫一扫」扫描并确认后，本机直接完成登录（不消耗短信）。
/// 登录成功以 `Navigator.pop(context, true)` 返回，由登录页收尾。
class QrLoginPage extends StatefulWidget {
  const QrLoginPage({super.key, this.service, this.pollInterval});

  /// 测试注入；为空时使用真实网络服务
  final QrLoginService? service;

  /// 轮询间隔（测试可缩短）
  final Duration? pollInterval;

  @override
  State<QrLoginPage> createState() => _QrLoginPageState();
}

class _QrLoginPageState extends State<QrLoginPage> {
  late final QrLoginService _service = widget.service ?? QrLoginService();

  QrLoginSession? _session;
  bool _creating = false;
  String? _createError;
  QrPollStatus _status = QrPollStatus.pending;
  bool _scanned = false;
  bool _finishing = false;
  int _secondsLeft = 0;
  Timer? _pollTimer;
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _countdown?.cancel();
    _pollTimer = null;
    _countdown = null;
  }

  /// 出码设备自报平台，仅供确认方弹窗展示
  static String platformLabel() {
    if (kIsWeb) return 'Web 网页版';
    if (Platform.isAndroid) return 'Android 手机';
    if (Platform.isIOS) return 'iPhone / iPad';
    if (Platform.isMacOS) return 'macOS 桌面版';
    if (Platform.isWindows) return 'Windows 桌面版';
    if (Platform.isLinux) return 'Linux 桌面版';
    return Platform.operatingSystem;
  }

  Future<void> _createSession() async {
    _stopTimers();
    setState(() {
      _creating = true;
      _createError = null;
      _status = QrPollStatus.pending;
      _scanned = false;
      _finishing = false;
      _session = null;
    });
    final session = await _service.createSession(platform: platformLabel());
    if (!mounted) return;
    if (session == null) {
      setState(() {
        _creating = false;
        _createError = '二维码生成失败，请检查网络后重试';
      });
      return;
    }
    setState(() {
      _session = session;
      _creating = false;
      _secondsLeft = session.expiresIn.inSeconds;
    });
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _stopTimers();
        setState(() {
          _secondsLeft = 0;
          _status = QrPollStatus.expired;
        });
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
    _pollTimer = Timer.periodic(
      widget.pollInterval ?? const Duration(seconds: 2),
      (_) => _pollOnce(),
    );
  }

  Future<void> _pollOnce() async {
    final session = _session;
    if (session == null || _finishing) return;
    final result = await _service.poll(session);
    if (!mounted || _finishing) return;
    switch (result.status) {
      case QrPollStatus.pending:
        if (result.scanned != _scanned) setState(() => _scanned = result.scanned);
      case QrPollStatus.loginOk:
        _stopTimers();
        setState(() => _finishing = true);
        await context.read<AuthProvider>().completeQrLogin();
        if (!mounted) return;
        Navigator.pop(context, true);
      case QrPollStatus.expired:
      case QrPollStatus.cancelled:
      case QrPollStatus.consumed:
        _stopTimers();
        setState(() => _status = result.status);
      case QrPollStatus.error:
        // 瞬时网络错误不打断轮询，下一轮再试
        break;
    }
  }

  String get _overlayText {
    switch (_status) {
      case QrPollStatus.expired:
        return '二维码已过期';
      case QrPollStatus.cancelled:
        return '对方拒绝了本次登录';
      case QrPollStatus.consumed:
        return '登录码已被使用';
      case QrPollStatus.pending:
      case QrPollStatus.loginOk:
      case QrPollStatus.error:
        return '';
    }
  }

  String get _statusText {
    if (_finishing) return '已确认，正在登录…';
    if (_createError != null) return _createError!;
    if (_creating || _session == null) return '正在生成二维码…';
    if (_status != QrPollStatus.pending) return '请点击刷新重新生成二维码';
    if (_scanned) return '已扫码，请在手机上点击「允许登录」';
    return '等待扫码… $_secondsLeft 秒后过期';
  }

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final showOverlay = _status != QrPollStatus.pending || _createError != null;

    return Scaffold(
      appBar: AppBar(title: const Text('扫码登录')),
      body: ResponsiveCenter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                '用已登录的手机打开“云上飞扬”，在个人中心点“扫一扫”扫描下方二维码',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(height: 1.5),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    child: _session == null
                        ? const SizedBox(
                            width: 220,
                            height: 220,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : QrImageView(
                            data: _session!.qrPayload,
                            version: QrVersions.auto,
                            size: 220,
                            // 固定白底黑码：深色模式下也保证最大对比度可扫
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Colors.black,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Colors.black,
                            ),
                          ),
                  ),
                  if (showOverlay)
                    Positioned.fill(
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          onTap: _creating ? null : _createSession,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                _createError != null ? '点击重试' : _overlayText,
                                style: AppText.body.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_createError == null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '点击刷新',
                                  style: AppText.captionSm.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_finishing)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Colors.white70,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_scanned && _status == QrPollStatus.pending && !_finishing)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: AppTheme.accentColor,
                      ),
                    ),
                  Flexible(
                    child: Text(
                      _statusText,
                      textAlign: TextAlign.center,
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _createError != null
                            ? AppTheme.errorRed
                            : (_scanned ? AppTheme.accentColor : null),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                '二维码仅本次有效',
                textAlign: TextAlign.center,
                style: AppText.captionSm.copyWith(
                  color: onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
