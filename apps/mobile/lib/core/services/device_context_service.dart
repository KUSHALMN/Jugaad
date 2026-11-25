import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Privacy-safe device & in-app context manager for Jugaad.
///
/// Tracks:
/// 1. Battery level & charging state -> triggers Low-Battery Express Mode (< 15%).
/// 2. Network connectivity (`connectivity_plus`), time of day, city, and recent
///    in-app searches/bookings -> powers smart service ranking & lightweight mode.
/// 3. Optional user-picked Trusted Emergency Contact -> 1-tap SMS/WhatsApp
///    tracking link sharing during critical battery or Night Emergency jobs.
class DeviceContextService extends ChangeNotifier {
  DeviceContextService._();

  static final DeviceContextService instance = DeviceContextService._();

  static const _kRecentSearchesKey = 'jugaad_recent_searches';
  static const _kLastBookedSkillKey = 'jugaad_last_booked_skill';
  static const _kTrustedContactNameKey = 'jugaad_trusted_contact_name';
  static const _kTrustedContactPhoneKey = 'jugaad_trusted_contact_phone';

  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<BatteryState>? _batterySub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _initialized = false;

  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.full;
  bool _isSlowOrMeteredNetwork = false;
  bool _isOffline = false;
  List<String> _recentSearches = [];
  String? _lastBookedSkill;
  String? _trustedContactName;
  String? _trustedContactPhone;

  int get batteryLevel => _batteryLevel;
  BatteryState get batteryState => _batteryState;
  bool get isSlowOrMeteredNetwork => _isSlowOrMeteredNetwork;
  bool get isOffline => _isOffline;
  List<String> get recentSearches => List.unmodifiable(_recentSearches);
  String? get lastBookedSkill => _lastBookedSkill;
  String? get trustedContactName => _trustedContactName;
  String? get trustedContactPhone => _trustedContactPhone;

  /// True when battery is below 15% and the device is not charging.
  bool get isLowBattery =>
      _batteryLevel < 15 &&
      _batteryState != BatteryState.charging &&
      _batteryState != BatteryState.full;

  /// True when heavy animations or video preloads should be paused.
  bool get shouldPauseHeavyMedia => isLowBattery || _isSlowOrMeteredNetwork;

  /// Reduced GPS polling interval when battery is low.
  Duration get gpsPollingInterval =>
      isLowBattery ? const Duration(seconds: 30) : const Duration(seconds: 8);

  bool get hasTrustedContact =>
      (_trustedContactPhone ?? '').trim().isNotEmpty;

  bool get isNightTime {
    final hour = DateTime.now().hour;
    return hour >= 21 || hour < 6;
  }

  /// Initializes listeners and loads persisted preferences safely.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _loadPrefs();
    await _refreshBattery();
    await _refreshConnectivity();

    try {
      _batterySub = _battery.onBatteryStateChanged.listen((state) async {
        _batteryState = state;
        await _refreshBattery(notify: false);
        notifyListeners();
      });
    } catch (_) {
      // Safe no-op on unsupported platforms or tests
    }

