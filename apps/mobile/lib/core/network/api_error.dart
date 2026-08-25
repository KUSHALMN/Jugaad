// lib/core/network/api_error.dart
// ═══════════════════════════════════════════════════════════════════
// Structured API error model — differentiates between no internet,
// server cold start, slow connection, and actual API errors.
// ═══════════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:dio/dio.dart';

/// Classifies the *real* reason a request failed.
enum ApiErrorType {
  /// Device has no network connectivity (airplane mode, WiFi off, etc.)
  noInternet,

  /// Render server is waking up from cold start (~50s on free tier).
  /// The user HAS internet — the server is just slow to boot.
  serverColdStart,

  /// Server responded but data is arriving slowly.
  slowConnection,

  /// Backend returned 5xx (crash, overload, deployment in progress).
  serverError,

  /// Backend returned 4xx (bad request, unauthorized, not found).
  clientError,

  /// Request was cancelled (user navigated away, timeout killed it).
  cancelled,

  /// Catch-all for unexpected errors.
  unknown,
}

class ApiError implements Exception {
  final ApiErrorType type;
  final String message;
  final bool isRetryable;
  final int? statusCode;
  final dynamic rawError;
  final String? endpoint;

  const ApiError({
    required this.type,
    required this.message,
    this.isRetryable = false,
    this.statusCode,
    this.rawError,
    this.endpoint,
  });

  /// Factory: creates the correct [ApiError] from a raw [DioException].
  factory ApiError.fromDioException(DioException e) {
    final endpoint = e.requestOptions.path;

    switch (e.type) {
      // ── Connection timeout → Render cold start (NOT "no internet") ──
      case DioExceptionType.connectionTimeout:
        return ApiError(
          type: ApiErrorType.serverColdStart,
          message: 'Server is starting up, please wait...',
          isRetryable: true,
          rawError: e,
          endpoint: endpoint,
        );

      // ── Send timeout → network is extremely slow ──
      case DioExceptionType.sendTimeout:
        return ApiError(
          type: ApiErrorType.slowConnection,
          message: 'Slow connection, retrying...',
          isRetryable: true,
          rawError: e,
          endpoint: endpoint,
        );

      // ── Receive timeout → server is responding slowly ──
      case DioExceptionType.receiveTimeout:
        return ApiError(
          type: ApiErrorType.slowConnection,
          message: 'Slow connection, retrying...',
          isRetryable: true,
          rawError: e,
          endpoint: endpoint,
        );

      // ── Connection error → check if it's truly offline ──
      case DioExceptionType.connectionError:
        if (e.error is SocketException) {
          return ApiError(
            type: ApiErrorType.noInternet,
            message: 'No internet connection',
            isRetryable: true,
            rawError: e,
            endpoint: endpoint,
          );
        }
        // DNS failure, TLS handshake failure, etc. — server might be down
        return ApiError(
          type: ApiErrorType.serverColdStart,
          message: 'Unable to reach server, retrying...',
          isRetryable: true,
          rawError: e,
          endpoint: endpoint,
        );

      // ── Request cancelled ──
      case DioExceptionType.cancel:
        return ApiError(
          type: ApiErrorType.cancelled,
          message: 'Request was cancelled',
          isRetryable: false,
          rawError: e,
          endpoint: endpoint,
        );

      // ── Bad response (4xx / 5xx) ──
      case DioExceptionType.badResponse:
        return _fromStatusCode(
          e.response?.statusCode,
          e.response?.data,
          e,
          endpoint,
        );

      // ── Unknown / bad certificate / other ──
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        // Check for SocketException buried inside unknown errors
        if (e.error is SocketException) {
          return ApiError(
            type: ApiErrorType.noInternet,
            message: 'No internet connection',
            isRetryable: true,
            rawError: e,
            endpoint: endpoint,
          );
        }
        return ApiError(
          type: ApiErrorType.unknown,
          message: 'Something went wrong. Please try again.',
          isRetryable: true,
          rawError: e,
          endpoint: endpoint,
        );
    }
  }

  /// Extract a meaningful error message from a 4xx/5xx response.
  static ApiError _fromStatusCode(
    int? statusCode,
    dynamic responseData,
    DioException e,
    String endpoint,
  ) {
    // Try to get the server's error message
    String serverMessage = '';
    if (responseData is Map) {
      serverMessage = (responseData['detail'] ??
              responseData['message'] ??
              responseData['error'] ??
              '')
          .toString();
    } else if (responseData is String && responseData.isNotEmpty) {
      serverMessage = responseData;
    }

    final code = statusCode ?? 0;

    if (code >= 500) {
      return ApiError(
        type: ApiErrorType.serverError,
        message: serverMessage.isNotEmpty
            ? serverMessage
            : 'Server error, retrying...',
        isRetryable: true,
        statusCode: code,
        rawError: e,
        endpoint: endpoint,
      );
    }

    // 4xx client errors
    String userMessage;
    switch (code) {
      case 401:
        userMessage =
            serverMessage.isNotEmpty ? serverMessage : 'Session expired. Please log in again.';
        break;
      case 403:
        userMessage =
            serverMessage.isNotEmpty ? serverMessage : 'You don\'t have permission to do this.';
        break;
      case 404:
        userMessage = serverMessage.isNotEmpty ? serverMessage : 'Not found.';
        break;
      case 409:
        userMessage =
            serverMessage.isNotEmpty ? serverMessage : 'This action conflicts with current state.';
        break;
      case 422:
        userMessage =
            serverMessage.isNotEmpty ? serverMessage : 'Invalid request data.';
        break;
      case 429:
        userMessage = 'Too many requests. Please wait a moment.';
        break;
      default:
        userMessage =
            serverMessage.isNotEmpty ? serverMessage : 'Request failed.';
    }

    return ApiError(
      type: ApiErrorType.clientError,
      message: userMessage,
      isRetryable: code == 429, // only rate limit is retryable among 4xx
      statusCode: code,
      rawError: e,
      endpoint: endpoint,
    );
  }

  @override
  String toString() =>
      'ApiError(type: $type, status: $statusCode, message: $message, endpoint: $endpoint)';
}
