import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';

/// 扫码登录码的编解码（纯函数，便于单测）。
/// 二维码内容 `[fylogin];<session_id>`，session_id 为 64 位 hex；
/// 与技术员接单码 `[give];…` 共用一套前缀识别约定。
class QrLoginCodec {
  QrLoginCodec._();

  static const prefix = '[fylogin];';
  static final _sessionIdPattern = RegExp(r'^[0-9a-f]{64}$');

  static String buildPayload(String sessionId) => '$prefix$sessionId';

  /// 解析扫到的内容；不是登录码或格式不合法返回 null
  static String? parseSessionId(String raw) {
    final input = raw.trim();
    if (!input.startsWith(prefix)) return null;
    final id = input.substring(prefix.length).trim();
    return _sessionIdPattern.hasMatch(id) ? id : null;
  }

  static bool isLoginCode(String raw) => parseSessionId(raw) != null;
}

/// 出码方创建会话的结果
class QrLoginSession {
  const QrLoginSession({
    required this.sessionId,
    required this.pollToken,
    required this.expiresIn,
  });

  final String sessionId;
  final String pollToken;
  final Duration expiresIn;

  String get qrPayload => QrLoginCodec.buildPayload(sessionId);
}

/// 轮询结果：pending（可带 scanned）/ loginOk / expired / cancelled / consumed / error
enum QrPollStatus { pending, loginOk, expired, cancelled, consumed, error }

class QrPollResult {
  const QrPollResult(this.status, {this.scanned = false, this.message});

  final QrPollStatus status;
  final bool scanned;
  final String? message;
}

/// 扫码方 scan 模式拿到的出码设备信息（用于确认弹窗）
class QrLoginRequester {
  const QrLoginRequester({required this.platform, required this.maskedIp});

  final String platform;
  final String maskedIp;
}

/// 扫码登录服务：封装 qrlogin_create / qrlogin_poll（出码方，免鉴权）与
/// qrlogin_confirm（扫码方，Bearer）。login_ok 时把 token 写入 ApiClient。
class QrLoginService {
  QrLoginService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<QrLoginSession?> createSession({required String platform}) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiConstants.qrLoginCreate,
      data: {'platform': platform},
    );
    final raw = res.raw;
    if (!res.success || raw is! Map) return null;
    final sessionId = raw['session_id']?.toString() ?? '';
    final pollToken = raw['poll_token']?.toString() ?? '';
    if (sessionId.isEmpty || pollToken.isEmpty) return null;
    final seconds = int.tryParse(raw['expires_in']?.toString() ?? '') ?? 120;
    return QrLoginSession(
      sessionId: sessionId,
      pollToken: pollToken,
      expiresIn: Duration(seconds: seconds),
    );
  }

  Future<QrPollResult> poll(QrLoginSession session) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiConstants.qrLoginPoll,
      data: {'session_id': session.sessionId, 'poll_token': session.pollToken},
    );
    final raw = res.raw;
    if (raw is! Map) {
      return QrPollResult(QrPollStatus.error, message: res.message ?? '网络连接异常');
    }
    final status = raw['status']?.toString() ?? '';
    if (!res.success) {
      // 会话失效类错误交给调用方按文案提示并重新出码
      return QrPollResult(
        status == 'session_not_found' ? QrPollStatus.expired : QrPollStatus.error,
        message: raw['message']?.toString() ?? res.message,
      );
    }
    switch (status) {
      case 'login_ok':
        final token = raw['access_token']?.toString() ?? '';
        if (token.isEmpty) {
          return const QrPollResult(QrPollStatus.error, message: '服务端未返回登录凭据');
        }
        await _client.setToken(token);
        return const QrPollResult(QrPollStatus.loginOk);
      case 'pending':
        return QrPollResult(QrPollStatus.pending, scanned: raw['scanned'] == true);
      case 'expired':
        return const QrPollResult(QrPollStatus.expired);
      case 'cancelled':
        return const QrPollResult(QrPollStatus.cancelled);
      case 'consumed':
        return const QrPollResult(QrPollStatus.consumed);
      default:
        return QrPollResult(QrPollStatus.error, message: '未知状态：$status');
    }
  }

  /// 扫码方：读取会话并标记已扫码；失败返回 null，错误文案见 [lastError]
  Future<QrLoginRequester?> scan(String sessionId) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiConstants.qrLoginConfirm,
      data: {'session_id': sessionId, 'mode': 'scan'},
    );
    final raw = res.raw;
    if (!res.success || raw is! Map) {
      lastError = _messageOf(res);
      return null;
    }
    return QrLoginRequester(
      platform: raw['requester_platform']?.toString() ?? '',
      maskedIp: raw['requester_ip']?.toString() ?? '',
    );
  }

  /// 扫码方：确认登录；返回 null 表示成功，否则为错误文案
  Future<String?> confirm(String sessionId) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiConstants.qrLoginConfirm,
      data: {'session_id': sessionId, 'mode': 'confirm'},
    );
    return res.success ? null : _messageOf(res);
  }

  /// 扫码方：拒绝本次登录（尽力而为，失败不提示）
  Future<void> cancel(String sessionId) async {
    await _client.post<Map<String, dynamic>>(
      ApiConstants.qrLoginConfirm,
      data: {'session_id': sessionId, 'mode': 'cancel'},
    );
  }

  String? lastError;

  static String _messageOf(ApiResponse<dynamic> res) {
    final raw = res.raw;
    if (raw is Map && raw['message'] != null) return raw['message'].toString();
    return res.message ?? '操作失败，请稍后重试';
  }
}
