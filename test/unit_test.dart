import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/core/theme/app_theme.dart';
import 'package:foc_app/models/event_model.dart';
import 'package:foc_app/models/ticket_model.dart';
import 'package:foc_app/models/user_model.dart';

void main() {
  group('UserModel tests', () {
    test('User role check and deserialization', () {
      final json = {
        'uid': '2021001',
        'role': 'technician',
        'nickname': '飞扬小助手',
        'campus': '江安',
        'wants': 'e',
        'canDuo': 1,
      };

      final user = UserModel.fromJson(json);
      expect(user.uid, '2021001');
      expect(user.isTechnician, true);
      expect(user.isAdmin, false);
      expect(user.canDuo, 1);
      expect(user.wants, 'e');
    });

    test('toUpdateJson 仅包含后端白名单字段，不携带 role/uid', () {
      final user = UserModel.fromJson({
        'id': '2021001',
        'role': 'technician',
        'nickname': '飞扬小助手',
        'campus': '江安',
        'avatar': 'https://example.com/a.png',
        'phone': '13800000000',
      });

      final payload = user.toUpdateJson();
      expect(payload.keys.toSet(), {'id', 'campus', 'avatar', 'nickname'});
      expect(payload.containsKey('role'), false);
      expect(payload.containsKey('uid'), false);
      expect(payload['id'], '2021001');
      expect(payload['avatar'], 'https://example.com/a.png');
    });

    test('无头像时 avatarUrl 为空字符串，不再回落第三方图床', () {
      final user = UserModel.fromJson({'id': '1', 'nickname': '同学'});
      expect(user.avatarUrl, '');
    });
  });

  group('TicketModel tests', () {
    test('Ticket status and finish state', () {
      final activeTicket = TicketModel(
        id: 'T1001',
        createTime: '2026-09-09 12:00:00',
        deviceType: '笔记本',
        computerBrand: '联想 Lenovo',
        faultType: '设备清灰',
        repairDescription: '风扇异响',
        repairImageUrl: 'https://example.com/img.jpg',
        repairStatus: 'Repairing',
        campus: '江安',
      );

      expect(activeTicket.isFinished, false);
      expect(AppTheme.getStatusText(activeTicket.repairStatus), '维修中');

      final doneTicket = TicketModel(
        id: 'T1002',
        createTime: '2026-09-09 12:00:00',
        deviceType: '台式机',
        computerBrand: '戴尔 DELL',
        faultType: '系统重装',
        repairDescription: '蓝屏重装系统',
        repairImageUrl: 'https://example.com/img.jpg',
        repairStatus: 'Done',
        campus: '望江',
      );

      expect(doneTicket.isFinished, true);
      expect(AppTheme.getStatusText(doneTicket.repairStatus), '已完成');
    });

    test('fromJson 解析服务端下发的 transcode，copyWith 保留未变更字段', () {
      final ticket = TicketModel.fromJson({
        'id': 'T1001',
        'repair_status': 'Repairing',
        'transcode': '483920',
      });

      expect(ticket.transcode, '483920');

      final updated = ticket.copyWith(repairStatus: 'Done');
      expect(updated.repairStatus, 'Done');
      // 状态流转后转单码等其他字段不丢失
      expect(updated.transcode, '483920');
      expect(updated.id, 'T1001');
    });

    test('fromJson 使用 fy_workorders 真实列名（user_phone / machine_purchase_date）', () {
      // 按 uid 查询时服务端会把 assigned_technician_id 覆写为「昵称 - 电话」并回填昵称
      final ticket = TicketModel.fromJson({
        'id': 'T1001',
        'repair_status': 'Repairing',
        'user_phone': '13800000000',
        'machine_purchase_date': '2024-06-01',
        'qq_number': 'QQ号|123456',
        'transcode': '483920',
        'assigned_technician_id': '张三 - 13900000000',
        'assigned_technician_nickname': '张三',
      });

      expect(ticket.phone, '13800000000');
      expect(ticket.purchaseDate, '2024-06-01');
      expect(ticket.technicianName, '张三');
      expect(ticket.qqNumber, 'QQ号|123456');
    });
  });

  group('EventModel tests', () {
    test('Event status calculation', () {
      final event = EventModel(
        id: 1,
        title: '2026秋季招新',
        description: '四川大学飞扬俱乐部招新活动',
        signupStartTime: '2020-01-01 00:00:00',
        signupEndTime: '2020-01-10 00:00:00',
        endTime: '2020-01-20 00:00:00',
      );

      event.calculateStatus();
      expect(event.status, 4); // 活动已结束
      expect(event.statusText, '已结束');
    });

    test('Parse real backend activity JSON', () {
      final json = {
        "id": "5",
        "name": "2025年终大会",
        "type": "讲座",
        "description": "飞扬俱乐部2025年年终大会来啦！！！",
        "poster": "https://qncdn.feiyang.ac.cn/avatar/sample.jpg",
        "create_time": "2025-12-15 18:02:10",
        "start_time": "2025-12-20 19:30:00",
        "end_time": "2025-12-20 21:30:00",
        "signup_start_time": "2025-12-15 00:00:00",
        "signup_end_time": "2025-12-20 21:00:00",
        "isLucky": "1",
        "registered": false,
        "max_luckynum": "103"
      };

      final event = EventModel.fromJson(json);
      expect(event.id, 5);
      expect(event.title, '2025年终大会');
      expect(event.type, '讲座');
      expect(event.isLucky, true);
      expect(event.registered, false);
      expect(event.maxLuckyNum, '103');
    });

    test('布尔字段类型容错：true / 1 / "1" / "true" 均可解析', () {
      final event = EventModel.fromJson({
        'id': '1',
        'name': '活动',
        'isLucky': true,
        'registered': '1',
      });
      expect(event.isLucky, true);
      expect(event.registered, true);

      final event2 = EventModel.fromJson({
        'id': '2',
        'name': '活动2',
        'isLucky': 1,
        'registered': 'true',
      });
      expect(event2.isLucky, true);
      expect(event2.registered, true);

      final event3 = EventModel.fromJson({
        'id': '3',
        'name': '活动3',
        'isLucky': 0,
        'registered': '0',
      });
      expect(event3.isLucky, false);
      expect(event3.registered, false);
    });
  });
}
