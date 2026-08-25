// lib/core/network/connectivity_service.dart
// ═══════════════════════════════════════════════════════════════════
// Smart connectivity service that differentiates between:
//   - Device offline (no WiFi/mobile data)
//   - Server waking up (Render cold start)
//   - Fully online
//
// Uses connectivity_plus for interface checks + HTTP ping for real
// verification (handles captive portals, restricted networks).
// ═══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'environment_config.dart';

/// Three-state connectivity — more useful than a simple bool.
enum ConnectivityState {
  /// Device online, server reachable.
  online,

  /// Device has no network interface (airplane mode, WiFi off).
  offline,

  /// Device online but server is waking up from cold start.
  serverWaking,
}

class ConnectivityService {
  ConnectivityService._();

  // ─── Public State ─────────────────────────────────────────────
  static final ValueNotifier<ConnectivityState> state =
      ValueNotifier(ConnectivityState.online);

  static bool get isOnline => state.value == ConnectivityState.online;
  static bool get isOffline => state.value == ConnectivityState.offline;
  static bool get isServerWaking =>
      state.value == ConnectivityState.serverWaking;

  // ─── Internal ─────────────────────────────────────────────────
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static Timer? _debounceTimer;
  static bool _initialized = false;
  static bool _serverUnavailable = false;

  static bool get isServerUnavailable => _serverUnavailable;
  static void setServerUnavailable(bool val) {
    _serverUnavailable = val;
    debugPrint('[CONNECTIVITY] Server unavailable set to: $val');
  }

  /// Lightweight Dio for health pings (no interceptors, short timeout).
  static final Dio _pingDio = Dio(BaseOptions(
    connectTimeout: EnvironmentConfig.healthTimeout,
    receiveTimeout: const Duration(seconds: 5),
  ));

  // ─── Initialization ───────────────────────────────────────────

  /// Call once at app startup. Starts listening for connectivity changes
  /// and immediately pings the server to warm it up.
  static Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    // Listen to physical network changes
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);

    // Check initial state + warm up the server
    final results = await Connectivity().checkConnectivity();
    final hasInterface =
        !results.contains(ConnectivityResult.none) && results.isNotEmpty;

    if (!hasInterface) {
      state.value = ConnectivityState.offline;
    } else {
      // Device has network — ping server to check real connectivity
      // and pre-warm Render from cold start
      state.value = ConnectivityState.serverWaking;
      _pingHealthEndpoint();
    }

    debugPrint('[CONNECTIVITY] Initialized → ${state.value.name}');
  }

  // ─── Connectivity Change Handler ──────────────────────────────

  static void _onConnectivityChanged(List<ConnectivityResult> results) {
    // Debounce rapid flickers (common when switching WiFi ↔ mobile data)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      final hasInterface =
          !results.contains(ConnectivityResult.none) && results.isNotEmpty;

      if (!hasInterface) {
        state.value = ConnectivityState.offline;
        debugPrint('[CONNECTIVITY] Network interface lost → offline');
      } else if (state.value == ConnectivityState.offline) {
        // Came back online — verify with a real HTTP ping
        debugPrint('[CONNECTIVITY] Network interface restored → verifying...');
        state.value = ConnectivityState.serverWaking;
        _pingHealthEndpoint();
      }
    });
  }

  // ─── Health Ping ──────────────────────────────────────────────

  /// Pings GET /health to verify real connectivity and warm Render.
  /// Retries up to 3 times with exponential backoff.
  static Future<void> _pingHealthEndpoint() async {
    for (int attempt = 0; attempt < EnvironmentConfig.maxRetries; attempt++) {
      try {
        debugPrint('[CONNECTIVITY] Health ping attempt ${attempt + 1}...');
        final response = await _pingDio.get(
          EnvironmentConfig.healthEndpoint,
        );

        if (response.statusCode != null && response.statusCode! < 400) {
          state.value = ConnectivityState.online;
          debugPrint('[CONNECTIVITY] Server reachable ✓ → online');
          return;
        }
      } on DioException catch (e) {
        if (e.error is SocketException) {
          // Truly offline
          state.value = ConnectivityState.offline;
          debugPrint('[CONNECTIVITY] SocketException → offline');
          return;
        }
        // Server waking up — wait and retry
        debugPrint('[CONNECTIVITY] Ping failed (${e.type.name}), '
            'retrying in ${2 * (1 << attempt)}s...');
      } catch (e) {
        debugPrint('[CONNECTIVITY] Unexpected ping error: $e');
      }

      if (attempt < EnvironmentConfig.maxRetries - 1) {
        await Future.delayed(
          EnvironmentConfig.retryBaseDelay * (1 << attempt),
        );
      }
    }

    // All retries failed but we have a network interface.
    // Reset state to online and mark server as unavailable so we don't show the connecting banner forever.
    _serverUnavailable = true;
    state.value = ConnectivityState.online;
    debugPrint('[CONNECTIVITY] All health pings failed. Resetting to online.');
  }

  // ─── State Reporters (called from DioClient interceptors) ─────

  /// Called by DioClient error interceptor when a SocketException occurs.
  static void reportOffline() {
    if (state.value != ConnectivityState.offline) {
      state.value = ConnectivityState.offline;
      debugPrint('[CONNECTIVITY] Reported offline by DioClient');
    }
  }

  /// Called by DioClient when a connection timeout occurs (cold start).
  static void reportServerWaking() {
    if (_serverUnavailable) return; // Don't report waking if we know the server is down
    if (state.value == ConnectivityState.online) {
      state.value = ConnectivityState.serverWaking;
      debugPrint('[CONNECTIVITY] Reported server waking by DioClient');
    }
  }

  /// Called by DioClient retry interceptor on successful retry.
  static void reportOnline() {
    _serverUnavailable = false; // Reset unavailable status when online
    if (state.value != ConnectivityState.online) {
      state.value = ConnectivityState.online;
      debugPrint('[CONNECTIVITY] Reported online by DioClient');
    }
  }

  /// Manual retry — triggered by user tapping "Retry" in the UI.
  static Future<void> retryConnection() async {
    debugPrint('[CONNECTIVITY] Manual retry requested');
    _serverUnavailable = false; // Reset to allow banner to show during retry
    final results = await Connectivity().checkConnectivity();
    final hasInterface =
        !results.contains(ConnectivityResult.none) && results.isNotEmpty;

    if (!hasInterface) {
      state.value = ConnectivityState.offline;
      return;
    }

    state.value = ConnectivityState.serverWaking;
    await _pingHealthEndpoint();
  }

  // ─── Cleanup ──────────────────────────────────────────────────

  static void dispose() {
    _subscription?.cancel();
    _debounceTimer?.cancel();
    _initialized = false;
  }
}
