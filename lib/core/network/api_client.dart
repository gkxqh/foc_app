import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../constants/api_constants.dart';

class ApiResponse<T> {
  final bool success;
  final int statusCode;
  final String? message;
  final T? data;
  final dynamic raw;

  ApiResponse({
    required this.success,
    required this.statusCode,
    this.message,
    this.data,
    this.raw,
  });
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio _dio;
  String? _accessToken;
  Function()? onUnauthorized;

  String? get accessToken => _accessToken;

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.rootApiUrl,
        connectTimeout: const Duration(seconds: 15),
        // 图片上传的发送阶段不受 receiveTimeout 约束，必须单独设 sendTimeout，
        // 否则链路停滞时请求无限挂起、页面 loading 永久卡死
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_accessToken != null && _accessToken!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          if (e.response?.statusCode == 401) {
            clearToken();
            onUnauthorized?.call();
          }
          return handler.next(e);
        },
      ),
    );
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
  }

  Future<void> setToken(String token) async {
    _accessToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  Future<void> clearToken() async {
    _accessToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return _handleResponse<T>(response);
    } on DioException catch (e) {
      return _handleDioError<T>(e);
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        statusCode: 500,
        message: e.toString(),
      );
    }
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _handleResponse<T>(response);
    } on DioException catch (e) {
      return _handleDioError<T>(e);
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        statusCode: 500,
        message: e.toString(),
      );
    }
  }

  // 图片上传统一收 XFile 并按字节读取：MultipartFile.fromFile 依赖 dart:io，
  // web 端会抛 "MultipartFile is only supported where dart:io is available"
  Future<ApiResponse<String>> uploadImage(XFile file) async {
    try {
      final String uuid = const Uuid().v4();
      final bytes = await file.readAsBytes();
      // web 端文件名可能是 blob URL 派生的空名，兜底扩展名保证服务端/七牛可识别类型
      final filename = _uploadFileName(file.name, uuid);
      final formData = FormData.fromMap({
        'key': 'fyMiniprogam/$uuid',
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType:
              MultipartFile.lookupMediaType(filename) ??
              DioMediaType('image', 'jpeg'),
        ),
      });

      final response = await _dio.post(
        ApiConstants.userAvatar,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      dynamic resData = response.data;
      if (resData is String) {
        resData = jsonDecode(resData);
      }

      if (resData is Map &&
          (resData['success'] == true || resData['success'] == 1)) {
        final url =
            resData['rawdata']?.toString() ?? resData['data']?.toString() ?? '';
        return ApiResponse<String>(success: true, statusCode: 200, data: url);
      }
      String? message;
      if (resData is Map) {
        message = resData['message']?.toString();
      }
      return ApiResponse<String>(
        success: false,
        statusCode: response.statusCode ?? 500,
        message: message ?? '图片上传失败',
      );
    } on DioException catch (e) {
      return _handleDioError<String>(e);
    } catch (e) {
      return ApiResponse<String>(
        success: false,
        statusCode: 500,
        message: e.toString(),
      );
    }
  }

  /// 从 XFile 文件名生成上传文件名；无扩展名（web blob 场景）时兜底 .jpg
  static String _uploadFileName(String name, String uuid) {
    final trimmed = name.trim();
    final dot = trimmed.lastIndexOf('.');
    if (trimmed.isNotEmpty && dot > 0 && dot < trimmed.length - 1) {
      return trimmed;
    }
    return '$uuid.jpg';
  }

  ApiResponse<T> _handleResponse<T>(Response response) {
    dynamic data = response.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {}
    }

    final bool success =
        data is Map && (data['success'] == true || data['success'] == 1);
    final String? message = data is Map ? data['message']?.toString() : null;

    return ApiResponse<T>(
      success: success,
      statusCode: response.statusCode ?? 200,
      message: message,
      data: (data is Map && data.containsKey('data'))
          ? data['data'] as T?
          : data as T?,
      raw: data,
    );
  }

  ApiResponse<T> _handleDioError<T>(DioException e) {
    String? message;
    final resData = e.response?.data;
    if (resData is Map) {
      message = resData['message']?.toString();
    } else if (resData is String && resData.isNotEmpty) {
      message = resData;
    }
    message ??= e.message ?? '网络连接异常';

    return ApiResponse<T>(
      success: false,
      statusCode: e.response?.statusCode ?? 500,
      message: message,
      raw: resData,
    );
  }
}
