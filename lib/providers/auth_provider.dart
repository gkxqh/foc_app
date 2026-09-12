import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../models/saved_account.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiClient _client = ApiClient();

  static const _kRememberEnabled = 'remember_enabled';
  static const _kSavedAccounts = 'saved_accounts';

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
    final prefs = await SharedPreferences.getInstance();

    // 优先读取本地持久化缓存的用户信息，实现秒开与状态保持。
    // 登录态必须同时持有 token：仅有缓存而无 token 时视为未登录，避免缓存独立造成假登录。
    final hasToken =
        _client.accessToken != null && _client.accessToken!.isNotEmpty;
    try {
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

  // ============ 本机保存账号（QQ 式快速切换） ============

  /// 读取本机保存的全部账号
  Future<List<SavedAccount>> loadSavedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kSavedAccounts) ?? [];
      return raw.map((s) => SavedAccount.fromJson(jsonDecode(s))).toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistSavedAccounts(List<SavedAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kSavedAccounts,
      accounts.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  /// 登录成功后保存/更新账号（同手机号覆盖）
  Future<void> upsertSavedAccount(SavedAccount account) async {
    final list = await loadSavedAccounts();
    list.removeWhere((a) => a.phone == account.phone);
    list.add(account);
    await _persistSavedAccounts(list);
  }

  Future<void> removeSavedAccount(String phone) async {
    final list = await loadSavedAccounts();
    list.removeWhere((a) => a.phone == phone);
    await _persistSavedAccounts(list);
  }

  Future<void> clearSavedAccounts() async {
    await _persistSavedAccounts([]);
  }

  /// 切换到已保存的账号：静默验证其 token，有效则直接恢复登录态。
  /// 返回 null 表示成功；否则返回错误文案。
  /// 仅在服务端明确 401（token 过期/注销）时才移除该保存账号；
  /// 网络瞬时异常时保留账号，避免一次超时就误删仍有效的登录凭据。
  Future<String?> switchToSavedAccount(SavedAccount account) async {
    await _client.setToken(account.token);
    final (userInfo, isAuthError) = await _authService.getUserInfoDetailed();
    if (userInfo == null) {
      await _client.clearToken();
      if (isAuthError) {
        // token 已过期/账号已注销：移除该保存账号
        await removeSavedAccount(account.phone);
        return '该账号登录已过期，请重新验证码登录';
      }
      // 网络异常：该账号仍保留在列表中，可稍后重试
      return '网络异常，请检查网络后重试';
    }
    _user = userInfo;
    _isLoggedIn = true;
    await _saveUserToCache(userInfo);
    // 刷新账号快照（昵称/头像可能变更）
    await upsertSavedAccount(
      SavedAccount(
        phone: account.phone,
        token: account.token,
        nickname: userInfo.nickname,
        avatarUrl: userInfo.avatarUrl,
        role: userInfo.role,
        savedAt: account.savedAt,
      ),
    );
    notifyListeners();
    return null;
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
      // 「记住此设备」开启时保存账号到本机列表，退出后可在登录页一键切换
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kRememberEnabled) ?? true) {
        final token = _client.accessToken;
        if (token != null && token.isNotEmpty) {
          await upsertSavedAccount(
            SavedAccount(
              phone: phone,
              token: token,
              nickname: _user?.nickname ?? '',
              avatarUrl: _user?.avatarUrl ?? '',
              role: _user?.role ?? 'user',
              savedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        }
      }
      _isLoading = false;
      notifyListeners();
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // 「记住此设备」开关：关闭时清空本机保存的账号列表
  Future<void> setRememberEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRememberEnabled, enabled);
    if (!enabled) {
      await prefs.remove(_kSavedAccounts);
    }
  }

  Future<bool> isRememberEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kRememberEnabled) ?? true;
  }

  Future<bool> hasSavedAccount(String phone) async {
    final list = await loadSavedAccounts();
    return list.any((a) => a.phone == phone);
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
      // 「记住登录」开启时保留备份 token（服务端 30 天内仍有效），
      // 下次打开 App 或重新登录可静默恢复；关闭状态则一并清除
      final rememberEnabled = prefs.getBool(_kRememberEnabled) ?? true;
      if (!rememberEnabled) {
        await prefs.remove(_kSavedAccounts);
      }
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
