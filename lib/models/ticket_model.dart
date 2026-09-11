class TicketModel {
  final String id;
  final String createTime;
  final String deviceType;
  final String computerBrand;
  final String faultType;
  final String repairDescription;
  final String repairImageUrl;
  final String? completeImageUrl;
  final String repairStatus; // Pending, Repairing, UserConfirming, TechConfirming, Done, Closed, Canceled
  final String campus;
  final String? qqNumber;
  final String? phone;
  final String? model;
  final String? warrantyStatus; // expired, under, unknown
  final String? purchaseDate;
  final String? technicianId;
  final String? technicianName;
  final String? transcode; // 服务端下发的 6 位转单验证码

  TicketModel({
    required this.id,
    required this.createTime,
    required this.deviceType,
    required this.computerBrand,
    required this.faultType,
    required this.repairDescription,
    required this.repairImageUrl,
    this.completeImageUrl,
    required this.repairStatus,
    required this.campus,
    this.qqNumber,
    this.phone,
    this.model,
    this.warrantyStatus,
    this.purchaseDate,
    this.technicianId,
    this.technicianName,
    this.transcode,
  });

  bool get isFinished {
    final s = repairStatus.trim().toLowerCase();
    return s == 'done' || s == 'closed' || s == 'canceled' || s == 'cancelled';
  }

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    // 字段名以 fy_workorders 真实列名为准（2026-09-10 服务端核实）：
    // 手机号是 user_phone、购买日期是 machine_purchase_date；
    // getTicket 在按 uid 查询时会把 assigned_technician_id 覆写为「昵称 - 电话」展示串，
    // 并额外回填 assigned_technician_nickname；按 tid 查询时则是原始技术员 id。
    return TicketModel(
      id: json['id']?.toString() ?? '',
      createTime: json['create_time']?.toString() ?? '',
      deviceType: json['device_type']?.toString() ?? '',
      computerBrand: json['computer_brand']?.toString() ?? '',
      faultType: json['fault_type']?.toString() ?? '',
      repairDescription: json['repair_description']?.toString() ?? '',
      repairImageUrl: json['repair_image_url']?.toString() ?? '',
      completeImageUrl: json['complete_image_url']?.toString(),
      repairStatus: json['repair_status']?.toString() ?? 'Pending',
      campus: json['campus']?.toString() ?? '',
      qqNumber: json['qq_number']?.toString(),
      phone: (json['user_phone'] ?? json['phone'])?.toString(),
      model: json['model']?.toString(),
      warrantyStatus: json['warranty_status']?.toString(),
      purchaseDate: (json['machine_purchase_date'] ?? json['purchase_date'])
          ?.toString(),
      technicianId: json['assigned_technician_id']?.toString(),
      technicianName: json['assigned_technician_nickname']?.toString(),
      transcode: json['transcode']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'create_time': createTime,
      'device_type': deviceType,
      'computer_brand': computerBrand,
      'fault_type': faultType,
      'repair_description': repairDescription,
      'repair_image_url': repairImageUrl,
      'complete_image_url': completeImageUrl,
      'repair_status': repairStatus,
      'campus': campus,
      'qq_number': qqNumber,
      'user_phone': phone,
      'model': model,
      'warranty_status': warrantyStatus,
      'machine_purchase_date': purchaseDate,
      'assigned_technician_id': technicianId,
      'assigned_technician_nickname': technicianName,
      'transcode': transcode,
    };
  }

  TicketModel copyWith({
    String? id,
    String? createTime,
    String? deviceType,
    String? computerBrand,
    String? faultType,
    String? repairDescription,
    String? repairImageUrl,
    String? completeImageUrl,
    String? repairStatus,
    String? campus,
    String? qqNumber,
    String? phone,
    String? model,
    String? warrantyStatus,
    String? purchaseDate,
    String? technicianId,
    String? technicianName,
    String? transcode,
  }) {
    return TicketModel(
      id: id ?? this.id,
      createTime: createTime ?? this.createTime,
      deviceType: deviceType ?? this.deviceType,
      computerBrand: computerBrand ?? this.computerBrand,
      faultType: faultType ?? this.faultType,
      repairDescription: repairDescription ?? this.repairDescription,
      repairImageUrl: repairImageUrl ?? this.repairImageUrl,
      completeImageUrl: completeImageUrl ?? this.completeImageUrl,
      repairStatus: repairStatus ?? this.repairStatus,
      campus: campus ?? this.campus,
      qqNumber: qqNumber ?? this.qqNumber,
      phone: phone ?? this.phone,
      model: model ?? this.model,
      warrantyStatus: warrantyStatus ?? this.warrantyStatus,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      technicianId: technicianId ?? this.technicianId,
      technicianName: technicianName ?? this.technicianName,
      transcode: transcode ?? this.transcode,
    );
  }
}
