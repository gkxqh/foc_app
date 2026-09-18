import 'package:flutter/foundation.dart';

import '../models/ticket_model.dart';
import '../services/ticket_service.dart';

/// 广场排序模式：等待最久优先（默认，早单在前）/ 最新优先
enum PlazaSortMode { waitLongest, newestFirst }

/// 筛选/排序/等待时长的纯函数集合，与 Provider 状态解耦便于单测
class PlazaFilters {
  PlazaFilters._();

  /// 关键词匹配的字段：设备型号、故障描述、品牌、设备类型、故障类型、机主昵称
  static bool _matchKeyword(TicketModel t, String keyword) {
    final lower = keyword.toLowerCase();
    return (t.model ?? '').toLowerCase().contains(lower) ||
        t.repairDescription.toLowerCase().contains(lower) ||
        t.computerBrand.toLowerCase().contains(lower) ||
        t.deviceType.toLowerCase().contains(lower) ||
        t.faultType.toLowerCase().contains(lower) ||
        (t.ownerNickname ?? '').toLowerCase().contains(lower);
  }

  /// 筛选：校区单选 + 品牌/设备/故障多选 + 关键词；全部条件为空集时原样返回
  static List<TicketModel> applyFilters(
    List<TicketModel> tickets, {
    String campus = '全部',
    Set<String> brands = const {},
    Set<String> devices = const {},
    Set<String> faults = const {},
    String keyword = '',
  }) {
    return tickets.where((t) {
      if (campus != '全部' && t.campus != campus) return false;
      if (brands.isNotEmpty && !brands.contains(t.computerBrand)) return false;
      if (devices.isNotEmpty && !devices.contains(t.deviceType)) return false;
      if (faults.isNotEmpty && !faults.contains(t.faultType)) return false;
      if (keyword.trim().isNotEmpty && !_matchKeyword(t, keyword.trim())) {
        return false;
      }
      return true;
    }).toList();
  }

  /// 排序：加急单恒置顶，其后按所选模式排创建时间（id 作稳定次序）
  static List<TicketModel> sortTickets(
    List<TicketModel> tickets,
    PlazaSortMode mode,
  ) {
    int timeMs(TicketModel t) =>
        DateTime.tryParse(t.createTime)?.millisecondsSinceEpoch ?? 0;
    final sorted = List<TicketModel>.of(tickets);
    sorted.sort((a, b) {
      if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
      final cmp = timeMs(a).compareTo(timeMs(b));
      final result = mode == PlazaSortMode.waitLongest ? cmp : -cmp;
      if (result != 0) return result;
      // 时间相同（解析失败回落 0 等）时按 id 数值稳定排序
      final idA = int.tryParse(a.id) ?? 0;
      final idB = int.tryParse(b.id) ?? 0;
      return mode == PlazaSortMode.waitLongest
          ? idA.compareTo(idB)
          : idB.compareTo(idA);
    });
    return sorted;
  }

  /// 组合：先筛后排
  static List<TicketModel> apply(
    List<TicketModel> tickets, {
    String campus = '全部',
    Set<String> brands = const {},
    Set<String> devices = const {},
    Set<String> faults = const {},
    String keyword = '',
    PlazaSortMode sortMode = PlazaSortMode.waitLongest,
  }) {
    return sortTickets(
      applyFilters(
        tickets,
        campus: campus,
        brands: brands,
        devices: devices,
        faults: faults,
        keyword: keyword,
      ),
      sortMode,
    );
  }

  /// 等待时长文案："刚刚 / X 分钟 / X 小时 / X 天"；create_time 解析失败返回 null（调用方隐藏该标签）。
  /// 服务端 create_time 为北京时间，直接按本地时区解析即可（与全 App 直显 create_time 的口径一致）。
  static String? formatWaitTime(String createTime, {DateTime? now}) {
    final created = DateTime.tryParse(createTime);
    if (created == null) return null;
    final current = now ?? DateTime.now();
    final minutes = current.difference(created).inMinutes;
    if (minutes < 1) return '刚刚';
    if (minutes < 60) return '$minutes 分钟';
    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours 小时';
    return '${minutes ~/ 1440} 天';
  }

