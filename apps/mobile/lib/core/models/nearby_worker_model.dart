// lib/core/models/nearby_worker_model.dart
// ═══════════════════════════════════════════════════════════════════
// Data model for workers returned by the PostGIS spatial search API.
// Maps 1:1 with the WorkerSearchResponse Pydantic model in the
// FastAPI backend.
// ═══════════════════════════════════════════════════════════════════

class NearbyWorkerModel {
  /// Worker's unique ID (Firebase UID)
  final String id;

  /// Display name
  final String name;

  /// Phone number (may be null if privacy-restricted)
  final String? phone;

  /// List of service skills (e.g. ['electrician', 'plumber'])
  final List<String> serviceTypes;

  /// Average rating (0.0 - 5.0)
  final double rating;

  /// Geodesic distance from the user's location in meters.
  /// Calculated by PostGIS ST_Distance on the GEOGRAPHY column.
  /// Returns -1.0 if distance is unknown (fallback query without PostGIS).
  final double distanceMeters;

  /// Whether the worker is currently available
  final bool isAvailable;

  /// Profile photo URL (ID document URL used as profile photo)
  final String? profilePhoto;

  /// Total number of completed jobs
  final int completedJobs;

  /// Whether this worker accepts emergency requests
  final bool emergencyAvailable;

  const NearbyWorkerModel({
    required this.id,
    required this.name,
    this.phone,
    required this.serviceTypes,
    required this.rating,
    required this.distanceMeters,
    required this.isAvailable,
    this.profilePhoto,
    required this.completedJobs,
    required this.emergencyAvailable,
  });

  /// Parse from the JSON map returned by the FastAPI /workers/search endpoint.
  factory NearbyWorkerModel.fromJson(Map<String, dynamic> json) {
    return NearbyWorkerModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Worker',
      phone: json['phone'] as String?,
      serviceTypes: (json['service_types'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      isAvailable: json['is_available'] as bool? ?? true,
      profilePhoto: json['profile_photo'] as String?,
      completedJobs: json['completed_jobs'] as int? ?? 0,
      emergencyAvailable: json['emergency_available'] as bool? ?? false,
    );
  }

  /// Serialize to JSON (useful for caching or passing between screens)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'service_types': serviceTypes,
      'rating': rating,
      'distance_meters': distanceMeters,
      'is_available': isAvailable,
      'profile_photo': profilePhoto,
      'completed_jobs': completedJobs,
      'emergency_available': emergencyAvailable,
    };
  }

  /// Human-readable distance string.
  /// - Under 1km: shows meters (e.g. "850m")
  /// - 1km+: shows km with one decimal (e.g. "2.3 km")
  /// - Unknown (-1): shows "Unknown"
  String get distanceLabel {
    if (distanceMeters < 0) return 'Unknown';
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()}m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  /// Formatted rating string (e.g. "4.8★")
  String get ratingLabel => '${rating.toStringAsFixed(1)}★';

  @override
  String toString() =>
      'NearbyWorkerModel(id: $id, name: $name, distance: $distanceLabel)';
}
