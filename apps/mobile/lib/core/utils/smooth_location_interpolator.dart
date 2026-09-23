import 'dart:math';

/// A 2D coordinate representation with bearing heading.
class SmoothPosition {
  final double lat;
  final double lng;
  final double bearingDegrees; // 0..360 degrees

  const SmoothPosition({
    required this.lat,
    required this.lng,
    this.bearingDegrees = 0.0,
  });

  double get bearingRadians => bearingDegrees * (pi / 180.0);
}

/// Utility for spherical bearing calculations and shortest-arc angular interpolation
/// to provide Uber/Grab-style smooth vehicle orientation.
class SmoothLocationInterpolator {
  /// Computes the spherical forward azimuth (bearing) from Point A to Point B.
  static double computeBearing(double lat1, double lon1, double lat2, double lon2) {
    final double phi1 = lat1 * (pi / 180.0);
    final double phi2 = lat2 * (pi / 180.0);
    final double deltaLambda = (lon2 - lon1) * (pi / 180.0);

    final double y = sin(deltaLambda) * cos(phi2);
    final double x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda);
    final double theta = atan2(y, x);

    // Convert to degrees and normalize to 0..360
    final double degrees = theta * (180.0 / pi);
    return (degrees + 360.0) % 360.0;
  }

  /// Interpolates angles taking the shortest arc path across the 0° / 360° boundary.
  static double interpolateAngle(double currentDeg, double targetDeg, double t) {
    double diff = (targetDeg - currentDeg) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    return (currentDeg + diff * t) % 360.0;
  }

  /// Linear interpolation of coordinates.
  static SmoothPosition interpolate({
    required SmoothPosition from,
    required SmoothPosition to,
    required double fraction,
  }) {
    final double t = fraction.clamp(0.0, 1.0);
    final double lat = from.lat + (to.lat - from.lat) * t;
    final double lng = from.lng + (to.lng - from.lng) * t;
    final double bearing = interpolateAngle(from.bearingDegrees, to.bearingDegrees, t);

    return SmoothPosition(lat: lat, lng: lng, bearingDegrees: bearing);
  }
}
