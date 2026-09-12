import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_update_model.dart';
import '../services/update_service.dart';

enum UpdateCheckResult { newVersion, upToDate, failed }

enum UpdateStatus { idle, checking, available, downloading, installing, error }

class UpdateProvider extends ChangeNotifier {
  final UpdateService _service = UpdateService();

  static const _keyIgnoredVersion = 'update_ignored_version';

  UpdateStatus _status = UpdateStatus.idle;
  AppUpdateInfo? _info;
  double _progress = 0; // 0..1
  String? _errorMessage;
  String _currentVersion = '';
  String? _apkPath; // 已下载完成的安装包路径，用于直接重试安装、避免重复下载
  CancelToken? _cancelToken;
  bool _dialogVisible = false; // 自动检查与手动入口防重复弹窗

  UpdateStatus get status => _status;
  AppUpdateInfo? get info => _info;
  double get progress => _progress;
  String? get errorMessage => _errorMessage;
  String get currentVersion => _currentVersion;
  bool get dialogVisible => _dialogVisible;
  bool get isBusy =>
      _status == UpdateStatus.downloading || _status == UpdateStatus.installing;

  void setDialogVisible(bool visible) {
    if (_dialogVisible == visible) return;
    _dialogVisible = visible;
    notifyListeners();
  }

  /// 检查更新。auto 为 true 时全程静默：失败不落错误态，命中「忽略的版本」
  /// 视为无更新，由首页自动检查调用。
  Future<UpdateCheckResult> checkForUpdate({bool auto = false}) async {
    // 更新渠道只有 Android 侧载 APK，其他平台无安装包可下
    if (!Platform.isAndroid) return UpdateCheckResult.upToDate;
    // 检查中/下载中不重复发起，避免并发请求与状态互踩
    if (isBusy || _status == UpdateStatus.checking) {
      return _info != null ? UpdateCheckResult.newVersion : UpdateCheckResult.upToDate;
    }

    _status = UpdateStatus.checking;
    notifyListeners();
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;
      final info = await _service.fetchLatestRelease();
      _info = info;

      final hasUpdate =
          info.hasApk && UpdateService.isNewerVersion(info.version, _currentVersion);
      if (!hasUpdate) {
        _status = UpdateStatus.idle;
        notifyListeners();
        return UpdateCheckResult.upToDate;
      }
      if (auto && await _ignoredVersion() == info.version) {
        _status = UpdateStatus.idle;
        notifyListeners();
        return UpdateCheckResult.upToDate;
      }
      _status = UpdateStatus.available;
      notifyListeners();
      return UpdateCheckResult.newVersion;
    } catch (_) {
      // 检查失败回到 idle：自动检查保持静默，手动检查由调用方给失败反馈
      _status = UpdateStatus.idle;
      notifyListeners();
      return UpdateCheckResult.failed;
    }
  }

  /// 「立即更新」入口：安装包已就绪时直接调起安装，否则先下载。
  Future<void> updateNow() async {
    if (_info == null || isBusy) return;
    final apkPath = _apkPath;
    if (apkPath != null) {
      await _install(apkPath);
      return;
    }
    await _startDownload();
  }

  Future<void> _startDownload() async {
    final info = _info;
    if (info == null || !info.hasApk || isBusy) return;

    _cancelToken = CancelToken();
    _status = UpdateStatus.downloading;
    _progress = 0;
    _errorMessage = null;
    notifyListeners();
    try {
      final path = await _service.downloadApk(
        url: info.downloadUrl,
        fileName: info.fileName,
        cancelToken: _cancelToken!,
        onProgress: _onProgress,
      );
      _apkPath = path;
      await _install(path);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        // 用户主动取消：回到待更新状态，弹窗内可再次发起
        _status = UpdateStatus.available;
      } else {
        _status = UpdateStatus.error;
        _errorMessage = '下载失败，请检查网络后重试';
      }
      notifyListeners();
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = _readableMessage(e);
      notifyListeners();
    }
  }

  Future<void> _install(String apkPath) async {
    _status = UpdateStatus.installing;
    _errorMessage = null;
    notifyListeners();
    try {
      await _service.installApk(apkPath);
      // 安装器已调起：若用户在系统安装页放弃，返回后仍停留在 available 可重试
      _status = UpdateStatus.available;
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = _readableMessage(e);
    }
    notifyListeners();
  }

  void cancelDownload() {
    // 状态回退统一在 _startDownload 的取消分支处理，这里只发取消信号
    _cancelToken?.cancel('用户取消下载');
  }

  /// 「忽略此版本」：自动检查不再提示该版本；手动检查仍正常提示。
  Future<void> markIgnored() async {
    final version = _info?.version;
    if (version == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyIgnoredVersion, version);
    } catch (_) {}
  }

  Future<String?> _ignoredVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyIgnoredVersion);
    } catch (_) {
      return null;
    }
  }

  void _onProgress(int received, int total) {
    if (total <= 0) return;
    final p = (received / total).clamp(0.0, 1.0);
    // 进度通知按整百分比去抖，避免高频 notifyListeners 重建弹窗
    if ((p * 100).floor() != (_progress * 100).floor() || p >= 1) {
      _progress = p;
      notifyListeners();
    }
  }

  static String _readableMessage(Object e) {
    return e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}
