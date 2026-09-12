import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/core/theme/app_theme.dart';
import 'package:foc_app/models/app_update_model.dart';
import 'package:foc_app/models/event_model.dart';
import 'package:foc_app/models/ticket_model.dart';
import 'package:foc_app/models/user_model.dart';
import 'package:foc_app/services/update_service.dart';

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

    test(
      'fromJson 使用 fy_workorders 真实列名（user_phone / machine_purchase_date）',
      () {
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
      },
    );
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

    test('报名已结束但活动未开始时应为 status 2「报名结束」', () {
      // 时间相对 now 构造，避免用例随时间推移失效
      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
      final now = DateTime.now();
      final event = EventModel(
        id: 2,
        title: '招新宣讲',
        description: '',
        signupStartTime: fmt(now.subtract(const Duration(days: 7))),
        signupEndTime: fmt(now.subtract(const Duration(hours: 1))),
        startTime: fmt(now.add(const Duration(hours: 1))),
        endTime: fmt(now.add(const Duration(hours: 3))),
      );

      event.calculateStatus();
      expect(event.status, 2);
      expect(event.statusText, '报名结束');
    });

    test('start_time 缺失时报名截止后仍视为进行中（向后兼容旧数据）', () {
      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
      final now = DateTime.now();
      final event = EventModel(
        id: 3,
        title: '无开始时间活动',
        description: '',
        signupStartTime: fmt(now.subtract(const Duration(days: 7))),
        signupEndTime: fmt(now.subtract(const Duration(hours: 1))),
        endTime: fmt(now.add(const Duration(hours: 3))),
      );

      event.calculateStatus();
      expect(event.status, 3);
      expect(event.statusText, '进行中');
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
        "max_luckynum": "103",
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

  group('UpdateService 版本比较', () {
    test('v 前缀与常规新版本', () {
      expect(UpdateService.isNewerVersion('v1.0.2', '1.0.1'), true);
      expect(UpdateService.isNewerVersion('v1.1.0', '1.0.9'), true);
      expect(UpdateService.isNewerVersion('2.0', '1.9.9'), true);
    });

    test('分段数值比较而非字典序（1.10 > 1.9）', () {
      expect(UpdateService.isNewerVersion('1.10.0', '1.9.9'), true);
      expect(UpdateService.isNewerVersion('v1.10', '1.9'), true);
      expect(UpdateService.isNewerVersion('1.2', '1.10'), false);
    });

    test('相同或更旧的版本不提示更新', () {
      expect(UpdateService.isNewerVersion('v1.0.1', '1.0.1'), false);
      expect(UpdateService.isNewerVersion('1.0.0', '1.0.1'), false);
      expect(UpdateService.isNewerVersion('0.9.9', '1.0.1'), false);
    });

    test('位数不齐时缺省段按 0 补齐', () {
      expect(UpdateService.isNewerVersion('v1.1', '1.0.5'), true);
      expect(UpdateService.isNewerVersion('v1.0', '1.0.1'), false);
    });

    test('无法解析的版本一律视为无更新，避免异常 tag 骚扰', () {
      expect(UpdateService.isNewerVersion('latest', '1.0.1'), false);
      expect(UpdateService.isNewerVersion('', '1.0.1'), false);
      expect(UpdateService.isNewerVersion('v1.0.2', 'dev'), false);
      expect(UpdateService.isNewerVersion('v1.0.2-beta.1', '1.0.1'), false);
    });
  });

  group('UpdateService.pickApkAsset 按 ABI 选择 APK', () {
    final assets = [
      {
        'name': 'app-armeabi-v7a-release.apk',
        'size': 18000000,
        'browser_download_url': 'https://example.com/app-armeabi-v7a-release.apk',
      },
      {
        'name': 'app-arm64-v8a-release.apk',
        'size': 20000000,
        'browser_download_url': 'https://example.com/app-arm64-v8a-release.apk',
      },
      {
        'name': 'app-x86_64-release.apk',
        'size': 21000000,
        'browser_download_url': 'https://example.com/app-x86_64-release.apk',
      },
      {
        'name': 'app-release.apk',
        'size': 55000000,
        'browser_download_url': 'https://example.com/app-release.apk',
      },
    ];

    test('优先精确匹配设备 ABI', () {
      expect(
        UpdateService.pickApkAsset(assets, 'arm64-v8a')?['name'],
        'app-arm64-v8a-release.apk',
      );
      expect(
        UpdateService.pickApkAsset(assets, 'armeabi-v7a')?['name'],
        'app-armeabi-v7a-release.apk',
      );
      expect(
        UpdateService.pickApkAsset(assets, 'x86_64')?['name'],
        'app-x86_64-release.apk',
      );
    });

    test('ABI 未知时退回任一分 ABI 包而非体积大的通用整包', () {
      expect(
        UpdateService.pickApkAsset(assets, '')?['name'],
        'app-armeabi-v7a-release.apk',
      );
    });

    test('仅通用整包时可用，且解析出下载直链', () {
      final universal = [
        {
          'name': 'app-release.apk',
          'size': 55000000,
          'browser_download_url': 'https://example.com/app-release.apk',
        },
      ];
      final picked = UpdateService.pickApkAsset(universal, 'arm64-v8a');
      expect(picked?['name'], 'app-release.apk');
    });

    test('兼容仓库实际发布产物命名（foc_app_v1.0.x_arm64.apk 简写）', () {
      final realAssets = [
        {
          'name': 'foc_app_v1.0.1_arm32.apk',
          'size': 32905976,
          'browser_download_url': 'https://example.com/foc_app_v1.0.1_arm32.apk',
        },
        {
          'name': 'foc_app_v1.0.1_arm64.apk',
          'size': 36763462,
          'browser_download_url': 'https://example.com/foc_app_v1.0.1_arm64.apk',
        },
        {
          'name': 'foc_app_v1.0.1_x86_64.apk',
          'size': 39484063,
          'browser_download_url': 'https://example.com/foc_app_v1.0.1_x86_64.apk',
        },
      ];
      expect(
        UpdateService.pickApkAsset(realAssets, 'arm64-v8a')?['name'],
        'foc_app_v1.0.1_arm64.apk',
      );
      expect(
        UpdateService.pickApkAsset(realAssets, 'armeabi-v7a')?['name'],
        'foc_app_v1.0.1_arm32.apk',
      );
      expect(
        UpdateService.pickApkAsset(realAssets, 'x86_64')?['name'],
        'foc_app_v1.0.1_x86_64.apk',
      );
      // 无 ABI 精确匹配时（如发布产物缺 x86_64 包）不误选通用整包
      expect(
        UpdateService.pickApkAsset(realAssets, '')?['name'],
        'foc_app_v1.0.1_arm32.apk',
      );
    });

    test('无任何 APK 资产时返回 null', () {
      expect(UpdateService.pickApkAsset([], 'arm64-v8a'), isNull);
      expect(
        UpdateService.pickApkAsset([
          {'name': 'source.zip', 'size': 1, 'browser_download_url': 'x'},
        ], 'arm64-v8a'),
        isNull,
      );
    });
  });

  group('AppUpdateInfo 解析', () {
    test('剥离 tag 的 v 前缀，按所选资产填充下载信息', () {
      final info = AppUpdateInfo.fromGitHubJson({
        'tag_name': 'v1.0.2',
        'name': '云上飞扬 v1.0.2',
        'body': '## 更新内容\n- 修复若干问题',
        'html_url': 'https://github.com/gkxqh/foc_app/releases/tag/v1.0.2',
      }, {
        'name': 'app-arm64-v8a-release.apk',
        'size': 20000000,
        'browser_download_url': 'https://example.com/app-arm64-v8a-release.apk',
      });

      expect(info.version, '1.0.2');
      expect(info.hasApk, true);
      expect(info.downloadUrl, 'https://example.com/app-arm64-v8a-release.apk');
      expect(info.downloadSize, 20000000);
      expect(info.changelog, contains('更新内容'));
    });

    test('无可用 APK 资产时 hasApk 为 false，更新检查会跳过', () {
      final info = AppUpdateInfo.fromGitHubJson({
        'tag_name': 'v1.0.2',
        'name': '云上飞扬 v1.0.2',
        'body': '',
        'html_url': '',
      }, null);

      expect(info.hasApk, false);
      expect(info.downloadUrl, isEmpty);
    });
  });
}
