import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/core/network/api_client.dart';
import 'package:foc_app/models/ticket_model.dart';
import 'package:foc_app/models/user_model.dart';
import 'package:foc_app/providers/auth_provider.dart';
import 'package:foc_app/providers/plaza_provider.dart';
import 'package:foc_app/services/ticket_service.dart';
import 'package:foc_app/views/home/claim_plaza_page.dart';
import 'package:provider/provider.dart';

TicketModel _ticket({
  required String id,
  String campus = '江安',
  String brand = '戴尔 DELL',
  String device = '笔记本 (Laptop)',
  String fault = '无法开机',
  String desc = '按下电源键无反应',
  String model = 'XPS 13',
  String createTime = '2026-09-18 08:00:00',
  bool urgent = false,
  String? orderHash = 'hash_abc',
}) {
  return TicketModel(
    id: id,
    createTime: createTime,
    deviceType: device,
    computerBrand: brand,
    faultType: fault,
    repairDescription: desc,
    repairImageUrl: '',
    repairStatus: 'Pending',
    campus: campus,
    model: model,
    orderHash: orderHash,
    isUrgent: urgent,
  );
}

/// 可注入假响应的 TicketService 替身（Provider 构造器注入，无需网络 mock 库）
class _FakeTicketService extends TicketService {
  _FakeTicketService({this.tickets = const [], this.claimSucceeds = true});

  List<TicketModel> tickets;
  bool claimSucceeds;
  final List<String> claimedOrderIds = [];

  @override
  Future<List<TicketModel>> getPlazaTickets() async => tickets;

  @override
  Future<ApiResponse<dynamic>> giveTicket({
    required String orderId,
    String? tvcode,
    String? orderHash,
  }) async {
    claimedOrderIds.add(orderId);
    return ApiResponse<dynamic>(
      success: claimSucceeds,
      statusCode: claimSucceeds ? 200 : 409,
      message: claimSucceeds ? 'Order assigned successfully' : 'Order has closed',
    );
  }
}

Widget _wrapPage({required UserModel user, required _FakeTicketService service}) {
  final auth = AuthProvider();
  auth.setUserForTest(user);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<PlazaProvider>(
        create: (_) => PlazaProvider(ticketService: service),
      ),
    ],
    child: const MaterialApp(home: ClaimPlazaPage()),
  );
}

