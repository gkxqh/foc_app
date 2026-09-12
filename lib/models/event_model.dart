class EventModel {
  final int id;
  final String title;
  final String description;
  final String signupStartTime;
  final String signupEndTime;
  final String startTime; // 活动开始时间（服务端 start_time，可能缺失）
  final String endTime;
  final String? location;
  final String? poster;
  final String? type;
  final bool isLucky;
  final bool registered;
  final String? maxLuckyNum;
  int status; // 0: 未开始, 1: 报名中, 2: 报名结束, 3: 进行中, 4: 已结束, 5: 未知

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.signupStartTime,
    required this.signupEndTime,
    this.startTime = '',
    required this.endTime,
    this.location,
    this.poster,
    this.type,
    this.isLucky = false,
    this.registered = false,
    this.maxLuckyNum,
    this.status = 5,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final event = EventModel(
      id: (json['id'] is int)
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['name']?.toString() ?? json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      signupStartTime: json['signup_start_time']?.toString() ?? '',
      signupEndTime: json['signup_end_time']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      location: json['location']?.toString(),
      poster: json['poster']?.toString(),
      type: json['type']?.toString(),
      isLucky: _parseBool(json['isLucky']),
      registered: _parseBool(json['registered']),
      maxLuckyNum: json['max_luckynum']?.toString(),
    );
    // 状态在反序列化时自动计算，调用方无需再手动调用 calculateStatus
    event.calculateStatus();
    return event;
  }

  // 服务端布尔字段类型不稳定（true / 1 / '1' / 'true' 都出现过），统一在此归一化
  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == '1' || v == 'true';
    }
    return false;
  }

  void calculateStatus() {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final sStart = DateTime.parse(signupStartTime.replaceAll('/', '-'))
          .millisecondsSinceEpoch;
      final sEnd = DateTime.parse(signupEndTime.replaceAll('/', '-'))
          .millisecondsSinceEpoch;
      // start_time 缺失/不可解析时回退为报名结束时间：status 2 窗口收敛为 0，
      // 行为与旧版（报名截止即视为进行中）保持一致
      final start = (startTime.isEmpty)
          ? sEnd
          : DateTime.parse(startTime.replaceAll('/', '-'))
                .millisecondsSinceEpoch;
      final eEnd = DateTime.parse(endTime.replaceAll('/', '-'))
          .millisecondsSinceEpoch;

      if (now < sStart) {
        status = 0; // 报名未开始
      } else if (now <= sEnd) {
        status = 1; // 报名进行中（报名期与活动期重叠时报名状态优先）
      } else if (now < start) {
        status = 2; // 报名已结束，活动尚未开始
      } else if (now <= eEnd) {
        status = 3; // 活动进行中
      } else {
        status = 4; // 活动已结束
      }
    } catch (_) {
      status = 5;
    }
  }

  String get statusText {
    switch (status) {
      case 0:
        return '未开始';
      case 1:
        return '报名中';
      case 2:
        return '报名结束';
      case 3:
        return '进行中';
      case 4:
        return '已结束';
      default:
        return '未知';
    }
  }
}

class LuckyNumberModel {
  final String luckyNum;
  final bool isWinner;

  LuckyNumberModel({required this.luckyNum, required this.isWinner});

  factory LuckyNumberModel.fromJson(Map<String, dynamic> json) {
    return LuckyNumberModel(
      luckyNum: json['luckynum']?.toString() ?? '',
      isWinner: EventModel._parseBool(json['is_winner']),
    );
  }
}
