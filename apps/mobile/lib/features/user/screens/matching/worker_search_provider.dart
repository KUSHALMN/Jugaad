import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/supabase_service.dart';

class WorkerSearchState {
  final List<dynamic> workers;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final double lat;
  final double lng;
  final double radiusKm;
  final String serviceType;
  final int page;
  final bool hasMore;
  final int total;
  final bool hasLocationPermission;
  final bool isResolvingLocation;
  final String activeLocationName;
  final bool isCitywideFallback;

  WorkerSearchState({
    this.workers = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.lat = 0.0,
    this.lng = 0.0,
    this.radiusKm = 5.0,
    this.serviceType = '',
    this.page = 0,
    this.hasMore = false,
    this.total = 0,
    this.hasLocationPermission = false,
    this.isResolvingLocation = false,
    this.activeLocationName = 'Not Set',
    this.isCitywideFallback = false,
  });

  WorkerSearchState copyWith({
    List<dynamic>? workers,
    bool? isLoading,
    bool? isLoadingMore,
    Object? errorMessage = const Object(),
    double? lat,
    double? lng,
    double? radiusKm,
    String? serviceType,
    int? page,
    bool? hasMore,
    int? total,
    bool? hasLocationPermission,
    bool? isResolvingLocation,
    String? activeLocationName,
    bool? isCitywideFallback,
  }) {
    return WorkerSearchState(
      workers: workers ?? this.workers,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage == const Object() ? this.errorMessage : errorMessage as String?,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusKm: radiusKm ?? this.radiusKm,
      serviceType: serviceType ?? this.serviceType,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      hasLocationPermission: hasLocationPermission ?? this.hasLocationPermission,
      isResolvingLocation: isResolvingLocation ?? this.isResolvingLocation,
      activeLocationName: activeLocationName ?? this.activeLocationName,
      isCitywideFallback: isCitywideFallback ?? this.isCitywideFallback,
    );
  }
}

class WorkerSearchNotifier extends Notifier<WorkerSearchState> {
  @override
  WorkerSearchState build() {
    return WorkerSearchState();
  }

