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
  final String? advisoryMessage;
  final String userCity;
  final String userDivision;
  final bool isUpcomingCity;

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
    this.advisoryMessage,
    this.userCity = 'Mysuru',
    this.userDivision = 'Your Region',
    this.isUpcomingCity = false,
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
    String? advisoryMessage,
    String? userCity,
    String? userDivision,
    bool? isUpcomingCity,
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
      advisoryMessage: advisoryMessage ?? this.advisoryMessage,
      userCity: userCity ?? this.userCity,
      userDivision: userDivision ?? this.userDivision,
      isUpcomingCity: isUpcomingCity ?? this.isUpcomingCity,
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
        print('[LOCATION_PROVIDER] Location services disabled. Falling back to Mysuru Center.');
        state = state.copyWith(
          hasLocationPermission: false,
          lat: 12.3051,
          lng: 76.6551,
          activeLocationName: 'Mysuru Center (Fallback)',
          isResolvingLocation: false,
        );
        search(refresh: true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('[LOCATION_PROVIDER] Location permission denied. Falling back to Mysuru Center.');
          state = state.copyWith(
            hasLocationPermission: false,
            lat: 12.3051,
            lng: 76.6551,
            activeLocationName: 'Mysuru Center (Fallback)',
            isResolvingLocation: false,
          );
          search(refresh: true);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('[LOCATION_PROVIDER] Location permission permanently denied. Falling back to Mysuru Center.');
        state = state.copyWith(
          hasLocationPermission: false,
          lat: 12.3051,
          lng: 76.6551,
          activeLocationName: 'Mysuru Center (Fallback)',
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
        activeLocationName: 'GPS (${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)})',
        isResolvingLocation: false,
      );

      // Trigger search with current coordinates
      search(refresh: true);

    } catch (e) {
      print('[LOCATION_PROVIDER] Error resolving location: $e. Falling back to default coordinates.');
      state = state.copyWith(
        hasLocationPermission: false,
        lat: 12.3051,
        lng: 76.6551,
        activeLocationName: 'Mysuru Center (Default)',
        isResolvingLocation: false,
      );
      search(refresh: true);
    }
  }

  /// Pick a preset neighborhood or custom location
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
    double searchLat = state.lat;
    double searchLng = state.lng;
    if (searchLat == 0.0 && searchLng == 0.0) {
      searchLat = 12.3051;
      searchLng = 76.6551;
      state = state.copyWith(
        lat: searchLat,
        lng: searchLng,
        activeLocationName: 'Mysuru Center (Default)',
      );
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
        division: state.activeLocationName,
        page: targetPage,
        limit: 8,
      );

      List<dynamic> fetchedWorkers = res['workers'] ?? [];
      final int total = res['total'] ?? 0;
      final bool hasMore = res['has_more'] ?? false;
      bool isFallback = res['mode'] == 'citywide_rating_fallback' || res['is_fallback'] == true;
      String? advisory = res['advisory_message'] as String?;
      String resolvedCity = res['user_city'] as String? ?? state.userCity;
      String resolvedDiv = res['user_division'] as String? ?? (state.activeLocationName.isNotEmpty ? state.activeLocationName : 'Your Region');
      bool isUpcoming = res['is_upcoming_city'] as bool? ?? false;

      // Fallback: If 0 workers found nearby, load Top-Rated Workers sorted by highest rating
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
        if (advisory == null || advisory.isEmpty) {
          final catLabel = state.serviceType.isNotEmpty ? state.serviceType : 'Service';
          advisory = 'Workers in your region ($resolvedDiv) are currently busy. You can book these high-rated $catLabel workers across the entire city of $resolvedCity!';
        }
      } else if (isFallback && (advisory == null || advisory.isEmpty)) {
        final catLabel = state.serviceType.isNotEmpty ? state.serviceType : 'Service';
        advisory = 'Workers in your region ($resolvedDiv) are currently busy. You can book these high-rated $catLabel workers across the entire city of $resolvedCity!';
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
        advisoryMessage: advisory,
        userCity: resolvedCity,
        userDivision: resolvedDiv,
        isUpcomingCity: isUpcoming,
      );
    } catch (e) {
      // Fallback on network/API exception: show citywide workers with advisory
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

      final catLabel = state.serviceType.isNotEmpty ? state.serviceType : 'Service';
      final fallbackAdvisory = 'Workers in your region (${state.activeLocationName}) are currently busy. You can book these high-rated $catLabel workers across the entire city of Mysuru!';

      state = state.copyWith(
        workers: mysoreWorkers,
        isLoading: false,
        isLoadingMore: false,
        total: mysoreWorkers.length,
        isCitywideFallback: true,
        advisoryMessage: fallbackAdvisory,
        userCity: 'Mysuru',
        userDivision: state.activeLocationName,
        isUpcomingCity: false,
        errorMessage: null,
      );
    }
  }

  /// Mysore Fallback Workers database sorted by rating DESC
  List<dynamic> _getMysoreWorkersForService(String serviceType) {
    return SupabaseService.getMysoreFallbackWorkers(category: serviceType, limit: 12);
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
