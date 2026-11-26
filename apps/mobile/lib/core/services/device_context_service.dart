import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/supabase_config.dart';
import 'auth_service.dart';

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
  static const _kActivityLogKey = 'jugaad_activity_log';
  static const _kSessionIdKey = 'jugaad_session_id';

  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<BatteryState>? _batterySub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _syncDebounce;
  bool _initialized = false;

  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.full;
  bool _isSlowOrMeteredNetwork = false;
  bool _isOffline = false;
  String _networkType = 'wifi';
  String _sessionId = '';
  List<String> _recentSearches = [];
  List<Map<String, dynamic>> _activityLog = [];
  String? _lastBookedSkill;
  String? _trustedContactName;
  String? _trustedContactPhone;

  int get batteryLevel => _batteryLevel;
  BatteryState get batteryState => _batteryState;
  bool get isSlowOrMeteredNetwork => _isSlowOrMeteredNetwork;
  bool get isOffline => _isOffline;
  String get networkType => _networkType;
  String get devicePlatform => kIsWeb ? 'Web' : defaultTargetPlatform.name;

  /// First-party session & preference cookie metadata for Admin diagnostics.
  Map<String, dynamic> get cookieProfile => {
        'consent_status': 'accepted_essential',
        'session_id': _sessionId.isNotEmpty
            ? _sessionId
            : 'jg_sess_${DateTime.now().millisecondsSinceEpoch}',
        'cookies_enabled': true,
        'preferred_language': 'en',
        'portal_mode': 'user',
        'stored_keys': [
          'jugaad_session_id',
          if (_recentSearches.isNotEmpty) 'jugaad_recent_searches',
          if (_lastBookedSkill != null) 'jugaad_last_booked_skill',
          if (hasTrustedContact) 'jugaad_trusted_contact',
        ],
        'last_cookie_sync_at': DateTime.now().toIso8601String(),
      };

  /// Derives a concise behavioral pattern label from in-app & device signals.
  String get behaviorPattern {
    if (isLowBattery && isNightTime) {
      return 'Night Emergency • Low-Battery Express';
    }
    if (isLowBattery) {
      return 'Battery-Conscious • 1-Tap Express';
    }
    if (isSlowOrMeteredNetwork && _recentSearches.isNotEmpty) {
      return 'On-the-Go Mobile Searcher (${_recentSearches.first})';
    }
    if (_lastBookedSkill != null) {
      return 'Repeat ${_lastBookedSkill!.replaceAll('_', ' ')} Booker';
    }
    if (_recentSearches.isNotEmpty) {
      return 'Active Explorer (${_recentSearches.first})';
    }
    return isNightTime ? 'Late-Night Browser' : 'Standard Daytime User';
  }
  List<String> get recentSearches => List.unmodifiable(_recentSearches);
  List<Map<String, dynamic>> get activityLog => List.unmodifiable(_activityLog);
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
    await recordActivity('app_open', 'Opened Jugaad ($devicePlatform • $_networkType)');

    try {
      _batterySub = _battery.onBatteryStateChanged.listen((state) async {
        _batteryState = state;
        await _refreshBattery(notify: false);
        notifyListeners();
        _syncActivityToBackend();
      });
    } catch (_) {
      // Safe no-op on unsupported platforms or tests
    }

    try {
      _connectivitySub =
          _connectivity.onConnectivityChanged.listen((results) {
        final prevNetwork = _networkType;
        _applyConnectivity(results);
        notifyListeners();
        if (prevNetwork != _networkType) {
          recordActivity('network_change', 'Switched to $_networkType');
        } else {
          _syncActivityToBackend();
        }
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
      _sessionId = prefs.getString(_kSessionIdKey) ?? '';
      if (_sessionId.isEmpty) {
        _sessionId = 'jg_sess_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString(_kSessionIdKey, _sessionId);
      }
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
    if (_isOffline) {
      _networkType = 'offline';
    } else if (results.contains(ConnectivityResult.wifi)) {
      _networkType = 'wifi';
    } else if (results.contains(ConnectivityResult.mobile)) {
      _networkType = 'mobile';
    } else if (results.contains(ConnectivityResult.ethernet)) {
      _networkType = 'ethernet';
    } else if (results.contains(ConnectivityResult.vpn)) {
      _networkType = 'vpn';
    } else {
      _networkType = results.first.name;
    }
  }

  Future<void> _syncActivityToBackend() async {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 2500), () async {
      try {
        final uid = AuthService().currentUser?.uid;
        if (uid == null || uid.isEmpty) return;
        await SupabaseConfig.client.from('users').update({
          'battery_level': _batteryLevel,
          'is_low_battery': isLowBattery,
          'battery_state': _batteryState.name,
          'network_mode': _networkType,
          'device_platform': devicePlatform,
          'recent_searches': _recentSearches,
          'last_booked_skill': _lastBookedSkill,
          'has_trusted_contact': hasTrustedContact,
          'behavior_pattern': behaviorPattern,
          'cookie_profile': cookieProfile,
          'activity_log': _activityLog,
          'last_active_at': DateTime.now().toIso8601String(),
        }).eq('id', uid);
      } catch (_) {
        // Safe no-op if offline, uninitialized, or columns not migrated yet
      }
    });
  }

  /// Records an in-app or device event to the user's activity feed and syncs it.
  Future<void> recordActivity(String type, String detail) async {
    final entry = <String, dynamic>{
      'type': type,
      'detail': detail,
      'battery': _batteryLevel,
      'network': _networkType,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _activityLog = [entry, ..._activityLog].take(20).toList();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kActivityLogKey,
        _activityLog
            .map((e) => '${e['type']}|${e['detail']}|${e['timestamp']}')
            .toList(),
      );
    } catch (_) {}
    await _syncActivityToBackend();
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
    await recordActivity('search', 'Searched "$normalized"');
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
    await recordActivity('booking', 'Booked $normalized');
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
    _syncActivityToBackend();
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
    _syncDebounce?.cancel();
    _batterySub?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
