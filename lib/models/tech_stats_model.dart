class TopTechModel {
  final String nickname;
  final int count;
  final String? campus;

  TopTechModel({
    required this.nickname,
    required this.count,
    this.campus,
  });

  factory TopTechModel.fromJson(Map<String, dynamic> json) {
    return TopTechModel(
      nickname: json['nickname']?.toString() ?? '技术员',
      count: (json['count'] is int)
          ? json['count']
          : int.tryParse(json['count']?.toString() ?? '0') ?? 0,
      campus: json['campus']?.toString(),
    );
  }
}

class TechSummaryModel {
  final String firstTime;
  final String lastTime;
  final String totalOrders;
  final String shortestTime;
  final String longestTime;
  final String totalTime;

  TechSummaryModel({
    this.firstTime = '',
    this.lastTime = '',
    this.totalOrders = '0',
    this.shortestTime = '',
    this.longestTime = '',
    this.totalTime = '',
  });

  factory TechSummaryModel.fromJson(Map<String, dynamic> json) {
    return TechSummaryModel(
      firstTime: json['first_time']?.toString() ?? '',
      lastTime: json['last_time']?.toString() ?? '',
      totalOrders: json['total_orders']?.toString() ?? '0',
      shortestTime: json['shortest_time']?.toString() ?? '',
      longestTime: json['longest_time']?.toString() ?? '',
      totalTime: json['total_time']?.toString() ?? '',
    );
  }
}