void main() {
  group('PlazaFilters.applyFilters', () {
    final tickets = [
      _ticket(id: '1', campus: '江安', brand: '戴尔 DELL'),
      _ticket(id: '2', campus: '望江', brand: '苹果 Apple', desc: '屏幕碎裂'),
      _ticket(id: '3', campus: '江安', brand: '联想 Lenovo', model: '拯救者 Y7000'),
    ];

    test('校区单选筛选', () {
      final result = PlazaFilters.applyFilters(tickets, campus: '望江');
      expect(result.map((t) => t.id), ['2']);
    });

    test('品牌多选筛选', () {
      final result = PlazaFilters.applyFilters(
        tickets,
        brands: {'戴尔 DELL', '联想 Lenovo'},
      );
      expect(result.map((t) => t.id), ['1', '3']);
    });

    test('关键词命中描述/型号/昵称，大小写不敏感', () {
      expect(
        PlazaFilters.applyFilters(tickets, keyword: '碎裂').map((t) => t.id),
        ['2'],
      );
      expect(
        PlazaFilters.applyFilters(tickets, keyword: 'y7000').map((t) => t.id),
        ['3'],
      );
    });

    test('条件叠加取交集；无条件原样返回', () {
      final result = PlazaFilters.applyFilters(
        tickets,
        campus: '江安',
        keyword: '拯救者',
      );
      expect(result.map((t) => t.id), ['3']);
      expect(PlazaFilters.applyFilters(tickets), tickets);
    });
  });

  group('PlazaFilters.sortTickets', () {
    test('加急恒置顶；等待最久 = 时间升序', () {
      final tickets = [
        _ticket(id: '1', createTime: '2026-09-18 09:00:00'),
        _ticket(id: '2', createTime: '2026-09-18 07:00:00', urgent: true),
        _ticket(id: '3', createTime: '2026-09-18 08:00:00'),
      ];
      final result = PlazaFilters.sortTickets(tickets, PlazaSortMode.waitLongest);
      expect(result.map((t) => t.id), ['2', '3', '1']);
    });

    test('最新优先 = 时间降序，加急仍在最前', () {
      final tickets = [
        _ticket(id: '1', createTime: '2026-09-18 09:00:00'),
        _ticket(id: '2', createTime: '2026-09-18 07:00:00', urgent: true),
        _ticket(id: '3', createTime: '2026-09-18 08:00:00'),
      ];
      final result = PlazaFilters.sortTickets(tickets, PlazaSortMode.newestFirst);
      expect(result.map((t) => t.id), ['2', '1', '3']);
    });

    test('时间解析失败回落 0 时按 id 稳定排序，不抛异常', () {
      final tickets = [
        _ticket(id: '20', createTime: 'not-a-date'),
        _ticket(id: '3', createTime: 'also-bad'),
      ];
      final result = PlazaFilters.sortTickets(tickets, PlazaSortMode.waitLongest);
      expect(result.map((t) => t.id), ['3', '20']);
    });
  });

  group('PlazaFilters.formatWaitTime', () {
    final now = DateTime(2026, 9, 18, 12, 0);

    test('解析失败的 create_time 返回 null（页面隐藏标签）', () {
      expect(PlazaFilters.formatWaitTime('garbage', now: now), isNull);
    });

    test('分钟/小时/天/刚刚', () {
      expect(
        PlazaFilters.formatWaitTime('2026-09-18 11:59:30', now: now),
        '刚刚',
      );
      expect(
        PlazaFilters.formatWaitTime('2026-09-18 11:30:00', now: now),
        '30 分钟',
      );
      expect(
        PlazaFilters.formatWaitTime('2026-09-18 09:00:00', now: now),
        '3 小时',
      );
      expect(
        PlazaFilters.formatWaitTime('2026-09-16 12:00:00', now: now),
        '2 天',
      );
    });
  });

  group('PlazaFilters.claimErrorText', () {
    test('抢占/凭据类报错翻译为友好文案', () {
      expect(
        PlazaFilters.claimErrorText('Order has closed'),
        '手慢了，该工单已被其他技术员接走',
      );
      expect(
        PlazaFilters.claimErrorText('Order hash mismatch'),
        '手慢了，该工单已被其他技术员接走',
      );
    });

    test('其他报错原样透传', () {
      expect(PlazaFilters.claimErrorText('Database error'), 'Database error');
    });
  });

  group('TicketModel.urgent 序列化', () {
    test('fromJson 兼容 int/字符串/布尔/缺失', () {
      expect(
        TicketModel.fromJson({
          'id': 1,
          'urgent': 1,
          'create_time': '2026-09-18 08:00:00',
          'device_type': 'd',
          'computer_brand': 'b',
          'fault_type': 'f',
          'repair_description': 'r',
          'repair_image_url': '',
          'repair_status': 'Pending',
          'campus': '江安',
        }).isUrgent,
        isTrue,
      );
      expect(
        TicketModel.fromJson({
          'id': 1,
          'urgent': '0',
          'repair_status': 'Pending',
        }).isUrgent,
        isFalse,
      );
      expect(TicketModel.fromJson({'id': 1}).isUrgent, isFalse);
    });

    test('toJson 输出服务端整型口径', () {
      expect(_ticket(id: '1', urgent: true).toJson()['urgent'], 1);
      expect(_ticket(id: '1').toJson()['urgent'], 0);
    });

    test('copyWith 可修改 isUrgent', () {
      final t = _ticket(id: '1');
      expect(t.copyWith(isUrgent: true).isUrgent, isTrue);
    });
  });

  group('PlazaProvider', () {
    test('fetchPlaza 成功加载列表', () async {
      final provider = PlazaProvider(
        ticketService: _FakeTicketService(tickets: [_ticket(id: '1')]),
      );
      await provider.fetchPlaza();
      expect(provider.isLoading, isFalse);
      expect(provider.lastError, isNull);
      expect(provider.tickets.map((t) => t.id), ['1']);
    });

    test('fetchPlaza 失败保留旧列表并记录错误', () async {
      final service = _FlakyTicketService();
      final provider = PlazaProvider(ticketService: service);
      await provider.fetchPlaza();
      expect(provider.tickets.map((t) => t.id), ['1']);
      expect(provider.lastError, isNull);

      service.fail = true;
      await provider.fetchPlaza();
      expect(provider.lastError, isNotNull);
      expect(provider.tickets.map((t) => t.id), ['1']);
    });

    test('claimTicket 成功返回 null 并本地移除该单', () async {
      final service = _FakeTicketService(
        tickets: [_ticket(id: '1'), _ticket(id: '2')],
      );
      final provider = PlazaProvider(ticketService: service);
      await provider.fetchPlaza();

      final error = await provider.claimTicket(provider.tickets.first);
      expect(error, isNull);
      expect(service.claimedOrderIds, ['1']);
      expect(provider.tickets.map((t) => t.id), ['2']);
    });

    test('claimTicket 失败返回翻译后的文案且不移除', () async {
      final service = _FakeTicketService(
        tickets: [_ticket(id: '1')],
        claimSucceeds: false,
      );
      final provider = PlazaProvider(ticketService: service);
      await provider.fetchPlaza();

      final error = await provider.claimTicket(provider.tickets.first);
      expect(error, '手慢了，该工单已被其他技术员接走');
      expect(provider.tickets, isNotEmpty);
    });

    test('接单进行中重复调用返回忙碌提示而非误报成功', () async {
      final service = _BlockingTicketService(
        tickets: [_ticket(id: '1'), _ticket(id: '2')],
      );
      final provider = PlazaProvider(ticketService: service);
      await provider.fetchPlaza();

      // 第一个接单请求在途（不 await），第二个立即到达
      final first = provider.claimTicket(provider.tickets.first);
      final busy = await provider.claimTicket(provider.tickets.last);
      expect(busy, '已有接单操作在进行，请稍候');

      service.completer.complete(
        ApiResponse<dynamic>(success: true, statusCode: 200),
      );
      expect(await first, isNull);
      expect(service.claimedOrderIds, ['1']);
      expect(provider.tickets.map((t) => t.id), ['2']);
    });

    test('order_hash 缺失时前置拦截且不发接单请求', () async {
      final service = _FakeTicketService(
        tickets: [_ticket(id: '1', orderHash: null)],
      );
      final provider = PlazaProvider(ticketService: service);
      await provider.fetchPlaza();

      final error = await provider.claimTicket(provider.tickets.first);
      expect(error, '该工单缺少接单凭据，请改用扫码接单');
      expect(service.claimedOrderIds, isEmpty);
      expect(provider.tickets, isNotEmpty);
    });

    test('筛选状态切换与清空', () {
      final provider = PlazaProvider(ticketService: _FakeTicketService());
      provider
        ..toggleBrand('戴尔 DELL')
        ..toggleFault('无法开机')
        ..setCampus('江安')
        ..setKeyword('黑屏')
        ..setSortMode(PlazaSortMode.newestFirst);
      expect(provider.hasActiveFilters, isTrue);
      expect(provider.visibleTickets, isEmpty);

      provider.clearFilters();
      expect(provider.hasActiveFilters, isFalse);
      // 排序是用户偏好而非筛选条件：清空筛选时保留
      expect(provider.sortMode, PlazaSortMode.newestFirst);
      expect(provider.campusFilter, '全部');
      expect(provider.keyword, '');
    });

    test('toggleBrand 二次调用取消选中', () {
      final provider = PlazaProvider(ticketService: _FakeTicketService());
      provider.toggleBrand('戴尔 DELL');
      expect(provider.brandFilters, {'戴尔 DELL'});
      provider.toggleBrand('戴尔 DELL');
      expect(provider.brandFilters, isEmpty);
    });
  });

  group('接单广场页面', () {
    testWidgets('技术员可见工单卡并可按关键词过滤', (tester) async {
      final service = _FakeTicketService(
        tickets: [
          _ticket(id: '1', desc: '开不了机', urgent: true),
          _ticket(id: '2', desc: '风扇异响'),
        ],
      );
      await tester.pumpWidget(
        _wrapPage(
          user: UserModel(uid: '9', id: '9', role: 'technician'),
          service: service,
        ),
      );
      // 首帧 + postFrame 的 fetchPlaza 完成后的重建（StaggeredIn 动画用定帧 pump）
      await tester.pump();
      await tester.pump();

      expect(find.text('接单广场'), findsOneWidget);
      expect(find.text('加急'), findsOneWidget);
      expect(find.text('开不了机'), findsOneWidget);
      expect(find.text('风扇异响'), findsOneWidget);
      expect(find.text('接单'), findsNWidgets(2));

      await tester.enterText(find.byType(TextField), '风扇');
      await tester.pump();

      expect(find.text('开不了机'), findsNothing);
      expect(find.text('风扇异响'), findsOneWidget);
    });

    testWidgets('空列表展示空态文案', (tester) async {
      await tester.pumpWidget(
        _wrapPage(
          user: UserModel(uid: '9', id: '9', role: 'technician'),
          service: _FakeTicketService(tickets: []),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('暂无待接工单'), findsOneWidget);
    });

    testWidgets('非技术员访问被拦截', (tester) async {
      await tester.pumpWidget(
        _wrapPage(
          user: UserModel(uid: '9', id: '9', role: 'user'),
          service: _FakeTicketService(tickets: [_ticket(id: '1')]),
        ),
      );
      await tester.pump();

      expect(find.text('仅技术员可访问接单广场'), findsOneWidget);
      expect(find.text('接单'), findsNothing);
    });

    testWidgets('清空全部筛选时同步清理搜索框文本', (tester) async {
      final service = _FakeTicketService(
        tickets: [
          _ticket(id: '1', desc: '开不了机'),
          _ticket(id: '2', desc: '风扇异响'),
        ],
      );
      await tester.pumpWidget(
        _wrapPage(
          user: UserModel(uid: '9', id: '9', role: 'technician'),
          service: service,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.byType(TextField), '风扇');
      await tester.pump();
      expect(find.text('开不了机'), findsNothing);

      // 打开高级筛选面板，点"清空全部"（pumpAndSettle 等 BottomSheet 滑入动画结束）
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清空全部'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, '');
      // 关键词已清空，列表恢复全量
      expect(find.text('开不了机'), findsOneWidget);
    });
  });
}

/// 先成功后失败的替身：验证 fetchPlaza 的错误路径不丢旧数据
class _FlakyTicketService extends TicketService {
  bool fail = false;

  @override
  Future<List<TicketModel>> getPlazaTickets() async {
    if (fail) throw Exception('network down');
    return [_ticket(id: '1')];
  }
}

/// give 请求挂起直到测试手动放行：验证接单并发互斥
class _BlockingTicketService extends TicketService {
  _BlockingTicketService({this.tickets = const []});

  List<TicketModel> tickets;
  final Completer<ApiResponse<dynamic>> completer = Completer();
  final List<String> claimedOrderIds = [];

  @override
  Future<List<TicketModel>> getPlazaTickets() async => tickets;

  @override
  Future<ApiResponse<dynamic>> giveTicket({
    required String orderId,
    String? tvcode,
    String? orderHash,
  }) async {
    claimedOrderIds.add(orderId);
    return completer.future;
  }
}
