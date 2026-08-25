import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/supabase_config.dart';
import 'app_theme.dart';
import 'user_app_theme.dart';
import 'worker_app_theme.dart';
import '../services/heartbeat_service.dart';

enum PortalMode { user, worker }

extension PortalModeExtension on PortalMode {
  Color get primary {
    switch (this) {
      case PortalMode.user:
        return UserAppTheme.primaryBlue;
      case PortalMode.worker:
        return WorkerAppTheme.primaryGreen;
    }
  }

  Color get primaryLight {
    switch (this) {
      case PortalMode.user:
        return const Color(0xFFEFF6FF);
      case PortalMode.worker:
        return const Color(0xFFE1F5EE);
    }
  }

  ThemeData get theme {
    switch (this) {
      case PortalMode.user:
        return AppTheme.userTheme();
      case PortalMode.worker:
        return AppTheme.workerTheme();
    }
  }

  String get label {
    switch (this) {
      case PortalMode.user:
        return "User";
      case PortalMode.worker:
        return "Worker";
    }
  }

  String get pillText {
    switch (this) {
      case PortalMode.user:
        return "User";
      case PortalMode.worker:
        return "Worker";
    }
  }
}

class PortalModeProvider extends ChangeNotifier {
  static const String _prefKey = 'portal_mode';
  PortalMode _mode = PortalMode.user;
  bool _isInitialized = false;

  PortalMode get mode => _mode;

  PortalModeProvider() {
    _loadMode();
  }

  Future<void> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isInitialized) {
      print('[THEME] _loadMode aborted because portal mode was already explicitly set.');
      return;
    }
    final String? modeString = prefs.getString(_prefKey);
    if (modeString == 'worker') {
      _mode = PortalMode.worker;
    } else {
      _mode = PortalMode.user;
    }
    _isInitialized = true;
    await _syncHeartbeatForMode();
    notifyListeners();
  }

  Future<void> setMode(PortalMode newMode) async {
    _mode = newMode;
    _isInitialized = true;
    print('[THEME] Portal mode set to: ${_mode.name}');
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, newMode.name);
    await _syncHeartbeatForMode();
  }

  /// Silently sets mode without triggering GoRouter redirect loop.
  /// Use ONLY during login redirect — not for user-triggered mode switches.
  void setModeWithoutNotify(PortalMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    _isInitialized = true;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_prefKey, newMode.name);
    });
  }

  Future<void> _syncHeartbeatForMode() async {
    if (_mode == PortalMode.worker) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          final result = await SupabaseConfig.client
              .from('workers')
              .select('approval_status')
              .eq('id', uid)
              .maybeSingle();
          if (result != null && result['approval_status'] == 'approved') {
            HeartbeatService().startHeartbeat(uid);
          } else {
            HeartbeatService().stopHeartbeat();
          }
        } catch (_) {
          HeartbeatService().stopHeartbeat();
        }
      } else {
        HeartbeatService().stopHeartbeat();
      }
    } else {
      HeartbeatService().stopHeartbeat();
    }
  }

  void toggleMode() {
    setMode(_mode == PortalMode.user ? PortalMode.worker : PortalMode.user);
  }
}
