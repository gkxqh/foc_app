import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/sys_config_model.dart';
import '../models/tech_stats_model.dart';

class ConfigService {
  final ApiClient _client = ApiClient();

  // 获取全局系统配置与公告
  Future<List<SysConfigItem>> getConfig() async {
    final res = await _client.get(ApiConstants.getConfig);
    List? list;
    if (res.raw is Map && res.raw['configs'] is List) {
      list = res.raw['configs'] as List;
    } else if (res.raw is List) {
      list = res.raw as List;
    }

    if (list != null) {
      return list
          .map(
            (item) => SysConfigItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }
    return [];
  }

  // 获取技术员排行榜 (总榜/江安/望江)
  Future<List<TopTechModel>> getTopTech({String? campus}) async {
    final query = <String, dynamic>{};
    if (campus == '江安') {
      query['campus'] = 'j';
    } else if (campus == '望江' || campus == '华西') {
      query['campus'] = 'm';
    }

    final res = await _client.get(
      ApiConstants.getTopTech,
      queryParameters: query,
    );
    List? list;
    if (res.raw is Map && res.raw['top_technicians'] is List) {
      list = res.raw['top_technicians'] as List;
    } else if (res.raw is List) {
      list = res.raw as List;
    }

    if (list != null) {
      return list
          .map((item) => TopTechModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    return [];
  }

  // 获取技术员年度总结
  // 服务端响应为 { success, year, data: { first_time, total_orders, ... } }，字段嵌套在 data 中。
  // success 但缺 data 视为「暂无维修记录」，返回空模型；请求/业务失败时抛出异常，
  // 由调用方区分「加载失败」与「暂无记录」，避免失败被误显示为 0 台。
  Future<TechSummaryModel> getTechSum() async {
    final res = await _client.get(ApiConstants.getTechSum);
    if (res.success) {
      final data = (res.raw is Map && res.raw['data'] is Map)
          ? Map<String, dynamic>.from(res.raw['data'])
          : <String, dynamic>{};
      return TechSummaryModel.fromJson(data);
    }
    throw Exception(res.message ?? '年度总结加载失败');
  }

  // 提交意见反馈
  Future<bool> putFeedback(String contact, String text) async {
    final res = await _client.post(
      ApiConstants.feedbackAdd,
      data: {'contact': contact, 'text': text},
    );
    return res.success;
  }
}
