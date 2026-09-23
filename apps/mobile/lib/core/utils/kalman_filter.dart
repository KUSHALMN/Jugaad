import 'dart:math';

/// A 2-dimensional Kalman Filter designed specifically for mobile GPS telemetry.
/// Dampens high-frequency GPS noise, multipath bouncing, and eliminates teleportation
/// artifacts when tracking en route trade workers.
class KalmanLatLong {
  final double _qMetersPerSecond; // Process noise
  double _lat = 0.0;
  double _lng = 0.0;
  double _variance = -1.0; // P matrix (initially invalid)
  int _timeStampMilliseconds = 0;

  KalmanLatLong({double qMetersPerSecond = 3.0})
      : _qMetersPerSecond = qMetersPerSecond;

  double get lat => _lat;
  double get lng => _lng;
  double get accuracy => sqrt(_variance);
  bool get isInitialized => _variance >= 0;

  /// Resets the filter with a known anchor position.
  void setState(double lat, double lng, double accuracyMeters, int timeStampMilliseconds) {
    _lat = lat;
    _lng = lng;
    _variance = accuracyMeters * accuracyMeters;
    _timeStampMilliseconds = timeStampMilliseconds;
  }

  /// Ingests a new raw GPS point and produces an optimal, smoothed estimate.
  /// Rejects extreme GPS spikes and dampens jitter.
  void process(double rawLat, double rawLng, double rawAccuracyMeters, int timeStampMilliseconds) {
    if (rawAccuracyMeters < 1.0) rawAccuracyMeters = 1.0;

    if (_variance < 0) {
      // First measurement
      setState(rawLat, rawLng, rawAccuracyMeters, timeStampMilliseconds);
      return;
    }

    final int durationMs = timeStampMilliseconds - _timeStampMilliseconds;
    if (durationMs > 0) {
      // Time has passed: increase variance by the expected process noise
      _variance += (durationMs / 1000.0) * _qMetersPerSecond * _qMetersPerSecond;
      _timeStampMilliseconds = timeStampMilliseconds;
    }

    // Outlier rejection: calculate approximate displacement
    final double distMeters = _approxDistanceInMeters(_lat, _lng, rawLat, rawLng);
    if (durationMs > 0) {
      final double speedKmph = (distMeters / (durationMs / 1000.0)) * 3.6;
      // If speed exceeds 130 km/h in city traffic, penalize accuracy heavily
      if (speedKmph > 130.0 && distMeters > 150.0) {
        rawAccuracyMeters *= 5.0;
      }
    }

    // Kalman gain K = P / (P + R)
    final double measurementVariance = rawAccuracyMeters * rawAccuracyMeters;
    final double k = _variance / (_variance + measurementVariance);

    // State update: x = x + K * (z - x)
    _lat += k * (rawLat - _lat);
    _lng += k * (rawLng - _lng);

    // Covariance update: P = (1 - K) * P
    _variance = (1.0 - k) * _variance;
  }

  /// Fast equirectangular distance approximation in meters.
  double _approxDistanceInMeters(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000; // Earth radius in meters
    final double dLat = (lat2 - lat1) * (pi / 180.0);
    final double dLon = (lon2 - lon1) * (pi / 180.0);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) * cos(lat2 * (pi / 180.0)) *
        sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }
}