  /// 接单失败文案映射：把服务端已有报错翻成用户能懂的说法
  static String claimErrorText(String serverMessage) {
    if (serverMessage.contains('Order has closed') ||
        serverMessage.contains('Order hash mismatch') ||
        serverMessage.contains('Transfer vcode mismatch')) {
      return '手慢了，该工单已被其他技术员接走';
    }
    if (serverMessage.contains('Permission denied')) {
      return '权限不足，仅技术员可接单';
    }
    return serverMessage;
  }
}

class PlazaProvider extends ChangeNotifier {
  PlazaProvider({TicketService? ticketService})
    : _ticketService = ticketService ?? TicketService();

  final TicketService _ticketService;

  List<TicketModel> _tickets = [];
  bool _isLoading = false;
  bool _isClaiming = false;
  String? _lastError;

  // 筛选/排序状态（页面直接读写，改完调 notifyFiltersChanged）
  String campusFilter = '全部';
  final Set<String> brandFilters = {};
  final Set<String> deviceFilters = {};
  final Set<String> faultFilters = {};
  String keyword = '';
  PlazaSortMode sortMode = PlazaSortMode.waitLongest;

  List<TicketModel> get tickets => _tickets;
  bool get isLoading => _isLoading;
  bool get isClaiming => _isClaiming;
  String? get lastError => _lastError;

  bool get hasActiveFilters =>
      campusFilter != '全部' ||
      brandFilters.isNotEmpty ||
      deviceFilters.isNotEmpty ||
      faultFilters.isNotEmpty ||
      keyword.trim().isNotEmpty;

  /// 筛选后的展示列表
  List<TicketModel> get visibleTickets => PlazaFilters.apply(
    _tickets,
    campus: campusFilter,
    brands: brandFilters,
    devices: deviceFilters,
    faults: faultFilters,
    keyword: keyword,
    sortMode: sortMode,
  );

  Future<void> fetchPlaza() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      _tickets = await _ticketService.getPlazaTickets();
    } catch (_) {
      // 网络异常保留旧列表只记错误，避免误显示"没有工单"（同 TicketProvider 约定）
      _lastError = '接单广场加载失败，请检查网络后下拉重试';
    }
    _isLoading = false;
    notifyListeners();
  }

  /// 接单（复用 /v1/ticket/give 的 order_hash 凭据）。
  /// 返回 null 表示成功；否则返回已翻译的错误文案。
  /// 服务端接单后 transcode 轮换、列表状态必然变化，调用方务必随后整表刷新。
  Future<String?> claimTicket(TicketModel ticket) async {
    // 忙碌时必须返回错误文案而非 null：null 在调用方约定里是"成功"，
    // 静默吞掉并发请求会误报"接单成功"
    if (_isClaiming) return '已有接单操作在进行，请稍候';
    // order_hash 是接单凭据；缺失时 give 会退化成 tvcode 校验并报
    // 'Invalid code' 原文，前置拦截给出可理解的提示
    if ((ticket.orderHash ?? '').isEmpty) {
      return '该工单缺少接单凭据，请改用扫码接单';
    }
    _isClaiming = true;
    notifyListeners();

    final res = await _ticketService.giveTicket(
      orderId: ticket.id,
      orderHash: ticket.orderHash,
    );

    _isClaiming = false;
    String? error;
    if (res.success) {
      // 本地先移除已被自己接走的单，整表刷新随后由页面触发
      _tickets.removeWhere((t) => t.id == ticket.id);
    } else {
      error = PlazaFilters.claimErrorText(res.message ?? '接单失败，请稍后重试');
    }
    notifyListeners();
    return error;
  }

  void setKeyword(String value) {
    keyword = value;
    notifyListeners();
  }

  void setCampus(String campus) {
    campusFilter = campus;
    notifyListeners();
  }

  void setSortMode(PlazaSortMode mode) {
    sortMode = mode;
    notifyListeners();
  }

  void toggleBrand(String brand) =>
      _toggle(brandFilters, brand, notifyListeners);
  void toggleDevice(String device) =>
      _toggle(deviceFilters, device, notifyListeners);
  void toggleFault(String fault) => _toggle(faultFilters, fault, notifyListeners);

  void clearFilters() {
    campusFilter = '全部';
    brandFilters.clear();
    deviceFilters.clear();
    faultFilters.clear();
    keyword = '';
    notifyListeners();
  }

  static void _toggle(Set<String> set, String value, VoidCallback notify) {
    if (!set.add(value)) {
      set.remove(value);
    }
    notify();
  }
}
