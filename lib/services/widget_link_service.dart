import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import '../models/ticket_model.dart';
import '../providers/auth_provider.dart';
import '../providers/ticket_provider.dart';
import '../views/auth/login_page.dart';
import '../views/home/repair_terms_page.dart';
import '../views/home/scan_give_page.dart';
import '../views/home/ticket_detail_page.dart';

/// 桌面小组件点击 → App 内页面路由。
///
/// URI 约定（原生侧通过 home_widget 的显式 intent 拉起，无需 manifest intent-filter）：
/// - `focapp://widget/scan`          扫码接单（仅技术员）
/// - `focapp://widget/ticket?id=xx`  工单详情（无本地命中时现拉一次工单列表）
/// - `focapp://widget/report`        报修须知页（等同首页「我要报修」）
/// - `focapp://widget/home`          仅拉起 App
class WidgetLinkService {
  WidgetLinkService._();

  static const scheme = 'focapp';
  static const host = 'widget';

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static StreamSubscription<Uri?>? _clickSub;
  static Uri? _pending;
  static bool _initialized = false;

  /// 深链诊断日志：仅 debug 构建输出，release 零开销
  static void _log(String message) {
    if (kDebugMode) debugPrint('[WidgetLink] $message');
  }

  /// runApp 后调用一次：登记冷启动落点 + 订阅运行中的热点击。
  static void init() {
    if (_initialized) return;
    _initialized = true;
    _log('init');

    // 冷启动：小组件点击拉起 App（App 此前未运行）
    HomeWidget.initiallyLaunchedFromHomeWidget()
        .then((uri) {
          _log('initial uri=$uri');
          if (uri != null) {
            _pending = uri;
            _drain();
          }
        })
        .catchError((_) {});

    // 热点击：App 已在运行，插件经 onNewIntent 转发
    _clickSub = HomeWidget.widgetClicked.listen((uri) {
      _log('click event uri=$uri');
      if (uri != null) {
        _pending = uri;
        _drain();
      }
    });
  }

  /// 预留：测试或热重载场景下取消订阅
  static void dispose() {
    _clickSub?.cancel();
    _clickSub = null;
    _initialized = false;
    _pending = null;
  }

  static void _drain() {
    final uri = _pending;
    if (uri == null) return;
    _log('drain uri=$uri navReady=${navigatorKey.currentState != null}');
    // navigator 在首帧后才可用；统一延后一帧消费
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = _pending;
      if (uri == null || navigatorKey.currentState == null) return;
      _pending = null;
      unawaited(_handle(uri));
    });
  }

  @visibleForTesting
  static Future<void> handleUri(Uri uri) => _handle(uri);

  static Future<void> _handle(Uri uri) async {
    _log('handle $uri');
    if (uri.scheme != scheme || uri.host != host) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    switch (uri.path) {
      case '/scan':
        _openScan(context);
      case '/ticket':
        await _openTicket(context, uri.queryParameters['id'] ?? '');
      case '/report':
        _openReport(context);
      case '/home':
        // 仅拉起 App 到默认页，无需额外跳转
      default:
        break;
    }
  }

  static void _openReport(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final navigator = navigatorKey.currentState;
    if (!auth.isLoggedIn) {
      navigator?.push(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      );
      return;
    }
    // 与首页「我要报修」同一路径：报修须知强制阅读后才进入表单
    navigator?.push(
      MaterialPageRoute<void>(builder: (_) => const RepairTermsPage()),
    );
  }

  static void _openScan(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final navigator = navigatorKey.currentState;
    if (!auth.isLoggedIn) {
      navigator?.push(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      );
      return;
    }
    if (!auth.isTechnician) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('扫码接单仅对技术员开放')));
      return;
    }
    navigator?.push(
      MaterialPageRoute<void>(builder: (_) => const ScanGivePage()),
    );
  }

  static Future<void> _openTicket(BuildContext context, String id) async {
    // await 之后不得再触碰 context（跨异步间隙），提前捕获 Provider 与导航/提示器
    final auth = context.read<AuthProvider>();
    final tickets = context.read<TicketProvider>();
    final navigator = navigatorKey.currentState;
    final messenger = ScaffoldMessenger.maybeOf(context);

    if (!auth.isLoggedIn) {
      navigator?.push(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      );
      return;
    }
    if (id.isEmpty) {
      messenger?.showSnackBar(const SnackBar(content: Text('工单信息无效')));
      return;
    }

    TicketModel? ticket = _findById(tickets.tickets, id);
    if (ticket == null && auth.user != null) {
      // 详情页需要完整 TicketModel 且无按 id 查询的接口，本地未命中时现拉一次
      await tickets.fetchTickets(role: auth.user!.role, uid: auth.user!.uid);
      ticket = _findById(tickets.tickets, id);
    }
    final resolved = ticket;
    if (resolved == null) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('工单不存在或加载失败')),
      );
      return;
    }
    navigator?.push(
      MaterialPageRoute<void>(builder: (_) => TicketDetailPage(ticket: resolved)),
    );
  }

  static TicketModel? _findById(List<TicketModel> tickets, String id) {
    for (final t in tickets) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 供测试断言解析结果
  @visibleForTesting
  static ({String path, String? ticketId}) parse(Uri uri) {
    final path = (uri.scheme == scheme && uri.host == host) ? uri.path : '';
    return (path: path, ticketId: uri.queryParameters['id']);
  }
}
