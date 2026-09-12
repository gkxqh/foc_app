import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/models/ticket_model.dart';
import 'package:foc_app/models/user_model.dart';
import 'package:foc_app/services/widget_snapshot_service.dart';

TicketModel _ticket(
  String id,
  String status, {
  String device = '笔记本',
  String brand = '联想',
  String fault = '蓝屏',
  String campus = '江安',
  String tech = '',
}) {
  return TicketModel(
    id: id,
    createTime: '2026-09-12 10:00:00',
    deviceType: device,
    computerBrand: brand,
    faultType: fault,
    repairDescription: 'desc',
    repairImageUrl: '',
    repairStatus: status,
    campus: campus,
    technicianName: tech,
  );
}

void main() {
  group('WidgetSnapshotService.priority 渲染排序', () {
    test('技术员视角：待我确认 > 维修中 > 待用户确认 > 待分配', () {
      expect(
        WidgetSnapshotService.priority('TechConfirming', technician: true),
        lessThan(WidgetSnapshotService.priority('Repairing', technician: true)),
      );
      expect(
        WidgetSnapshotService.priority('Repairing', technician: true),
        lessThan(
          WidgetSnapshotService.priority('UserConfirming', technician: true),
        ),
      );
      expect(
        WidgetSnapshotService.priority('UserConfirming', technician: true),
        lessThan(WidgetSnapshotService.priority('Pending', technician: true)),
      );
    });

    test('用户视角：待你确认 > 维修中 > 待技术员确认 > 待分配', () {
      expect(
        WidgetSnapshotService.priority('UserConfirming', technician: false),
        lessThan(WidgetSnapshotService.priority('Repairing', technician: false)),
      );
      expect(
        WidgetSnapshotService.priority('TechConfirming', technician: false),
        greaterThan(WidgetSnapshotService.priority('Repairing', technician: false)),
      );
    });
  });

  group('WidgetSnapshotService.buildPayload', () {
    test('技术员视角：完结单被过滤、可操作单置顶、余量与计数正确', () {
      final user = UserModel(
        uid: 't1',
        role: 'technician',
        available: '3',
        maxConcurrent: 2,
        nickname: '小王',
      );
      final payload = WidgetSnapshotService.buildPayload(
        user: user,
        role: 'technician',
        uid: 't1',
        tickets: [
          _ticket('a', 'Repairing'),
          _ticket('b', 'Done'),
          _ticket('c', 'TechConfirming'),
          _ticket('d', 'Canceled'),
        ],
      );

      expect(payload['loggedIn'], isTrue);
      expect(payload['role'], 'technician');
      expect(payload['quota'], '3');
      expect(payload['maxConcurrent'], 2);

      final tickets = payload['tickets'] as List;
      expect(tickets, hasLength(2)); // Done/Canceled 被过滤
      expect((tickets.first as Map)['id'], 'c'); // 待我确认置顶
      expect((tickets.first as Map)['status'], 'TechConfirming');
      expect((tickets.first as Map)['brand'], '联想');
      expect((tickets.first as Map)['fault'], '蓝屏');

      expect(payload['countTotal'], 2);
      expect(payload['countTechConfirm'], 1);
      expect(payload['countUserConfirm'], 0);
    });

    test('用户视角：待你确认的单排最前，额度原样透传', () {
      final user = UserModel(uid: 'u1', role: 'user', available: '2');
      final payload = WidgetSnapshotService.buildPayload(
        user: user,
        role: 'user',
        uid: 'u1',
        tickets: [
          _ticket('a', 'Pending', tech: ''),
          _ticket('b', 'UserConfirming', tech: '小王'),
        ],
      );

      final tickets = payload['tickets'] as List;
      expect((tickets.first as Map)['id'], 'b');
      expect((tickets.first as Map)['tech'], '小王');
      expect(payload['countUserConfirm'], 1);
      expect(payload['countTotal'], 2);
    });

    test('未登录 / 无用户信息：loggedIn 为 false 且额度为空', () {
      final payload = WidgetSnapshotService.buildPayload(
        user: null,
        role: 'user',
        uid: 'u1',
        tickets: [_ticket('a', 'Repairing')],
      );
      expect(payload['loggedIn'], isFalse);
      expect(payload['quota'], '');
      expect(payload['tickets'], isEmpty);
    });
  });

  group('WidgetSnapshotService.loggedOutPayload', () {
    test('包含 schema 版本且工单清空', () {
      final payload = WidgetSnapshotService.loggedOutPayload();
      expect(payload['v'], WidgetSnapshotService.schemaVersion);
      expect(payload['loggedIn'], isFalse);
      expect(payload['tickets'], isEmpty);
      expect(payload['countTotal'], 0);
    });
  });
}
