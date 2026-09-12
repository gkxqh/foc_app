import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/event_model.dart';

class EventService {
  final ApiClient _client = ApiClient();

  // 获取活动列表。
  // 加载失败时抛出异常，由调用方区分「加载失败」与「确实没有活动」，
  // 避免网络错误被误显示为空态；单条脏数据仍跳过，不影响整体列表。
  Future<List<EventModel>> getEvents() async {
    final res = await _client.get(ApiConstants.getEvent);
    List? rawList;
    if (res.raw is Map && res.raw['activities'] is List) {
      rawList = res.raw['activities'] as List;
    } else if (res.raw is List) {
      rawList = res.raw as List;
    }

    if (rawList == null) {
      if (!res.success) {
        throw Exception(res.message ?? '活动加载失败');
      }
      return [];
    }

    final List<EventModel> list = [];
    for (final item in rawList) {
      try {
        // fromJson 内已自动计算活动状态
        list.add(EventModel.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {}
    }
    return list;
  }

  // 招新 / 飞扬维修部或研发部报名
  Future<bool> registerEvent({
    required int eventId,
    required String name,
    required String gender,
    required List<String> departments,
    required List<String> freeTimes,
  }) async {
    final res = await _client.post(
      ApiConstants.regEvent,
      data: {
        'id': eventId,
        'name': name,
        'gender': gender,
        'department': departments.join(','),
        'free_time': freeTimes.join(','),
      },
    );
    return res.success;
  }

  // 获取用户幸运号码（服务端要求 activity_id + user_id 两个参数）
  Future<LuckyNumberModel?> getLuckyNum(int eventId, String uid) async {
    final res = await _client.get(
      ApiConstants.getLuckyNum,
      queryParameters: {'activity_id': eventId, 'user_id': uid},
    );
    if (res.success && res.raw != null && res.raw is Map) {
      return LuckyNumberModel.fromJson(Map<String, dynamic>.from(res.raw));
    }
    return null;
  }
}
