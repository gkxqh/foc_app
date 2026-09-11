class UserModel {
  final String uid;
  final String id;
  final String role; // 'user', 'technician', 'admin'
  final String email;
  final String phone;
  final String campus;
  final int canDuo; // 是否跨校区接单意愿 (1 or 0)
  final String nickname;
  final String avatarUrl;
  final String? wants; // a, b, c, d, e (技术员接单意愿)
  final String? available;
  final int maxConcurrent; // 同时接单上限（自动派单硬条件，服务端限 1-10）
  final String? tempEmail;
  final String? qq;

  UserModel({
    this.uid = '',
    this.id = '',
    this.role = 'user',
    this.email = '',
    this.phone = '',
    this.campus = '',
    this.canDuo = 0,
    this.nickname = '',
    this.avatarUrl = '',
    this.wants,
    this.available,
    this.maxConcurrent = 1,
    this.tempEmail,
    this.qq,
  });

  bool get isTechnician => role == 'technician';
  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid']?.toString() ?? json['id']?.toString() ?? '',
      id: json['id']?.toString() ?? json['uid']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      campus: json['campus']?.toString() ?? '',
      canDuo: (json['canDuo'] is int)
          ? json['canDuo']
          : int.tryParse(json['canDuo']?.toString() ?? '0') ?? 0,
      nickname: json['nickname']?.toString() ?? '',
      avatarUrl:
          json['avatar']?.toString() ?? json['avatarUrl']?.toString() ?? '',
      wants: json['wants']?.toString(),
      available: json['available']?.toString(),
      maxConcurrent: (json['max_concurrent'] is int)
          ? json['max_concurrent']
          : int.tryParse(json['max_concurrent']?.toString() ?? '') ?? 1,
      tempEmail: json['temp_email']?.toString(),
      qq: json['qq']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'id': id,
      'role': role,
      'email': email,
      'phone': phone,
      'campus': campus,
      'canDuo': canDuo,
      'nickname': nickname,
      'avatar': avatarUrl,
      'avatarUrl': avatarUrl,
      'wants': wants,
      'available': available,
      'max_concurrent': maxConcurrent,
      'temp_email': tempEmail,
      'qq': qq,
    };
  }

  // 资料更新接口的白名单字段（与小程序原版 /v1/user/setuser 契约一致），
  // 严禁携带 role/uid 等服务端不接受的字段，避免超额提交带来提权风险。
  Map<String, dynamic> toUpdateJson() {
    return {
      'id': id,
      'campus': campus,
      'avatar': avatarUrl,
      'nickname': nickname,
    };
  }

  UserModel copyWith({
    String? uid,
    String? id,
    String? role,
    String? email,
    String? phone,
    String? campus,
    int? canDuo,
    String? nickname,
    String? avatarUrl,
    String? wants,
    String? available,
    int? maxConcurrent,
    String? tempEmail,
    String? qq,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      id: id ?? this.id,
      role: role ?? this.role,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      campus: campus ?? this.campus,
      canDuo: canDuo ?? this.canDuo,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      wants: wants ?? this.wants,
      available: available ?? this.available,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
      tempEmail: tempEmail ?? this.tempEmail,
      qq: qq ?? this.qq,
    );
  }
}
