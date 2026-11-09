import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';
import 'demo_api.dart';

/// A user-presentable error coming from the API or the network.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;

  /// Extracts the most useful message from a Strapi v3 error payload.
  /// Strapi returns errors in several shapes:
  ///   {message: [{messages: [{id, message}]}]}
  ///   {message: "text"}
  ///   {error: {message: "text"}}
  ///   {success: false, message: "text"}
  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final status = error.response?.statusCode;
      final msg = messageFromBody(error.response?.data);
      if (msg != null) return ApiException(msg, statusCode: status);
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ApiException('The server is taking too long. Please try again.', statusCode: status);
        case DioExceptionType.connectionError:
          return ApiException('No internet connection. Check your network.', statusCode: status);
        default:
          break;
      }
      if (status == 401) {
        return ApiException('Your session has expired. Please log in again.', statusCode: status);
      }
      if (status == 403) {
        return ApiException('You are not allowed to do that.', statusCode: status);
      }
      if (status != null && status >= 500) {
        return ApiException('Server error ($status). Please try later.', statusCode: status);
      }
      return ApiException('Something went wrong. Please try again.', statusCode: status);
    }
    return ApiException(error.toString());
  }

  static String? messageFromBody(dynamic data) {
    if (data == null) return null;
    if (data is String) {
      final t = data.trim();
      if (t.isEmpty || t.startsWith('<')) return null;
      return t.length > 200 ? '${t.substring(0, 200)}…' : t;
    }
    if (data is Map) {
      final m = data['message'];
      if (m is String && m.trim().isNotEmpty) return m;
      if (m is List && m.isNotEmpty) {
        final first = m.first;
        if (first is Map) {
          final inner = first['messages'];
          if (inner is List && inner.isNotEmpty && inner.first is Map) {
            final text = inner.first['message'];
            if (text is String) return text;
            // Some Strapi errors only carry an id, which is often a sentence
            // ("No authorization header was found").
            final id = inner.first['id'];
            if (id is String && id.contains(' ')) return id;
          }
          final text = first['message'];
          if (text is String) return text;
        }
        if (first is String) return first;
      }
      final err = data['error'];
      if (err is Map && err['message'] is String) return err['message'] as String;
      if (err is String && err.trim().isNotEmpty) return err;
    }
    return null;
  }
}

/// Persists the JWT the same way the web app keeps `tnp-student-jwt`.
class TokenStore {
  static const _key = 'tnp-student-jwt';
  final _storage = const FlutterSecureStorage();

  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String token) => _storage.write(key: _key, value: token);

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}

/// Thin Dio wrapper: base URL, bearer token, cookie session (needed by the
/// IMS captcha / CGPA flows which rely on a server-side session cookie).
class ApiClient {
  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(minutes: 2),
        headers: {'Accept': 'application/json'},
      ),
    );
    dio.interceptors.add(CookieManager(cookieJar));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final t = token;
          final skipAuth = options.extra['noAuth'] == true;
          if (t != null && t.isNotEmpty && !skipAuth) {
            options.headers['Authorization'] = 'Bearer $t';
          }
          handler.next(options);
        },
        onError: (e, handler) {
          final hadToken = e.requestOptions.headers['Authorization'] != null;
          if (e.response?.statusCode == 401 && hadToken) {
            onUnauthorized?.call();
          }
          handler.next(e);
        },
      ),
    );
    if (DemoApiInterceptor.enabled) dio.interceptors.add(DemoApiInterceptor());
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: false, responseBody: false, logPrint: (o) => debugPrint(o.toString())),
      );
    }
  }

  late final Dio dio;
  final CookieJar cookieJar = CookieJar();
  String? token;
  VoidCallback? onUnauthorized;

  static Options get noAuth => Options(extra: {'noAuth': true});
}
