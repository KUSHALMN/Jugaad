// lib/core/network/dio_client.dart
// ═══════════════════════════════════════════════════════════════════
// Production-grade Dio HTTP client with:
//   1. Firebase Auth token injection
//   2. Smart error classification (NOT "no internet" for everything)
//   3. Automatic retry with exponential backoff
//   4. Debug-only request/response logging
//   5. Render cold-start aware timeouts
// ═══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'api_error.dart';
import 'environment_config.dart';
import 'connectivity_service.dart';

class DioClient {
  DioClient._();

  static late final Dio _dio;
  static bool _initialized = false;

  /// Shared Dio instance — use this everywhere.
  static Dio get instance {
    assert(_initialized, 'DioClient.initialize() must be called first');
    return _dio;
  }

  /// Call once at app startup (in main.dart).
  static void initialize() {
    if (_initialized) return;

    _dio = Dio(BaseOptions(
      baseUrl: EnvironmentConfig.baseUrl,
      connectTimeout: EnvironmentConfig.connectTimeout,
      receiveTimeout: EnvironmentConfig.receiveTimeout,
      sendTimeout: EnvironmentConfig.sendTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Order matters: logging → auth → retry → error
    if (EnvironmentConfig.isDebug) {
      _dio.interceptors.add(_LoggingInterceptor());
    }
    _dio.interceptors.add(_AuthInterceptor());
    _dio.interceptors.add(_RetryInterceptor(_dio));
    _dio.interceptors.add(_ErrorInterceptor());

    _initialized = true;
    debugPrint('[DIO] Initialized → ${EnvironmentConfig.baseUrl}');
  }

  /// Base URL getter for external use (e.g. heartbeat service).
  static String get baseUrl => EnvironmentConfig.baseUrl;
}

// ═══════════════════════════════════════════════════════════════════
// 1. AUTH INTERCEPTOR — injects Firebase token on every request
// ═══════════════════════════════════════════════════════════════════

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (e) {
      debugPrint('[DIO/AUTH] Token fetch failed: $e');
      // Don't block the request — let the server return 401
    }
    handler.next(options);
  }
}

// ═══════════════════════════════════════════════════════════════════
// 2. ERROR INTERCEPTOR — classifies errors correctly
//    THIS IS THE CORE BUG FIX: no longer marks everything as offline
// ═══════════════════════════════════════════════════════════════════

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final apiError = ApiError.fromDioException(err);

    debugPrint('[DIO/ERROR] ${apiError.type.name}: ${apiError.message} '
        '(${err.requestOptions.method} ${err.requestOptions.path})');

    // ONLY set truly offline when the device has no internet
    // connectionTimeout = Render cold start, NOT offline
    if (apiError.type == ApiErrorType.noInternet) {
      ConnectivityService.reportOffline();
    } else if (apiError.type == ApiErrorType.serverColdStart) {
      final retryCount = (err.requestOptions.extra['x-retry-count'] as int?) ?? 0;
      if (retryCount >= EnvironmentConfig.maxRetries) {
        ConnectivityService.reportOnline();
      } else {
        ConnectivityService.reportServerWaking();
      }
    }

    // Wrap the DioException to carry our ApiError
    handler.next(err.copyWith(
      error: apiError,
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════
// 3. RETRY INTERCEPTOR — exponential backoff for retryable errors
//    Retries: 2s → 4s → 8s (3 attempts)
// ═══════════════════════════════════════════════════════════════════

class _RetryInterceptor extends Interceptor {
  final Dio _dio;
  static const String _retryCountKey = 'x-retry-count';

  _RetryInterceptor(this._dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final apiError = err.error is ApiError
        ? err.error as ApiError
        : ApiError.fromDioException(err);

    if (!apiError.isRetryable) {
      return handler.next(err);
    }

    final retryCount =
        (err.requestOptions.extra[_retryCountKey] as int?) ?? 0;

    if (retryCount >= EnvironmentConfig.maxRetries) {
      debugPrint('[DIO/RETRY] Max retries ($retryCount) reached for '
          '${err.requestOptions.path}');
      // Clear serverWaking state and mark server as down because we stopped retrying this request
      ConnectivityService.setServerUnavailable(true);
      ConnectivityService.reportOnline();
      return handler.next(err);
    }

    final delay = EnvironmentConfig.retryBaseDelay * (1 << retryCount); // 2s, 4s, 8s
    debugPrint('[DIO/RETRY] Retry ${retryCount + 1}/${EnvironmentConfig.maxRetries} '
        'in ${delay.inSeconds}s for ${err.requestOptions.path}');

    await Future.delayed(delay);

    // Clone the request with incremented retry count
    final options = err.requestOptions;
    options.extra[_retryCountKey] = retryCount + 1;

    try {
      final response = await _dio.fetch(options);
      // Successful retry — clear any server-waking state
      ConnectivityService.reportOnline();
      return handler.resolve(response);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// 4. LOGGING INTERCEPTOR — debug mode only
// ═══════════════════════════════════════════════════════════════════

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('┌── DIO REQUEST ──────────────────────────────');
    debugPrint('│ ${options.method} ${options.uri}');
    if (options.data != null) {
      debugPrint('│ Body: ${_truncate(options.data.toString(), 200)}');
    }
    debugPrint('└─────────────────────────────────────────────');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('┌── DIO RESPONSE ─────────────────────────────');
    debugPrint('│ ${response.statusCode} ${response.requestOptions.method} '
        '${response.requestOptions.path}');
    debugPrint('│ Data: ${_truncate(response.data.toString(), 200)}');
    debugPrint('└─────────────────────────────────────────────');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('┌── DIO ERROR ────────────────────────────────');
    debugPrint('│ ${err.type.name} ${err.requestOptions.method} '
        '${err.requestOptions.path}');
    debugPrint('│ Message: ${err.message}');
    if (err.response != null) {
      debugPrint('│ Status: ${err.response?.statusCode}');
      debugPrint('│ Body: ${_truncate(err.response?.data.toString() ?? '', 200)}');
    }
    debugPrint('└─────────────────────────────────────────────');
    handler.next(err);
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
