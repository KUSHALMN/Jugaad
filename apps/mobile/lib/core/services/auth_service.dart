import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import 'api_service.dart';

/// Production-ready Firebase auth service.
/// Supports: Google Sign-In (v7 API), Email/Password.
/// The JWT (ID token) is sent as `Authorization: Bearer <token>`
/// to all backend API calls. Backend verifies with firebase_admin.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _webClientId = '745766971944-p6e287vftbuha15938lrcnis87eoaq46.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? _webClientId : null,
    serverClientId: kIsWeb ? null : _webClientId,
  );

  // ─── Current state ───────────────────────────────────────
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String? _userRole;
  String? get userRole => _userRole;

  void setUserRole(String? role) {
    _userRole = role;
  }

  Future<String?> fetchUserRole(String uid) async {
    try {
      final client = SupabaseConfig.client;

      // Check workers table first — this is the source of truth for worker identity
      final workerDoc = await client
          .from('workers')
          .select('id')
          .eq('id', uid)
          .maybeSingle();
      if (workerDoc != null) {
        _userRole = 'worker';
        print('Role fetched: $_userRole');
        return _userRole;
      }

      // Fall back to users table role
      final res = await client
          .from('users')
          .select('role')
          .eq('id', uid)
          .maybeSingle();
      if (res != null && res['role'] != null) {
        final dbRole = res['role'] as String;
        if (dbRole == 'employer') {
          _userRole = 'customer';
        } else {
          _userRole = dbRole;
        }
        print('Role fetched: $_userRole');
        return _userRole;
      }
    } catch (e) {
      debugPrint('[AUTH_SERVICE] Error fetching user role from Supabase: $e');
    }
    print('Role fetched: null');
    return null;
  }

  // ─── 1. Google Sign-In ────────────────────────────────────
  /// Signs in with Google.
  /// Returns the signed-in [UserCredential]. Throws on failure or if user cancels.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('[AUTH] signInWithGoogle: Starting...');
      final UserCredential userCredential;
      if (kIsWeb) {
        print('[AUTH] signInWithGoogle: Using web popup flow');
        final googleProvider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(googleProvider);
        print('[AUTH] signInWithGoogle: Popup completed successfully');
      } else {
        print('[AUTH] signInWithGoogle: Using native flow');
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          print('[AUTH] signInWithGoogle: User cancelled (native)');
          return null;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential =
            await _auth.signInWithCredential(credential);
        print('[AUTH] signInWithGoogle: Native credential sign-in completed');
      }

      final user = userCredential.user;
      print('[AUTH] signInWithGoogle: Firebase auth SUCCESS — uid=${user?.uid}, email=${user?.email}');

      if (user != null) {
        // After sign-in, sync user to Supabase via backend
        print('[AUTH] signInWithGoogle: Step 1 — syncing user to backend...');
        await _syncUserToBackend(user);
        
        // Also ensure user doc exists in Supabase
        print('[AUTH] signInWithGoogle: Step 2 — ensuring user doc...');
        await _ensureUserDoc(user);
        print('[AUTH] signInWithGoogle: All sync steps complete');
      }

      return userCredential;
    } on PlatformException catch (e) {
      debugPrint('Google Sign-In PlatformException: ${e.code} - ${e.message}');
      if (e.code == 'sign_in_failed') {
        throw PlatformException(
          code: 'sign_in_failed',
          message: 'Sign-in failed. Please check SHA configuration.',
        );
      } else if (e.code == 'sign_in_cancelled') {
        throw PlatformException(
          code: 'sign_in_cancelled',
          message: 'User cancelled',
        );
      }
      rethrow;
    } on FirebaseAuthException catch (e) {
      debugPrint('Google Sign-In FirebaseAuthException: ${e.code} - ${e.message}');
      if (e.code == 'account-exists-with-different-credential') {
        throw FirebaseAuthException(
          code: 'account-exists-with-different-credential',
          message: 'An account already exists with a different credential. Please use email/password login.',
        );
      }
      rethrow;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  Future<void> _syncUserToBackend(User user) async {
    try {
      print('[AUTH] _syncUserToBackend: Starting sync for UID=${user.uid}, email=${user.email}');
      // Use DioClient (has retries, auth token injection, proper error handling)
      // instead of raw http.post which silently fails without retries.
      final response = await ApiService.client.post(
        '/v1/users/sync',
        data: {
          'uid': user.uid,
          'email': user.email,
          'name': user.displayName,
          'photo_url': user.photoURL,
          'provider': 'google',
        },
      );
      print('[AUTH] _syncUserToBackend: SUCCESS (${response.statusCode})');
    } catch (e) {
      // Don't block sign-in if backend sync fails — the backend's
      // ensure_db_user middleware will auto-provision on the next API call.
      print('[AUTH] _syncUserToBackend: FAILED — $e');
      debugPrint('[AUTH] Backend sync failed (non-fatal): $e');
    }
  }

  // ─── 2. Email/Password Sign-In ────────────────────────────
  /// Signs in with email and password. Returns the signed-in [User].
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (result.user == null) throw Exception('Sign-in returned null user');
      await _ensureUserDoc(result.user!);
      return result.user!;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No account found with this email');
        case 'wrong-password':
          throw Exception('Incorrect password');
        case 'invalid-email':
          throw Exception('Invalid email address');
        case 'user-disabled':
          throw Exception('This account has been disabled');
        case 'invalid-credential':
          throw Exception('Invalid email or password');
        default:
          throw Exception(e.message ?? 'Sign-in failed');
      }
    }
  }

  // ─── 3. Email/Password Sign-Up ────────────────────────────
  /// Creates a new account with email and password.
  Future<User> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (result.user == null) throw Exception('Sign-up returned null user');
      
      // Update display name in Firebase Auth
      await result.user!.updateDisplayName(name.trim());
      await result.user!.reload();
      
      final updatedUser = _auth.currentUser!;
      await _ensureUserDoc(updatedUser);
      return updatedUser;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('An account already exists with this email');
        case 'weak-password':
          throw Exception('Password is too weak. Use at least 6 characters.');
        case 'invalid-email':
          throw Exception('Invalid email address');
        default:
          throw Exception(e.message ?? 'Sign-up failed');
      }
    }
  }

  // ─── 4. Password Reset ────────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No account found with this email');
        case 'invalid-email':
          throw Exception('Invalid email address');
        default:
          throw Exception(e.message ?? 'Failed to send reset email');
      }
    }
  }

  // ─── 5. Get JWT (for backend API calls) ───────────────────
  /// Returns a fresh Firebase ID token (JWT).
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return await _auth.currentUser?.getIdToken(forceRefresh);
  }

  /// Convenience: returns the full Authorization header value.
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getIdToken();
    if (token == null) throw Exception('Not authenticated');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // ─── 6. Sign out ──────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _userRole = null;
    await _auth.signOut();
  }

  // ─── 7. Ensure Supabase user document exists ──────────────
  Future<void> _ensureUserDoc(User user) async {
    try {
      // Fix M2: use null for missing phone instead of empty string
      // to avoid violating NOT NULL constraints on the backend.
      final phone = (user.phoneNumber?.isNotEmpty == true) ? user.phoneNumber : null;
      await ApiService().syncUser(
        user.email ?? '',
        user.displayName ?? '',
        phone,
      );
    } catch (e) {
      debugPrint('[AUTH] Error ensuring user doc via API: $e');
    }
  }
}
