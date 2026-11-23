import 'package:geolocator/geolocator.dart';

enum DemandTier {
  veryHigh,
  high,
  moderate;

  String get label {
    switch (this) {
      case DemandTier.veryHigh:
        return 'Very High Demand';
      case DemandTier.high:
        return 'High Demand';
      case DemandTier.moderate:
        return 'Moderate Demand';
    }
  }

  String get icon {
    switch (this) {
      case DemandTier.veryHigh:
        return '🔥';
      case DemandTier.high:
        return '📈';
      case DemandTier.moderate:
        return '📍';
    }
  }
}

/// Geographic high-demand hotspot zone for gig workers.
/// Helps technicians position themselves in active booking clusters to maximize earnings.
class HighDemandZone {
  final String id;
  final String name;
  final String city;
  final double latitude;
  final double longitude;
  final int activeRequestsCount;
  final DemandTier demandTier;
  final int surgeBonus;
  final String? surgeReason;
  final String dominantTrade;

  const HighDemandZone({
    required this.id,
    required this.name,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.activeRequestsCount,
    required this.demandTier,
    this.surgeBonus = 0,
    this.surgeReason,
    this.dominantTrade = 'Electrician & Plumber',
  });

  /// Compute distance in kilometers from worker's current coordinates
  double distanceInKm(double currentLat, double currentLng) {
    if (currentLat == 0.0 && currentLng == 0.0) return 0.0;
    final meters = Geolocator.distanceBetween(
      currentLat,
      currentLng,
      latitude,
      longitude,
    );
    return meters / 1000.0;
  }

  /// Formatted distance string (e.g. "1.8 km away")
  String formattedDistance(double currentLat, double currentLng) {
    final km = distanceInKm(currentLat, currentLng);
    if (km <= 0.0) return 'Nearby';
    return '${km.toStringAsFixed(1)} km away';
  }

  /// Estimated two-wheeler scooter transit time in urban traffic
  int estimatedScooterMinutes(double currentLat, double currentLng) {
    final km = distanceInKm(currentLat, currentLng);
    if (km <= 0.0) return 2;
    // Assuming 25 km/h average speed in Mysore / Bangalore traffic
    final minutes = ((km / 25.0) * 60).round();
    return minutes < 3 ? 3 : minutes;
  }

  /// Expressive summary tagline for worker radar card
  String get summaryTagline {
    if (surgeBonus > 0 && surgeReason != null) {
      return '$activeRequestsCount requests in last 15 mins • +₹$surgeBonus $surgeReason';
    }
    return '$activeRequestsCount requests in last 15 mins • High earning potential';
  }

  factory HighDemandZone.fromJson(Map<String, dynamic> json) {
    DemandTier tier = DemandTier.moderate;
    final tierStr = (json['demand_tier'] as String?)?.toLowerCase();
    if (tierStr == 'very_high' || tierStr == 'veryhigh') {
      tier = DemandTier.veryHigh;
    } else if (tierStr == 'high') {
      tier = DemandTier.high;
    }

    return HighDemandZone(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Service Zone',
      city: json['city'] as String? ?? 'Mysuru',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 12.3051,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 76.6551,
      activeRequestsCount: json['active_requests_count'] as int? ?? 1,
      demandTier: tier,
      surgeBonus: json['surge_bonus'] as int? ?? 0,
      surgeReason: json['surge_reason'] as String?,
      dominantTrade: json['dominant_trade'] as String? ?? 'All Services',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'city': city,
    'latitude': latitude,
    'longitude': longitude,
    'active_requests_count': activeRequestsCount,
    'demand_tier': demandTier.name,
    'surge_bonus': surgeBonus,
    'surge_reason': surgeReason,
    'dominant_trade': dominantTrade,
  };
}
