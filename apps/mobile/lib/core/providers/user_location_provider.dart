import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserLocationState {
  final String city;
  final String locality;
  final double latitude;
  final double longitude;
  final bool isLoading;
  final bool isGpsDetected;
  final String? errorMessage;

  const UserLocationState({
    required this.city,
    required this.locality,
    required this.latitude,
    required this.longitude,
    this.isLoading = false,
    this.isGpsDetected = false,
    this.errorMessage,
  });

  String get shortName {
    if (locality.isNotEmpty && locality != city) {
      return '$locality, $city';
    }
    return city;
  }

  UserLocationState copyWith({
    String? city,
    String? locality,
    double? latitude,
    double? longitude,
    bool? isLoading,
    bool? isGpsDetected,
    String? errorMessage,
  }) {
    return UserLocationState(
      city: city ?? this.city,
      locality: locality ?? this.locality,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isLoading: isLoading ?? this.isLoading,
      isGpsDetected: isGpsDetected ?? this.isGpsDetected,
      errorMessage: errorMessage,
    );
  }
}

class UserLocationNotifier extends Notifier<UserLocationState> {
  static const _prefCityKey = 'jugaad_user_city';
  static const _prefLocalityKey = 'jugaad_user_locality';
  static const _prefLatKey = 'jugaad_user_lat';
  static const _prefLonKey = 'jugaad_user_lon';

  @override
  UserLocationState build() {
    _initFromPreferences();
    return const UserLocationState(
      city: 'Mysuru',
      locality: 'Gokulam',
      latitude: 12.3051,
      longitude: 76.6551,
      isLoading: false,
      isGpsDetected: false,
    );
  }

  Future<void> _initFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCity = prefs.getString(_prefCityKey);
      final savedLocality = prefs.getString(_prefLocalityKey);
      final savedLat = prefs.getDouble(_prefLatKey);
      final savedLon = prefs.getDouble(_prefLonKey);

      if (savedCity != null && savedCity.isNotEmpty) {
        state = state.copyWith(
          city: savedCity,
          locality: savedLocality ?? '',
          latitude: savedLat ?? state.latitude,
          longitude: savedLon ?? state.longitude,
        );
      } else {
        // Automatically probe GPS once in background
        detectCurrentLocation();
      }
    } catch (_) {}
  }

  Future<void> detectCurrentLocation() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Step 1: Check if location service is available
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Location services are disabled on your device.',
        );
        return;
      }

      // Step 2: Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Location permission was denied.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Location permission is permanently denied in settings.',
        );
        return;
      }

      // Step 3: Get position
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Could not acquire GPS coordinates.',
        );
        return;
      }

      // Step 4: Reverse Geocode to real City & Locality
      final geoResult = await _reverseGeocode(position.latitude, position.longitude);

      state = state.copyWith(
        city: geoResult.city,
        locality: geoResult.locality,
        latitude: position.latitude,
        longitude: position.longitude,
        isLoading: false,
        isGpsDetected: true,
        errorMessage: null,
      );

      _persistLocation(geoResult.city, geoResult.locality, position.latitude, position.longitude);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Location error: $e',
      );
    }
  }

  Future<({String city, String locality})> _reverseGeocode(double lat, double lon) async {
    // 1. Try Nominatim reverse geocode (cross-platform, works on Web & Mobile)
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=14&addressdetails=1',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'JugaadHyperlocalMarketplace/2.0'},
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};

        String city = address['city'] ??
            address['town'] ??
            address['municipality'] ??
            address['city_district'] ??
            address['county'] ??
            '';

        String locality = address['suburb'] ??
            address['neighbourhood'] ??
            address['residential'] ??
            address['commercial'] ??
            '';

        if (city.isNotEmpty) {
          if (city.toLowerCase().contains('mysore') || city.toLowerCase().contains('mysuru')) {
            city = 'Mysuru';
          } else if (city.toLowerCase().contains('bangalore') || city.toLowerCase().contains('bengaluru')) {
            city = 'Bengaluru';
          }
          return (city: city, locality: locality);
        }
      }
    } catch (_) {}

    // 2. Geographic coordinate heuristics for Karnataka/India fallback
    if (lat >= 12.15 && lat <= 12.45 && lon >= 76.50 && lon <= 76.80) {
      return (city: 'Mysuru', locality: 'Gokulam');
    } else if (lat >= 12.75 && lat <= 13.25 && lon >= 77.35 && lon <= 77.85) {
      return (city: 'Bengaluru', locality: 'HSR Layout');
    }

    return (city: 'Karnataka', locality: 'Local Area');
  }

  void setManualLocation({
    required String city,
    required String locality,
    required double latitude,
    required double longitude,
  }) {
    state = state.copyWith(
      city: city,
      locality: locality,
      latitude: latitude,
      longitude: longitude,
      isLoading: false,
      isGpsDetected: false,
      errorMessage: null,
    );
    _persistLocation(city, locality, latitude, longitude);
  }

  Future<void> _persistLocation(String city, String locality, double lat, double lon) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCityKey, city);
      await prefs.setString(_prefLocalityKey, locality);
      await prefs.setDouble(_prefLatKey, lat);
      await prefs.setDouble(_prefLonKey, lon);
    } catch (_) {}
  }
}

final userLocationProvider = NotifierProvider<UserLocationNotifier, UserLocationState>(
  UserLocationNotifier.new,
);
