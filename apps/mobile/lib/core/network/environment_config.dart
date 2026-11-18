// lib/core/network/environment_config.dart
// ═══════════════════════════════════════════════════════════════════
// Single source of truth for API base URL, timeouts, and endpoints.
// Replaces both AppConfig and ApiConstants.
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

class EnvironmentConfig {
  EnvironmentConfig._();

  // ─── Environment ──────────────────────────────────────────────
  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => !isProduction;
  static bool get isDebug => kDebugMode && isDevelopment;

  // ─── Base URL ─────────────────────────────────────────────────
  // Pass at build time:
  //   flutter run --dart-define=API_BASE_URL=https://your-app.onrender.com
  //   flutter build apk --dart-define=API_BASE_URL=https://your-app.onrender.com --dart-define=ENV=production
  static const String _defaultProdUrl = 'https://jugaad-api.onrender.com';
  static const String _defaultDevWebUrl = 'http://localhost:8000';

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb && kDebugMode) return _defaultDevWebUrl;
    return _defaultProdUrl;
  }

  static String get apiV1 => '$baseUrl/api/v1';

  // ─── Timeouts (tuned for Render free-tier cold start) ─────────
  /// Render cold start can take 50s. 60s gives margin.
  static const Duration connectTimeout = Duration(seconds: 60);

  /// Once connected, response should come within 30s.
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Sending data (file uploads, etc.)
  static const Duration sendTimeout = Duration(seconds: 30);

  // ─── Retry Configuration ──────────────────────────────────────
  static const int maxRetries = 3;
  static const Duration retryBaseDelay = Duration(seconds: 2); // 2s, 4s, 8s

  // ─── Health Check ─────────────────────────────────────────────
  static String get healthEndpoint => '$baseUrl/health';

  /// How long to wait for health ping before declaring server cold
  static const Duration healthTimeout = Duration(seconds: 10);

  // ─── Endpoints ────────────────────────────────────────────────
  static String get jobs => '$apiV1/jobs';
  static String get users => '$apiV1/users';
  static String get workers => '$apiV1/workers';
  static String get payments => '$apiV1/payments';
  static String get dispatch => '$apiV1/dispatch';
  static String get platformConfig => '$apiV1/platform/config';
}
