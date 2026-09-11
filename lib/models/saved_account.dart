/// 本机保存的登录账号（QQ 式快速切换）。
/// token 为服务端 fy_app_tokens 30 天凭据，退出登录不会吊销。
class SavedAccount {
  final String phone;
  final String token;
  final String nickname;
  final String avatarUrl;
  final String role;
  final int savedAt; // 毫秒时间戳

  const SavedAccount({
    required this.phone,
    required this.token,
    this.nickname = '',
    this.avatarUrl = '',
    this.role = 'user',
    required this.savedAt,
  });

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    return SavedAccount(
      phone: json['phone']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      savedAt: (json['savedAt'] is int) ? json['savedAt'] : 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'token': token,
    'nickname': nickname,
    'avatarUrl': avatarUrl,
    'role': role,
    'savedAt': savedAt,
  };

  /// 138****0000 形式的掩码手机号
  String get maskedPhone {
    if (phone.length == 11) {
      return '${phone.substring(0, 3)}****${phone.substring(7)}';
    }
    return phone;
  }
}