    try {
      _connectivitySub =
          _connectivity.onConnectivityChanged.listen((results) {
        _applyConnectivity(results);
        notifyListeners();
      });
    } catch (_) {
      // Safe no-op on unsupported platforms or tests
    }
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recentSearches =
          prefs.getStringList(_kRecentSearchesKey) ?? <String>[];
      _lastBookedSkill = prefs.getString(_kLastBookedSkillKey);
      _trustedContactName = prefs.getString(_kTrustedContactNameKey);
      _trustedContactPhone = prefs.getString(_kTrustedContactPhoneKey);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _refreshBattery({bool notify = true}) async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      _batteryLevel = level;
      _batteryState = state;
      if (notify) notifyListeners();
    } catch (_) {
      // Keep safe defaults when battery API is unavailable
    }
  }

  Future<void> _refreshConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _applyConnectivity(results);
      notifyListeners();
    } catch (_) {}
  }

  void _applyConnectivity(List<ConnectivityResult> results) {
    _isOffline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    _isSlowOrMeteredNetwork =
        _isOffline || results.contains(ConnectivityResult.mobile);
  }

  /// Records a user search query to personalize service recommendations.
  Future<void> recordSearch(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return;
    _recentSearches = [
      normalized,
      ..._recentSearches.where((q) => q != normalized),
    ].take(5).toList();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kRecentSearchesKey, _recentSearches);
    } catch (_) {}
  }

  /// Records the most recently booked skill for smart re-ranking.
  Future<void> recordBookedSkill(String skill) async {
    final normalized = skill.trim().toLowerCase();
    if (normalized.isEmpty) return;
    _lastBookedSkill = normalized;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastBookedSkillKey, normalized);
    } catch (_) {}
  }

  /// Saves an optional user-picked Trusted Emergency Contact.
  Future<void> saveTrustedContact({
    required String name,
    required String phone,
  }) async {
    _trustedContactName = name.trim();
    _trustedContactPhone = phone.trim();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTrustedContactNameKey, _trustedContactName!);
      await prefs.setString(_kTrustedContactPhoneKey, _trustedContactPhone!);
    } catch (_) {}
  }

  /// Clears the saved Trusted Emergency Contact.
  Future<void> clearTrustedContact() async {
    _trustedContactName = null;
    _trustedContactPhone = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kTrustedContactNameKey);
      await prefs.remove(_kTrustedContactPhoneKey);
    } catch (_) {}
  }

  /// Scores a service key using recent searches, last booking, time of day, and city.
  int scoreSkill(String skillKey, {String? city}) {
    final key = skillKey.toLowerCase();
    int score = 0;

    if (_lastBookedSkill != null &&
        (key == _lastBookedSkill || key.contains(_lastBookedSkill!))) {
      score += 40;
    }
    for (final q in _recentSearches) {
      if (key.contains(q) || q.contains(key.replaceAll('_', ' '))) {
        score += 30;
        break;
      }
    }
    if (isNightTime &&
        (key == 'electrician' || key == 'plumber' || key == 'ac_repair')) {
      score += 20;
    }
    if ((city ?? '').toLowerCase().contains('mysur') &&
        (key == 'electrician' || key == 'ac_repair')) {
      score += 10;
    }
    return score;
  }

  /// Launches SMS or WhatsApp to share a live tracking link with the trusted contact.
  Future<bool> shareTrackingWithTrustedContact({
    required String jobId,
    String? workerName,
    String? serviceName,
    bool useWhatsApp = false,
  }) async {
    final rawPhone = (_trustedContactPhone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (rawPhone.isEmpty) return false;

    final contactLabel =
        (_trustedContactName ?? '').isNotEmpty ? _trustedContactName! : 'Family';
    final reason = isLowBattery
        ? 'My phone battery is low ($_batteryLevel%).'
        : (isNightTime ? 'Night Emergency booking.' : 'Jugaad Safety Update.');
    final workerPart =
        (workerName ?? '').isNotEmpty ? ' Technician: $workerName.' : '';
    final servicePart =
        (serviceName ?? '').isNotEmpty ? ' Service: $serviceName.' : '';
    final trackingUrl = 'https://jugaad.app/track/$jobId';
    final message =
        'Hi $contactLabel, $reason$servicePart$workerPart Track my live Jugaad service here: $trackingUrl';

    final uri = useWhatsApp
        ? Uri.parse(
            'https://wa.me/${rawPhone.replaceAll('+', '')}?text=${Uri.encodeComponent(message)}',
          )
        : Uri(
            scheme: 'sms',
            path: rawPhone,
            queryParameters: {'body': message},
          );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}
    return false;
  }

  @visibleForTesting
  void setBatteryForTesting(int level, BatteryState state) {
    _batteryLevel = level;
    _batteryState = state;
    notifyListeners();
  }

  @visibleForTesting
  void setNetworkForTesting({bool? isSlowOrMetered, bool? isOffline}) {
    if (isSlowOrMetered != null) _isSlowOrMeteredNetwork = isSlowOrMetered;
    if (isOffline != null) _isOffline = isOffline;
    notifyListeners();
  }

  @override
  void dispose() {
    _batterySub?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
