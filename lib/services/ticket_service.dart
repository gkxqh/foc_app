import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/ticket_model.dart';

class TicketService {
  final ApiClient _client = ApiClient();

  // 获取工单列表 (普通用户或技术员)
  Future<List<TicketModel>> getTickets({String? uid, String? tid}) async {
    final query = <String, dynamic>{};
    if (uid != null && uid.isNotEmpty) query['uid'] = uid;
    if (tid != null && tid.isNotEmpty) query['tid'] = tid;

    final res = await _client.get(ApiConstants.getTicket, queryParameters: query);
    if (res.success && res.raw != null && res.raw is Map) {
      final listData = res.raw['data'];
      if (listData is List) {
        return listData
            .map((item) => TicketModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    }
    return [];
  }

  // 发起新报修
  Future<ApiResponse<dynamic>> submitTicket({
    String? uid,
    String? userNick,
    required String purchaseDate,
    required String phone,
    required String deviceType,
    required String computerBrand,
    required String description,
    required String imageUrl,
    required String faultType,
    required String qqOrContact,
    required String campus,
    required int duoCampus,
    required String warrantyStatus, // expired, under, unknown
    required String model,
  }) async {
    final finalImageUrl = imageUrl.isEmpty ? ApiConstants.defaultTicketImage : imageUrl;

    return await _client.post(
      ApiConstants.addTicket,
      data: {
        'uid': ?uid,
        'user_nick': ?userNick,
        'purchase_date': purchaseDate,
        'phone': phone,
        'device_type': deviceType,
        'brand': computerBrand,
        'description': description,
        'image': finalImageUrl,
        'fault_type': faultType,
        'qq': qqOrContact,
        'campus': campus,
        'DuoCampus': duoCampus,
        'warranty_status': warrantyStatus,
        'model': model.isNotEmpty ? model : 'default',
      },
    );
  }

  // 接单 / 转单
  // [give] 二维码携带 order_hash（服务端优先校验），手动输入的转单码走 tvcode
  Future<ApiResponse<dynamic>> giveTicket({
    required String orderId,
    String? tvcode,
    String? orderHash,
  }) async {
    return await _client.post(
      ApiConstants.giveTicket,
      data: {
        'order_id': orderId,
        'order_hash': ?orderHash,
        'tvcode': ?tvcode,
      },
    );
  }

  // 结束工单 (技术员)
  Future<ApiResponse<dynamic>> completeTicket(String orderId) async {
    return await _client.post(
      ApiConstants.completeTicket,
      data: {'order_id': orderId},
    );
  }

  // 设置工单状态 (取消 Canceled / 双向确认 UserConfirming / TechConfirming / Closed)
  Future<ApiResponse<dynamic>> setTicketStatus(String orderId, String status) async {
    return await _client.post(
      ApiConstants.setTicketStatus,
      data: {
        'tid': orderId,
        'repair_status': status,
      },
    );
  }

  // 上传维修完成凭证图片
  Future<ApiResponse<dynamic>> setCompleteImage(String orderId, String imageUrl) async {
    return await _client.post(
      ApiConstants.setCompleteImage,
      data: {
        'tid': orderId,
        'complete_image_url': imageUrl,
      },
    );
  }
}
