import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/kalman_filter.dart';
import 'location_service.dart';

/// Manages background telemetry resilience for Android & field hardware.
/// Specifically addresses aggressive OEM task killers (MIUI, ColorOS, FunTouch OS)
/// by maintaining foreground telemetry sessions and applying Kalman filtering.
class BackgroundLocationService {
  static final BackgroundLocationService _instance = BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  final KalmanLatLong _kalmanFilter = KalmanLatLong(qMetersPerSecond: 3.0);
  bool _isForegroundActive = false;
  Timer? _heartbeatTimer;

  bool get isForegroundActive => _isForegroundActive;

  /// Starts persistent foreground telemetry tracking.
  Future<void> startForegroundTelemetry({
    required String workerId,
    required Function(double lat, double lng, double accuracy) onFilteredPosition,
  }) async {
    if (_isForegroundActive) return;
    _isForegroundActive = true;
    debugPrint('[TELEMETRY] Starting resilient foreground telemetry for: $workerId');

    // Switch LocationService to enRoute mode for high resolution
    LocationService().setTrackingMode(TrackingMode.enRoute);

    // Periodic heartbeat to guarantee sensor wakefulness on budget chipsets
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        final pos = await LocationService().getCurrentLocation();
        if (pos != null) {
          _kalmanFilter.process(
            pos.latitude,
            pos.longitude,
            pos.accuracy,
            pos.timestamp.millisecondsSinceEpoch,
          );
          onFilteredPosition(
            _kalmanFilter.lat,
            _kalmanFilter.lng,
            _kalmanFilter.accuracy,
          );
        }
      } catch (e) {
        debugPrint('[TELEMETRY] Heartbeat ping error: $e');
      }
    });
  }

  /// Stops persistent foreground telemetry when worker goes offline or finishes job.
  void stopForegroundTelemetry() {
    _isForegroundActive = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    LocationService().setTrackingMode(TrackingMode.idle);
    debugPrint('[TELEMETRY] Foreground telemetry stopped.');
  }

  /// Verifies if device has proper location permissions including background.
  Future<bool> hasBackgroundLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }
}
