import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthService {
  final ApiClient _client = ApiClient();

  // 微信登录 / 凭证登录
  Future<ApiResponse<Map<String, dynamic>>> userLogin({String? code}) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiConstants.userLogin,
      data: {'code': code ?? ''},
    );
    if (res.success && res.raw != null && res.raw is Map) {
      final token = res.raw['access_token']?.toString();
      if (token != null && token.isNotEmpty) {
        await _client.setToken(token);
      }
    }
    return res;
  }

  // 发送手机注册/登录短信验证码
  Future<ApiResponse<Map<String, dynamic>>> sendRegisterCode(
    String phone,
  ) async {
    return await _client.post<Map<String, dynamic>>(
      ApiConstants.userRegister,
      data: {'phone': phone},
    );
  }

  // App 端短信登录：发送验证码（对应服务端 phonesend.php，免鉴权、带频控）
  Future<ApiResponse<Map<String, dynamic>>> sendLoginCode(String phone) async {
    return await _client.post<Map<String, dynamic>>(
      ApiConstants.phoneSend,
      data: {'phone': phone},
    );
  }

  // App 端短信登录：验证码校验并换取 30 天长效 token（对应服务端 phonelogin.php）
  Future<ApiResponse<Map<String, dynamic>>> loginWithCode(
    String phone,
    String code,
  ) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiConstants.phoneLogin,
      data: {'phone': phone, 'code': code},
    );
    if (res.success && res.raw != null && res.raw is Map) {
      final token = res.raw['access_token']?.toString();
      if (token != null && token.isNotEmpty) {
        await _client.setToken(token);
      }
    }
    return res;
  }

  // 手机号+验证码验证
  Future<ApiResponse<Map<String, dynamic>>> verifyCode(
    String phone,
    String code,
  ) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiConstants.userVerify,
      data: {'phone': phone, 'code': code},
    );
    if (res.success && res.raw != null && res.raw is Map) {
      final token = res.raw['access_token']?.toString();
      if (token != null && token.isNotEmpty) {
        await _client.setToken(token);
      }
    }
    return res;
  }

  // 老账号数据迁移
  Future<ApiResponse<Map<String, dynamic>>> userMigration(
    String phone,
    String code,
  ) async {
    final res = await _client.post<Map<String, dynamic>>(
      ApiConstants.userMigration,
      data: {'phone': phone, 'code': code},
    );
    if (res.success && res.raw != null && res.raw is Map) {
      final token = res.raw['access_token']?.toString();
      if (token != null && token.isNotEmpty) {
        await _client.setToken(token);
      }
    }
    return res;
  }

  // 获取当前用户信息
  Future<UserModel?> getUserInfo() async {
    final result = await getUserInfoDetailed();
    return result.$1;
  }

  /// 获取用户信息并区分失败原因，供需要区别对待的场景使用：
  /// 成功返回 (user, false)；401 表示 token 已失效返回 (null, true)；
  /// 超时/5xx 等瞬时异常返回 (null, false)，不应据此清除登录态或已保存账号。
  Future<(UserModel?, bool)> getUserInfoDetailed() async {
    final res = await _client.get(ApiConstants.getUserInfo);
    if (res.success && res.raw != null && res.raw is Map) {
      return (UserModel.fromJson(Map<String, dynamic>.from(res.raw)), false);
    }
    return (null, res.statusCode == 401);
  }

  // 更新普通用户信息（仅提交后端白名单字段，见 UserModel.toUpdateJson）
  Future<bool> setUserInfo(UserModel user) async {
    final res = await _client.post(
      ApiConstants.setUserInfo,
      data: user.toUpdateJson(),
    );
    return res.success;
  }

  // 更新技术员专属信息（wants/canDuo/max_concurrent 走 setuser 白名单；available 仅管理员可改，本人不提交）
  Future<bool> setTechInfo({
    required String wants,
    required int canDuo,
    required int maxConcurrent,
  }) async {
    final res = await _client.post(
      ApiConstants.setUserInfo,
      data: {'wants': wants, 'canDuo': canDuo, 'max_concurrent': maxConcurrent},
    );
    return res.success;
  }

  // 更换新手机号
  Future<ApiResponse<Map<String, dynamic>>> newPhone(String phone) async {
    return await _client.post<Map<String, dynamic>>(
      ApiConstants.newPhone,
      data: {'phone': phone},
    );
  }

  // 手机变更验证（服务端 phonechange_verify 只收 vcode，用户身份由 token 识别）
  Future<bool> verifyNewPhone(String code) async {
    final res = await _client.post(
      ApiConstants.phoneVerify,
      data: {'vcode': code},
    );
    return res.success;
  }

  // 更换邮箱
  Future<bool> newEmail(String email) async {
    final res = await _client.post(
      ApiConstants.newEmail,
      data: {'email': email},
    );
    return res.success;
  }

  // 注销账号
  Future<bool> deleteAccount() async {
    final res = await _client.post(ApiConstants.userDelete, data: {});
    if (res.success) {
      await _client.clearToken();
    }
    return res.success;
  }
}
