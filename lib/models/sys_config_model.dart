class SysConfigItem {
  final String name;
  final String info;
  final String data;

  SysConfigItem({required this.name, required this.info, required this.data});

  factory SysConfigItem.fromJson(Map<String, dynamic> json) {
    return SysConfigItem(
      name: json['name']?.toString() ?? '',
      info: json['info']?.toString() ?? '',
      data: json['data']?.toString() ?? '',
    );
  }
}
