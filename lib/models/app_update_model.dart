/// GitHub Release 解析出的应用更新信息。
class AppUpdateInfo {
  final String tagName; // 原始 tag，如 "v1.0.2"
  final String version; // 剥离 v 前缀后的版本号，用于版本比较与展示
  final String releaseName; // Release 标题
  final String changelog; // Release 说明（Markdown）
  final String downloadUrl; // 按设备 ABI 选中的 APK 直链；无可用 APK 时为空串
  final String fileName;
  final int downloadSize; // APK 字节数；未知为 -1
  final String htmlUrl; // Release 网页地址

  const AppUpdateInfo({
    required this.tagName,
    required this.version,
    required this.releaseName,
    required this.changelog,
    required this.downloadUrl,
    required this.fileName,
    required this.downloadSize,
    required this.htmlUrl,
  });

  bool get hasApk => downloadUrl.isNotEmpty;

  /// [apkAsset] 为调用方按设备 ABI 从 assets 中选出的 APK 资产（可为 null）。
  factory AppUpdateInfo.fromGitHubJson(
    Map<String, dynamic> json,
    Map<String, dynamic>? apkAsset,
  ) {
    final tagName = json['tag_name']?.toString() ?? '';
    final version = tagName.toLowerCase().startsWith('v')
        ? tagName.substring(1)
        : tagName;
    return AppUpdateInfo(
      tagName: tagName,
      version: version,
      releaseName: json['name']?.toString() ?? tagName,
      changelog: json['body']?.toString() ?? '',
      downloadUrl: apkAsset?['browser_download_url']?.toString() ?? '',
      fileName: apkAsset?['name']?.toString() ?? 'update.apk',
      downloadSize: (apkAsset?['size'] as num?)?.toInt() ?? -1,
      htmlUrl: json['html_url']?.toString() ?? '',
    );
  }
}
