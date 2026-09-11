import 'package:flutter/foundation.dart';
import '../models/ticket_model.dart';
import '../services/ticket_service.dart';

class TicketProvider extends ChangeNotifier {
  final TicketService _ticketService = TicketService();

  List<TicketModel> _tickets = [];
  bool _isLoading = false;
  String? _lastError;
  String? _lastActionError; // 最近一次提交类操作（提交工单/接单）失败的服务端原因

  List<TicketModel> get tickets => _tickets;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  String? get lastActionError => _lastActionError;

  // 进行中的工单（未完成）
  List<TicketModel> get activeTickets =>
      _tickets.where((t) => !t.isFinished).toList();

  // 历史完成/关闭工单
  List<TicketModel> get historyTickets =>
      _tickets.where((t) => t.isFinished).toList();

  // 刷新工单
  Future<void> fetchTickets({required String role, required String uid}) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      if (role == 'technician') {
        _tickets = await _ticketService.getTickets(tid: uid);
      } else {
        _tickets = await _ticketService.getTickets(uid: uid);
      }
    } catch (_) {
      // 网络异常时保留已有列表，仅记录错误供页面提示，避免误显示"没有工单"
      _lastError = '工单加载失败，请检查网络后下拉重试';
    }

    _isLoading = false;
    notifyListeners();
  }

  // 提交报修
  Future<bool> submitTicket({
    String? uid,
    String? userNick,
    required String purchaseDate,
    required String phone,
    required String deviceType,
    required String computerBrand,
    required String description,
    required String imageUrl,
    required String faultType,
    required String qqOrContact,
    required String campus,
    required int duoCampus,
    required String warrantyStatus,
    required String model,
  }) async {
    _isLoading = true;
    _lastActionError = null;
    notifyListeners();

    final res = await _ticketService.submitTicket(
      uid: uid,
      userNick: userNick,
      purchaseDate: purchaseDate,
      phone: phone,
      deviceType: deviceType,
      computerBrand: computerBrand,
      description: description,
      imageUrl: imageUrl,
      faultType: faultType,
      qqOrContact: qqOrContact,
      campus: campus,
      duoCampus: duoCampus,
      warrantyStatus: warrantyStatus,
      model: model,
    );

    _isLoading = false;
    if (!res.success) {
      // 保留服务端原因（如"报修通道未开启"、配额上限等），供页面展示
      _lastActionError = res.message ?? '提交失败，请稍后重试';
    }
    notifyListeners();
    return res.success;
  }

  // 接单 / 转单
  // 支持两种凭证：服务端二维码格式 "[give];<单号>;<order_hash>"，或 "单号+6位tvcode" 文本
  Future<String?> transferTicket(String raw) async {
    final input = raw.trim();

    String orderId;
    if (input.startsWith('[give];')) {
      final parts = input.split(';');
      if (parts.length < 3 || parts[1].isEmpty || parts[2].isEmpty) {
        return '二维码内容无效';
      }
      orderId = parts[1];
    } else {
      final code = input;
      // 服务端会校验 tvcode（"Transfer vcode mismatch"），格式不符直接本地拦截
      if (code.length <= 6 || !RegExp(r'^\d{6}$').hasMatch(code.substring(code.length - 6))) {
        return '转单码格式错误（应为 工单号 + 6位数字验证码）';
      }
      orderId = code.substring(0, code.length - 6);
    }

    _isLoading = true;
    notifyListeners();

    final res = await _ticketService.giveTicket(
      orderId: orderId,
      tvcode: input.startsWith('[give];') ? null : input.substring(input.length - 6),
      orderHash: input.startsWith('[give];') ? input.split(';')[2] : null,
    );
    _isLoading = false;
    notifyListeners();

    if (res.success) return null;
    return res.message ?? '接单失败';
  }

  // 技术员完成工单
  Future<bool> completeTicket(String orderId) async {
    final res = await _ticketService.completeTicket(orderId);
    if (res.success) {
      _updateLocalTicketStatus(orderId, 'Done');
    }
    return res.success;
  }

  // 双向确认或取消工单
  Future<bool> changeTicketStatus(String orderId, String status) async {
    final res = await _ticketService.setTicketStatus(orderId, status);
    if (res.success) {
      _updateLocalTicketStatus(orderId, status);
    }
    return res.success;
  }

  void _updateLocalTicketStatus(String orderId, String newStatus) {
    final index = _tickets.indexWhere((t) => t.id == orderId);
    if (index != -1) {
      _tickets[index] = _tickets[index].copyWith(repairStatus: newStatus);
      notifyListeners();
    }
  }

  // 上传完成维修凭证图片
  Future<bool> setCompleteImage(String orderId, String imageUrl) async {
    final res = await _ticketService.setCompleteImage(orderId, imageUrl);
    return res.success;
  }
}
