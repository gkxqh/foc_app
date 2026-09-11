import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiClient _client = ApiClient();

  UserModel? _user;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  // 验证码倒计时
  int _countdown = 0;
  Timer? _timer;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  int get countdown => _countdown;
  bool get isCountingDown => _countdown > 0;
  bool get isTechnician => _user?.isTechnician ?? false;

  /// 仅测试使用：直接注入用户状态
  @visibleForTesting
  void setUserForTest(UserModel? user) {
    _user = user;
    _isLoggedIn = user != null;
    notifyListeners();
  }

  AuthProvider() {
    _client.onUnauthorized = () {
      logout();
    };
  }

  Future<void> _saveUserToCache(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_info', jsonEncode(user.toJson()));
    } catch (_) {}
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    await _client.init();

    // 优先读取本地持久化缓存的用户信息，实现秒开与状态保持。
    // 登录态必须同时持有 token：仅有缓存而无 token 时视为未登录，避免缓存独立造成假登录。
    final hasToken =
        _client.accessToken != null && _client.accessToken!.isNotEmpty;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_user_info');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        _user = UserModel.fromJson(jsonDecode(cachedJson));
        _isLoggedIn = hasToken;
        if (!hasToken) {
          await prefs.remove('cached_user_info');
          _user = null;
        }
      }
    } catch (_) {}

    // 如果已持有 token，静默向服务端同步最新用户信息
    if (hasToken) {
      try {
        final userInfo = await _authService.getUserInfo();
        if (userInfo != null) {
          _user = userInfo;
          _isLoggedIn = true;
          await _saveUserToCache(userInfo);
        }
      } catch (_) {}
    }

    _isLoading = false;
    notifyListeners();
  }

  // 发送手机验证码（App 端走 phonesend 免鉴权接口，带 60s/小时频控）
  Future<ApiResponse<Map<String, dynamic>>> sendSmsCode(String phone) async {
    final res = await _authService.sendLoginCode(phone);
    if (res.success) {
      startCountdown();
    }
    return res;
  }

  void startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        _countdown--;
        notifyListeners();
      } else {
        _timer?.cancel();
      }
    });
    notifyListeners();
  }

  // 验证码登录 / 校验（App 端走 phonelogin 30 天 token；迁移分支保留旧接口）
  Future<bool> verifyAndLogin(
    String phone,
    String code, {
    bool isMigration = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    ApiResponse<Map<String, dynamic>> res;
    if (isMigration) {
      res = await _authService.userMigration(phone, code);
    } else {
      res = await _authService.loginWithCode(phone, code);
    }

    if (res.success) {
      final userInfo = await _authService.getUserInfo();
      _user = userInfo ?? UserModel(phone: phone);
      _isLoggedIn = true;
      // 无论能否拉到完整资料都落缓存，保证冷启动后登录态与资料一致
      await _saveUserToCache(_user!);
      _isLoading = false;
      notifyListeners();
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // 快捷刷新用户信息
  Future<void> refreshUserInfo() async {
    final userInfo = await _authService.getUserInfo();
    if (userInfo != null) {
      _user = userInfo;
      notifyListeners();
    }
  }

  // 更新资料
  Future<bool> updateUserInfo(UserModel newUser) async {
    _isLoading = true;
    notifyListeners();
    final ok = await _authService.setUserInfo(newUser);
    if (ok) {
      _user = newUser;
    }
    _isLoading = false;
    notifyListeners();
    return ok;
  }

  // 更新技术员设置（wants/canDuo/max_concurrent 走 setuser；available 仅管理员可改）
  Future<bool> updateTechSettings({
    required String wants,
    required int canDuo,
    required int maxConcurrent,
  }) async {
    _isLoading = true;
    notifyListeners();
    final ok = await _authService.setTechInfo(
      wants: wants,
      canDuo: canDuo,
      maxConcurrent: maxConcurrent,
    );
    if (ok && _user != null) {
      _user = _user!.copyWith(
        wants: wants,
        canDuo: canDuo,
        maxConcurrent: maxConcurrent,
      );
    }
    _isLoading = false;
    notifyListeners();
    return ok;
  }

  // 注销登录
  Future<void> logout() async {
    await _client.clearToken();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_user_info');
    } catch (_) {}
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
