import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants/api_constants.dart';
import '../models/app_update_model.dart';

class UpdateService {
  // GitHub 专用 Dio：绝不复用 ApiClient——它会给所有请求附加业务后端的
  // Bearer token，发往 GitHub 属于凭据泄漏；APK 大文件下载也需要独立的超时策略
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      // receiveTimeout 约束的是相邻数据块的间隔而非总时长：国内经 GitHub CDN
      // 下载 APK 整体偏慢但只要还在出数据就不应中断，中断与取消交给进度条和用户
      receiveTimeout: const Duration(seconds: 60),
      // GitHub API 强制要求 User-Agent，缺失直接 403
      headers: {'User-Agent': 'foc_app'},
    ),
  );

  /// 拉取最新正式 Release（latest 端点自动排除 draft 与 pre-release）。
  /// 网络失败、限流等异常直接抛出，由调用方决定静默还是提示。
  Future<AppUpdateInfo> fetchLatestRelease() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '${ApiConstants.githubApiBase}/repos/${ApiConstants.githubRepo}/releases/latest',
    );
    final data = res.data;
    if (data == null) {
      throw Exception('GitHub Releases 响应为空');
    }
    final assets = (data['assets'] as List?) ?? const [];
    final info = AppUpdateInfo.fromGitHubJson(data, pickApkAsset(assets, _deviceAbi()));
    if (info.tagName.isEmpty) {
      throw Exception('GitHub Releases 响应缺少 tag_name');
    }
    return info;
  }

  /// Dart VM 报告的 Android ABI（Platform.version 形如 …on "android_arm64"）
  String _deviceAbi() {
    final v = Platform.version.toLowerCase();
    if (v.contains('android_arm64')) return 'arm64-v8a';
    if (v.contains('android_arm')) return 'armeabi-v7a';
    if (v.contains('android_x64')) return 'x86_64';
    if (v.contains('android_ia32')) return 'x86';
    return '';
  }

  /// 从 Release assets 中选 APK：优先按设备 ABI 匹配关键词，其次任一分 ABI 包，
  /// 最后退回通用整包。静态方法便于对资产解析做纯函数单测。
  static Map<String, dynamic>? pickApkAsset(List<dynamic> assets, String abi) {
    final apks = assets
        .whereType<Map>()
        .map((a) => Map<String, dynamic>.from(a))
        .where((a) => (a['name']?.toString() ?? '').toLowerCase().endsWith('.apk'))
        .toList();
    if (apks.isEmpty) return null;

    bool hasKeyword(Map<String, dynamic> a, List<String> keywords) =>
        keywords.any((k) => a['name'].toString().toLowerCase().contains(k));

    // 兼容两套产物命名：flutter --split-per-abi 默认（arm64-v8a）与
    // 仓库实际发布产物（foc_app_v1.0.1_arm64.apk 这类简写）
    final keywords = switch (abi) {
      'arm64-v8a' => ['arm64-v8a', 'arm64'],
      'armeabi-v7a' => ['armeabi-v7a', 'armeabi', 'arm32'],
      'x86_64' => ['x86_64'],
      'x86' => ['x86'],
      _ => <String>[],
    };
    if (keywords.isNotEmpty) {
      final exact = apks.firstWhereOrNull(
        (a) => hasKeyword(a, keywords),
      );
      if (exact != null) return exact;
    }
    final splitPkgs = apks
        .where((a) => hasKeyword(a, const ['arm64', 'armeabi', 'arm32', 'x86']))
        .toList();
    if (splitPkgs.isNotEmpty) return splitPkgs.first;
    return apks.first;
  }

  /// 远端版本是否比当前版本新：按 `.` 分段做数值比较（1.10 > 1.9），
  /// 兼容 `v` 前缀；任一版本无法解析为纯数字分段时返回 false，
  /// 避免异常 tag 触发无意义的更新提示。
  static bool isNewerVersion(String remote, String current) {
    final r = _parseVersionSegments(remote);
    final c = _parseVersionSegments(current);
    if (r == null || c == null) return false;
    final len = r.length > c.length ? r.length : c.length;
    for (var i = 0; i < len; i++) {
      final rv = i < r.length ? r[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (rv != cv) return rv > cv;
    }
    return false;
  }

  static List<int>? _parseVersionSegments(String input) {
    var s = input.trim().toLowerCase();
    if (s.startsWith('v')) s = s.substring(1);
    s = s.split('+').first; // 剥离构建号（如 1.0.2+3）
    if (s.isEmpty) return null;
    final segments = <int>[];
    for (final part in s.split('.')) {
      final n = int.tryParse(part.trim());
      if (n == null) return null;
      segments.add(n);
    }
    return segments;
  }

  /// 下载 APK 到应用缓存目录，返回完整路径；进度与取消经参数透传。
  Future<String> downloadApk({
    required String url,
    required String fileName,
    required CancelToken cancelToken,
    required void Function(int received, int total) onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final savePath = '${dir.path}/$fileName';
    await _dio.download(
      url,
      savePath,
      cancelToken: cancelToken,
      deleteOnError: true, // 中断/取消时清掉残包，避免下次误装损坏的 APK
      onReceiveProgress: onProgress,
    );
    return savePath;
  }

  /// 请求「安装未知应用」授权后调起系统安装器；未授权或调起失败时抛出可展示的异常。
  Future<void> installApk(String apkPath) async {
    // 首次会跳转系统「允许安装未知应用」设置页，用户返回后 future 才完成
    final status = await Permission.requestInstallPackages.request();
    if (!status.isGranted) {
      throw Exception('未授予「安装未知应用」权限，无法安装更新');
    }
    final result = await OpenFilex.open(
      apkPath,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception('无法调起安装器：${result.message}');
    }
  }
}

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
