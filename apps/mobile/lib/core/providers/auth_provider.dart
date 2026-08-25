import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

class UserSession {
  final String? uid;
  final String? role;
  final bool isLoading;

  const UserSession({this.uid, this.role, this.isLoading = false});

  UserSession copyWith({String? uid, String? role, bool? isLoading}) {
    return UserSession(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Maps raw DB role strings to canonical app roles. Single source of truth. (Fix M6)
String? _mapRole(String? rawRole) {
  if (rawRole == null) return null;
  if (rawRole == 'employer' || rawRole == 'customer') return 'user';
  return rawRole;
}

class AuthNotifier extends Notifier<UserSession> {
  final AuthService _authService = AuthService();
  bool _suppressAutoFetch = false;

  /// Stored subscription so it can be cancelled on dispose. (Fix C3)
  StreamSubscription<dynamic>? _authSub;

  void suppressAutoFetch() {
    _suppressAutoFetch = true;
    debugPrint('[AUTH_PROVIDER] Auto-fetch SUPPRESSED');
  }

  void unsuppressAutoFetch() {
    _suppressAutoFetch = false;
    debugPrint('[AUTH_PROVIDER] Auto-fetch UNSUPPRESSED');
  }

  @override
  UserSession build() {
    // Cancel previous subscription to prevent stacking on rebuild. (Fix C3)
    _authSub?.cancel();
    _authSub = _authService.authStateChanges.listen((user) async {
      if (user == null) {
        debugPrint('[AUTH_PROVIDER] Auth state changed: user is null');
        _suppressAutoFetch = false;
        state = const UserSession();
      } else {
        if (state.uid != user.uid) {
          if (_suppressAutoFetch) {
            debugPrint('[AUTH_PROVIDER] Auto-fetch SUPPRESSED. Setting uid only.');
            state = UserSession(uid: user.uid, isLoading: false);
          } else {
            debugPrint('[AUTH_PROVIDER] Fetching role...');
            state = UserSession(uid: user.uid, isLoading: true);
            final role = await _authService.fetchUserRole(user.uid);
            final mapped = _mapRole(role);
            debugPrint('[AUTH_PROVIDER] Role loaded: $mapped for ${user.uid}');
            state = UserSession(uid: user.uid, role: mapped, isLoading: false);
          }
        }
      }
    });

    // Cancel subscription on dispose. (Fix C3)
    ref.onDispose(() {
      _authSub?.cancel();
      _authSub = null;
      debugPrint('[AUTH_PROVIDER] Subscription cancelled on dispose');
    });

    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      Future(() async {
        if (_suppressAutoFetch) return;
        final role = await _authService.fetchUserRole(currentUser.uid);
        final mapped = _mapRole(role);
        debugPrint('[AUTH_PROVIDER] Initial role loaded: $mapped');
        state = UserSession(uid: currentUser.uid, role: mapped, isLoading: false);
      });
      return const UserSession(isLoading: true);
    }

    return const UserSession();
  }

  Future<String?> fetchAndCacheRole(String uid) async {
    debugPrint('[AUTH_PROVIDER] Manual role fetch for: $uid');
    state = state.copyWith(isLoading: true);
    final role = await _authService.fetchUserRole(uid);
    final mapped = _mapRole(role);
    debugPrint('[AUTH_PROVIDER] Manual role fetch complete: $mapped');
    state = UserSession(uid: uid, role: mapped, isLoading: false);
    return mapped;
  }

  void setRole(String? role) {
    final mapped = _mapRole(role);
    debugPrint('[AUTH_PROVIDER] setRole: $role -> $mapped');
    state = state.copyWith(role: mapped);
  }

  void clear() {
    _suppressAutoFetch = false;
    state = const UserSession();
  }
}

final authProvider = NotifierProvider<AuthNotifier, UserSession>(
  AuthNotifier.new,
);
