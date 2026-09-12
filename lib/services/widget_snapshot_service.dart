import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ticket_model.dart';
import '../models/user_model.dart';

/// 桌面小组件快照管线（Android）。
///
/// 小组件的原生渲染只读这一个 JSON payload；App 侧任何数据变化都重建整份 payload
/// 写入并触发刷新。原生侧（WorkManager 轮询 / 组件刷新按钮）会写入同 schema 的
/// payload，双方以 `ts` 与 `uid`/`role` 判断能否复用对方的数据，schema 见 buildPayload。
class WidgetSnapshotService {
  WidgetSnapshotService._();

  static const payloadKey = 'foc_widget_payload';
  static const schemaVersion = 1;

  static const _techProvider =
      'cn.ac.feiyang.foc_app.widget.TechWidgetProvider';
  static const _userProvider =
      'cn.ac.feiyang.foc_app.widget.UserWidgetProvider';

  /// 30 分钟内写入的快照视为「新鲜」：仅用户信息变化时保留其中的工单数据，
  /// 避免冷启动/资料刷新用尚未拉取的空列表覆盖原生轮询刚写入的数据造成闪烁。
  static const freshWindow = Duration(minutes: 30);

  /// payload 最多携带的工单条数（4x2 布局渲染前两条，留少量余量）。
  static const maxTickets = 4;

  /// 工单数据变化（fetchTickets / 本地状态流转）后的完整重建。
  static Future<void> refreshTickets({
    required String role,
    required String uid,
    required List<TicketModel> tickets,
  }) async {
    final user = await _loadCachedUser();
    await _write(buildPayload(user: user, role: role, uid: uid, tickets: tickets));
  }

  /// 仅用户信息变化（登录 / 切换账号 / 资料刷新 / 接单上限调整）。
  /// [resetTickets] 为 true 时丢弃快照中的工单（账号已切换，旧工单不再属于当前用户）。
  static Future<void> refreshUser({bool resetTickets = false}) async {
    final user = await _loadCachedUser();
    if (user == null) {
      await clear();
      return;
    }
    var tickets = const <Map<String, Object?>>[];
    if (!resetTickets) {
      final previous = await _readPayload();
      if (previous != null &&
          _isFresh(previous) &&
          previous['uid']?.toString() == user.uid &&
          previous['role']?.toString() == user.role) {
        final prevTickets = previous['tickets'];
        if (prevTickets is List) {
          tickets = prevTickets
              .whereType<Map>()
              .map((t) => t.cast<String, Object?>())
              .toList();
        }
      }
    }
    await _write(_payloadFromTicketDicts(user: user, role: user.role, uid: user.uid, ticketDicts: tickets));
  }

  /// 退出登录 / 登录态失效：清空为未登录快照。
  static Future<void> clear() async {
    await _write(loggedOutPayload());
  }

  // ============ payload 构建（纯函数，供单测） ============

  @visibleForTesting
  static Map<String, Object?> buildPayload({
    required UserModel? user,
    required String role,
    required String uid,
    required List<TicketModel> tickets,
  }) {
    return _payloadFromTicketDicts(
      user: user,
      role: role,
      uid: uid,
      ticketDicts: tickets.map(_ticketToJson).toList(),
    );
  }

  /// 以工单字典为输入构建 payload：完整重建（模型→字典）与复用旧快照（refreshUser）
  /// 共用过滤/排序/计数逻辑。
  static Map<String, Object?> _payloadFromTicketDicts({
    required UserModel? user,
    required String role,
    required String uid,
    required List<Map<String, Object?>> ticketDicts,
  }) {
    final technician = role == 'technician';
    // 未登录一律不携带工单（原生侧也只渲染引导态）
    final active =
        (user == null ? const <Map<String, Object?>>[] : ticketDicts)
            .where((t) => !isFinishedStatus(t['status']?.toString() ?? ''))
            .toList()
          ..sort(
            (a, b) => priority(
              a['status']?.toString() ?? '',
              technician: technician,
            ).compareTo(
              priority(b['status']?.toString() ?? '', technician: technician),
            ),
          );
    return {
      'v': schemaVersion,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'loggedIn': user != null,
      'tokenState': 'ok',
      'role': role,
      'uid': uid,
      'nickname': user?.nickname ?? '',
      // 周报修额度是服务端下发的展示串，原样透传
      'quota': user?.available ?? '',
      'maxConcurrent': user?.maxConcurrent ?? 1,
      'tickets': active.take(maxTickets).toList(),
      'countTotal': active.length,
      'countTechConfirm':
          active.where((t) => t['status'] == 'TechConfirming').length,
      'countUserConfirm':
          active.where((t) => t['status'] == 'UserConfirming').length,
    };
  }

  /// 与 TicketModel.isFinished 同口径（含历史拼写 cancelled）
  @visibleForTesting
  static bool isFinishedStatus(String status) {
    final s = status.trim().toLowerCase();
    return s == 'done' || s == 'closed' || s == 'canceled' || s == 'cancelled';
  }

  @visibleForTesting
  static Map<String, Object?> loggedOutPayload() => {
    'v': schemaVersion,
    'ts': DateTime.now().millisecondsSinceEpoch,
    'loggedIn': false,
    'tokenState': 'ok',
    'role': '',
    'uid': '',
    'nickname': '',
    'quota': '',
    'maxConcurrent': 1,
    'tickets': <Object?>[],
    'countTotal': 0,
    'countTechConfirm': 0,
    'countUserConfirm': 0,
  };

  /// 渲染排序：可操作状态最优先（技术员先看「待我确认」，用户先看「待你确认」），
  /// 其余按流转顺序。与 App 内状态色映射同源（app_theme.dart）。
  @visibleForTesting
  static int priority(String status, {required bool technician}) {
    switch (status.trim().toLowerCase()) {
      case 'techconfirming':
        return technician ? 0 : 2;
      case 'repairing':
        return 1;
      case 'userconfirming':
        return technician ? 2 : 0;
      case 'pending':
        return 3;
      default:
        return 4;
    }
  }

  static Map<String, Object?> _ticketToJson(TicketModel t) => {
    'id': t.id,
    'status': t.repairStatus,
    'device': t.deviceType,
    'brand': t.computerBrand,
    'model': t.model ?? '',
    'fault': t.faultType,
    'campus': t.campus,
    'tech': t.technicianName ?? '',
    'createdAt': t.createTime,
  };

  // ============ 存取 ============

  static Future<UserModel?> _loadCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_user_info');
      if (raw == null || raw.isEmpty) return null;
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _readPayload() async {
    try {
      final raw = await HomeWidget.getWidgetData<String>(payloadKey);
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static bool _isFresh(Map<String, dynamic> payload) {
    final ts = payload['ts'];
    return ts is num &&
        DateTime.now().millisecondsSinceEpoch - ts <=
            freshWindow.inMilliseconds;
  }

  /// 写入并触发刷新；小组件链路上的任何失败都不允许影响 App 主流程。
  static Future<void> _write(Map<String, Object?> payload) async {
    try {
      await HomeWidget.saveWidgetData<String>(payloadKey, jsonEncode(payload));
    } catch (_) {}
    try {
      // 未添加到桌面的组件会空跑一次广播，无副作用
      await HomeWidget.updateWidget(qualifiedAndroidName: _techProvider);
      await HomeWidget.updateWidget(qualifiedAndroidName: _userProvider);
    } catch (_) {}
  }
}