  /// Check GPS permissions and resolve the user's coordinates.
  Future<void> checkAndResolveLocation() async {
    state = state.copyWith(isResolvingLocation: true, errorMessage: null);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[LOCATION_PROVIDER] Location services disabled. Falling back to Bangalore Center.');
        state = state.copyWith(
          hasLocationPermission: false,
          lat: 12.9716,
          lng: 77.5946,
          activeLocationName: 'Bangalore Center (Fallback)',
          isResolvingLocation: false,
        );
        search(refresh: true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('[LOCATION_PROVIDER] Location permission denied. Falling back to Bangalore Center.');
          state = state.copyWith(
            hasLocationPermission: false,
            lat: 12.9716,
            lng: 77.5946,
            activeLocationName: 'Bangalore Center (Fallback)',
            isResolvingLocation: false,
          );
          search(refresh: true);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('[LOCATION_PROVIDER] Location permission permanently denied. Falling back to Bangalore Center.');
        state = state.copyWith(
          hasLocationPermission: false,
          lat: 12.9716,
          lng: 77.5946,
          activeLocationName: 'Bangalore Center (Fallback)',
          isResolvingLocation: false,
        );
        search(refresh: true);
        return;
      }

      // Permission granted, query current location
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 7),
        ),
      );

      state = state.copyWith(
        hasLocationPermission: true,
        lat: position.latitude,
        lng: position.longitude,
        activeLocationName: 'GPS Location',
        isResolvingLocation: false,
      );

      // Trigger search with current coordinates
      search(refresh: true);

    } catch (e) {
      print('[LOCATION_PROVIDER] Error resolving location: $e. Falling back to Bangalore Center.');
      state = state.copyWith(
        hasLocationPermission: false,
        lat: 12.9716,
        lng: 77.5946,
        activeLocationName: 'Bangalore Center (Fallback)',
        isResolvingLocation: false,
      );
      search(refresh: true);
    }
  }

  /// Pick a preset Mysuru neighborhood location
  void selectManualLocation(double lat, double lng, String name) {
    state = state.copyWith(
      lat: lat,
      lng: lng,
      activeLocationName: name,
      hasLocationPermission: false,
      errorMessage: null,
    );
    search(refresh: true);
  }

  /// Run search API call
  Future<void> search({bool refresh = false}) async {
    if (state.lat == 0.0 && state.lng == 0.0) {
      state = state.copyWith(errorMessage: 'Please resolve location first.');
      return;
    }

    final int targetPage = refresh ? 0 : state.page;
    
    if (refresh) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    } else {
      state = state.copyWith(isLoadingMore: true);
    }

    try {
      final res = await ApiService().searchWorkers(
        lat: state.lat,
        lng: state.lng,
        radiusKm: state.radiusKm,
        serviceType: state.serviceType.toLowerCase().replaceAll(' ', '_'),
        page: targetPage,
        limit: 8,
      );

      List<dynamic> fetchedWorkers = res['workers'] ?? [];
      final int total = res['total'] ?? 0;
      final bool hasMore = res['has_more'] ?? false;
      bool isFallback = res['mode'] == 'citywide_rating_fallback';

      // Fallback: If 0 workers found nearby, load Mysore Citywide Workers sorted by highest rating
      if (fetchedWorkers.isEmpty) {
        final dbWorkers = await SupabaseService().fetchTopRatedWorkersByCategory(
          category: state.serviceType,
          limit: 12,
        );
        if (dbWorkers.isNotEmpty) {
          fetchedWorkers = dbWorkers;
        } else {
          fetchedWorkers = _getMysoreWorkersForService(state.serviceType);
        }
        isFallback = true;
      }

      final updatedWorkers = refresh 
          ? fetchedWorkers 
          : [...state.workers, ...fetchedWorkers];

      state = state.copyWith(
        workers: updatedWorkers,
        isLoading: false,
        isLoadingMore: false,
        page: targetPage + 1,
        hasMore: hasMore,
        total: total > 0 ? total : updatedWorkers.length,
        isCitywideFallback: isFallback,
      );
    } catch (e) {
      // Fallback on network/API exception: show Mysore citywide workers
      List<dynamic> mysoreWorkers = [];
      try {
        mysoreWorkers = await SupabaseService().fetchTopRatedWorkersByCategory(
          category: state.serviceType,
          limit: 12,
        );
      } catch (_) {}

      if (mysoreWorkers.isEmpty) {
        mysoreWorkers = _getMysoreWorkersForService(state.serviceType);
      }

      state = state.copyWith(
        workers: mysoreWorkers,
        isLoading: false,
        isLoadingMore: false,
        total: mysoreWorkers.length,
        isCitywideFallback: true,
        errorMessage: null,
      );
    }
  }

  /// Mysore Fallback Workers database sorted by rating DESC
  List<dynamic> _getMysoreWorkersForService(String serviceType) {
    final normalized = serviceType.toLowerCase().replaceAll(' ', '_');

    final List<Map<String, dynamic>> allMysoreWorkers = [
      {
        "id": "9c141401-2acd-5eba-a988-9f70f405e86b",
        "name": "SAN TECHNOLOGIES Water Purifier Services",
        "category": "ro_service",
        "skills": ["RO Repair", "Water Purifier", "Plumber"],
        "rating": 5.0,
        "total_jobs": 440,
        "hourly_rate": 200.0,
        "is_verified": true,
        "area": "Kumbarakoppal, Mysuru",
        "phone": "+91 99459 15910"
      },
      {
        "id": "8d6fa9db-c83c-5e00-b42a-d139f721355e",
        "name": "Manu Electrician Mysore",
        "category": "electrician",
        "skills": ["Electrician", "Power Outage", "Wiring"],
        "rating": 4.9,
        "total_jobs": 365,
        "hourly_rate": 200.0,
        "is_verified": true,
        "area": "Ramachandra Agrahara, Mysuru",
        "phone": "+91 97396 87998"
      },
      {
        "id": "405cc123-aec0-507e-9196-1fdd4fb230a6",
        "name": "PRK Services",
        "category": "refrigerator_service",
        "skills": ["Refrigerator Repair", "Appliance Repair", "Electrician"],
        "rating": 4.9,
        "total_jobs": 346,
        "hourly_rate": 200.0,
        "is_verified": true,
        "area": "Hebbal 1st Stage, Mysuru",
        "phone": "+91 90193 91170"
      },
      {
        "id": "5420c074-d276-543b-b7af-79b40aa0226b",
        "name": "Cool Tech",
        "category": "ac_service",
        "skills": ["AC Repair", "AC Service", "Electrician"],
        "rating": 4.9,
        "total_jobs": 535,
        "hourly_rate": 200.0,
        "is_verified": true,
        "area": "Gayathripuram, Mysuru",
        "phone": "+91 99022 61785"
      },
      {
        "id": "8f4cdb1d-7277-5f69-857b-6f4d6d59a752",
        "name": "RJN Plumbing Services",
        "category": "plumber",
        "skills": ["Plumber", "Water Leakage", "Drainage"],
        "rating": 4.9,
        "total_jobs": 165,
        "hourly_rate": 200.0,
        "is_verified": true,
        "area": "Hebbal, Mysuru",
        "phone": "+91 89700 25339"
      },
      {
        "id": "04b91e23-4ade-50bc-9d31-3b1302c36f78",
        "name": "L T Electric Zone",
        "category": "electrician",
        "skills": ["Electrician", "Short Circuit", "Appliance Repair"],
        "rating": 4.9,
        "total_jobs": 133,
        "hourly_rate": 200.0,
        "is_verified": true,
        "area": "Hootagalli, Mysuru",
        "phone": "+91 97414 81923"
      },
      {
        "id": "85525bc9-6c27-549d-8f68-ea4089c30f62",
        "name": "KK Plumbing",
        "category": "plumber",
        "skills": ["Plumber", "Pipe Leak", "Sanitary"],
        "rating": 4.9,
        "total_jobs": 32,
        "hourly_rate": 200.0,
        "is_verified": true,
        "area": "Shivarampet, Mysuru",
        "phone": "+91 87480 02207"
      },
      {
        "id": "dc0da591-c2c5-5fdb-94b2-03fc6f48b9a3",
        "name": "Sriranga Home Cleaning",
        "category": "cleaning",
        "skills": ["House Cleaning", "Deep Cleaning", "Sanitization"],
        "rating": 4.8,
        "total_jobs": 70,
        "hourly_rate": 200.0,
        "is_verified": true,
        "area": "Vinayakanagar, Mysuru",
        "phone": "+91 90363 62141"
      },
      {
        "id": "391c19b8-26aa-549e-9962-7e5fa6c0efe1",
        "name": "Lapserve Laptop Service Center",
        "category": "laptop_repair",
        "skills": ["Laptop Repair", "Phone Repair", "Hardware Repair"],
        "rating": 4.8,
        "total_jobs": 1908,
        "hourly_rate": 250.0,
        "is_verified": true,
        "area": "Saraswathipuram, Mysuru",
        "phone": "+91 99026 64488"
      }
    ];

    List<Map<String, dynamic>> filtered = allMysoreWorkers;
    if (normalized.isNotEmpty && normalized != 'all') {
      filtered = allMysoreWorkers.where((w) {
        final cat = (w['category'] as String? ?? '').toLowerCase();
        final skills = List<String>.from(w['skills'] as List? ?? []).map((s) => s.toLowerCase().replaceAll(' ', '_')).toList();
        return cat.contains(normalized) || skills.any((s) => s.contains(normalized));
      }).toList();
      if (filtered.isEmpty) {
        filtered = allMysoreWorkers;
      }
    }

    // Sort by highest rating DESC and most completed jobs DESC
    filtered.sort((a, b) {
      final double rA = (a['rating'] as num?)?.toDouble() ?? 0.0;
      final double rB = (b['rating'] as num?)?.toDouble() ?? 0.0;
      if (rB != rA) return rB.compareTo(rA);

      final int jA = (a['total_jobs'] as num?)?.toInt() ?? 0;
      final int jB = (b['total_jobs'] as num?)?.toInt() ?? 0;
      return jB.compareTo(jA);
    });

    return filtered;
  }

  /// Set the selected service type filtering chip
  void updateServiceType(String type) {
    state = state.copyWith(serviceType: type, page: 0);
    search(refresh: true);
  }

  /// Update search radius manually
  void updateRadius(double radius) {
    state = state.copyWith(radiusKm: radius, page: 0);
    search(refresh: true);
  }
}

final workerSearchProvider = NotifierProvider<WorkerSearchNotifier, WorkerSearchState>(
  WorkerSearchNotifier.new,
);
