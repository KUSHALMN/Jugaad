import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as pkg_provider;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/portal_mode.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/config/supabase_config.dart';
import '../../../shared/widgets/jugaad_button.dart';
import '../../../shared/widgets/responsive_wrapper.dart';

class LoginScreen extends StatefulWidget {
  final PortalMode selectedRole;

  const LoginScreen({super.key, required this.selectedRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isEmailMode = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        pkg_provider.Provider.of<PortalModeProvider>(context, listen: false).setMode(widget.selectedRole);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // BUG FIX: Suppress auto-fetch to prevent race condition with _handleRouting
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    // Suppress the auth listener's auto role-fetch to prevent race condition
    final container = ProviderScope.containerOf(context);
    container.read(authProvider.notifier).suppressAutoFetch();

    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential == null || userCredential.user == null) {
        container.read(authProvider.notifier).unsuppressAutoFetch();
        setState(() => _isLoading = false);
        return; // User cancelled
      }
      if (!mounted) return;
      await _handleRouting(userCredential.user!.uid);
    } on PlatformException catch (e) {
      if (!mounted) return;
      container.read(authProvider.notifier).unsuppressAutoFetch();
      setState(() => _isLoading = false);
      if (e.code == 'sign_in_cancelled') {
        return;
      }
      if (e.code == 'sign_in_failed') {
        _showErrorToast('Sign-in failed. Please check SHA configuration.');
      } else {
        _showErrorToast('Sign-in failed: ${e.message ?? e.code}');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      container.read(authProvider.notifier).unsuppressAutoFetch();
      setState(() => _isLoading = false);
      if (e.code == 'account-exists-with-different-credential') {
        _showErrorToast('An account already exists with a different credential. Please use email/password login.');
      } else {
        _showErrorToast(e.message ?? 'Authentication failed');
      }
    } catch (e) {
      if (!mounted) return;
      container.read(authProvider.notifier).unsuppressAutoFetch();
      setState(() => _isLoading = false);
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('cancelled')) return; // User cancelled, no error
      _showErrorToast(msg);
    }
  }

  // ─── Email Sign-In / Sign-Up ─────────────────────────
  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    // Validate
    setState(() {
      _nameError = null;
      _emailError = null;
      _passwordError = null;
    });

    if (_isSignUp && name.isEmpty) {
      setState(() => _nameError = 'Please enter your name');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _emailError = 'Enter a valid email address');
      return;
    }
    if (password.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);

    // Suppress the auth listener's auto role-fetch to prevent race condition
    final container = ProviderScope.containerOf(context);
    container.read(authProvider.notifier).suppressAutoFetch();

    try {
      User user;
      if (_isSignUp) {
        user = await _authService.signUpWithEmail(email: email, password: password, name: name);
      } else {
        user = await _authService.signInWithEmail(email: email, password: password);
      }
      if (!mounted) return;
      print('Login success, fetching role...');
      await _handleRouting(user.uid);
    } catch (e) {
      if (!mounted) return;
      container.read(authProvider.notifier).unsuppressAutoFetch();
      setState(() => _isLoading = false);
      String msg = e.toString().replaceAll('Exception: ', '');
      _showErrorToast(msg);
    }
  }

  // ─── Forgot Password ────────────────────────────────
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showErrorToast('Enter your email address first');
      return;
    }

    try {
      await _authService.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent! Check your inbox.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString().replaceAll('Exception: ', '');
      _showErrorToast(msg);
    }
  }

  // ─── Handle Routing ──────────────────────────────────
  Future<void> _handleRouting(String uid) async {
    print('[ROUTING] _handleRouting: START for uid=$uid');

    // CRITICAL: Set portal mode IMMEDIATELY — before any awaits.
    final selectedRole = widget.selectedRole;
    print('[ROUTING] _handleRouting: Selected role = ${selectedRole.name}');
    pkg_provider.Provider.of<PortalModeProvider>(context, listen: false).setMode(selectedRole);

    bool isFirstTime = true;
    final client = SupabaseConfig.client;

    try {
      if (selectedRole == PortalMode.worker) {
        // Check if the user already has a worker profile
        // NOTE: Using SELECT only — Supabase anon key allows reads via
        // the "workers_anonymous_all" and "users_anonymous_read" policies.
        // We do NOT write directly — that's blocked by RLS since we use
        // Firebase Auth (not Supabase Auth), so auth.uid() is always NULL.
        print('[ROUTING] _handleRouting: Checking workers table for uid=$uid...');
        final workerDoc = await client
            .from('workers')
            .select()
            .eq('id', uid)
            .maybeSingle();
        if (workerDoc != null) {
          isFirstTime = false;
          print('[ROUTING] _handleRouting: Worker profile FOUND — existing worker');
        } else {
          print('[ROUTING] _handleRouting: No worker profile — new worker (will need registration)');
          // The user row was already created by the backend's ensure_db_user
          // middleware during _syncUserToBackend. No direct upsert needed.
        }
      } else {
        // Check if the user already exists in the users table
        print('[ROUTING] _handleRouting: Checking users table for uid=$uid...');
        final userDoc = await client
            .from('users')
            .select()
            .eq('id', uid)
            .maybeSingle();
        if (userDoc != null) {
          isFirstTime = false;
          print('[ROUTING] _handleRouting: User profile FOUND — existing user');
        } else {
          print('[ROUTING] _handleRouting: No user profile found — new user');
          // The user row was already created by the backend's ensure_db_user
          // middleware during _syncUserToBackend. No direct upsert needed.
        }
      }
    } catch (e) {
      print('[ROUTING] _handleRouting: Supabase query failed: $e');
      // If the query fails, assume first time — the backend already
      // created the user via ensure_db_user, so navigation will still work.
    }

    if (!mounted) return;

    // Now set the correct role in the AuthNotifier so GoRouter redirects work.
    final container = ProviderScope.containerOf(context);
    final authNotifier = container.read(authProvider.notifier);

    // Set role based on selected portal — this is the SOURCE OF TRUTH
    // for routing. The DB role is secondary; portal mode determines
    // which shell the user sees.
    final roleToSet = selectedRole == PortalMode.worker ? 'worker' : 'user';
    print('[ROUTING] _handleRouting: Setting auth role to "$roleToSet"');
    authNotifier.setRole(roleToSet);

    // Unsuppress auto-fetch now that we've set the role ourselves
    authNotifier.unsuppressAutoFetch();

    setState(() => _isLoading = false);

    // Navigate explicitly
    if (selectedRole == PortalMode.user) {
      print('[ROUTING] _handleRouting: Navigating to /user/home');
      context.go('/user/home');
    } else {
      if (isFirstTime) {
        print('[ROUTING] _handleRouting: Navigating to /worker/register/step1 (new worker)');
        context.go('/worker/register/step1');
      } else {
        print('[ROUTING] _handleRouting: Navigating to /worker/home (existing worker)');
        context.go('/worker/home');
      }
    }
    print('[ROUTING] _handleRouting: DONE');
  }

  void _showErrorToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.selectedRole.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20.0),
            onPressed: () {
              if (_isEmailMode) {
                setState(() => _isEmailMode = false);
              } else {
                context.go('/auth/role');
              }
            },
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveWrapper(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.1, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: _isEmailMode 
                ? _buildEmailLogin(primaryColor) 
                : _buildMainLogin(primaryColor),
          ),
        ),
      ),
    );
  }

  // ─── Main Login View (Google + Email buttons) ────────
  Widget _buildMainLogin(Color primaryColor) {
    final isWorker = widget.selectedRole == PortalMode.worker;
    return Padding(
      key: const ValueKey('main_login'),
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24.0),
          Text(
            isWorker ? 'Sign in as Worker' : 'Sign in to Jugaad',
            style: AppTextStyles.heading2(color: AppColors.textPrimary).copyWith(
              fontSize: 26.0,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            isWorker 
                ? 'Unlock hyperlocal job opportunities in Mysuru'
                : 'Book verified skills and services instantly',
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 48.0),

          // Google Sign-In Button with neat custom border
          SizedBox(
            width: double.infinity,
            height: 54.0,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _signInWithGoogle,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)))
                  : const Icon(Icons.g_mobiledata, color: Color(0xFF4285F4), size: 28),
              label: Text(
                'Continue with Google',
                style: AppTextStyles.bodyLarge(color: AppColors.textPrimary, weight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.black.withValues(alpha: 0.08), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50.0)),
                backgroundColor: AppColors.surface,
                elevation: 0,
              ),
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.15, end: 0.0),
          
          const SizedBox(height: 24.0),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: Colors.black.withValues(alpha: 0.06), height: 1.0)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('or', style: AppTextStyles.bodySmall(color: AppColors.textSecondary, weight: FontWeight.w600)),
              ),
              Expanded(child: Divider(color: Colors.black.withValues(alpha: 0.06), height: 1.0)),
            ],
          ).animate().fadeIn(delay: 200.ms),
          
          const SizedBox(height: 24.0),

          // Email Sign-In Button
          JugaadButton(
            text: 'Continue with Email',
            isLoading: _isLoading && _isEmailMode,
            onPressed: _isLoading
                ? null
                : () => setState(() {
                      _isEmailMode = true;
                      _isSignUp = false;
                    }),
            type: isWorker ? JugaadButtonType.success : JugaadButtonType.primary,
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.15, end: 0.0),
          
          const Spacer(),
          
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                'By continuing, you agree to our Terms of Service & Privacy Policy',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall(color: AppColors.textSecondary.withValues(alpha: 0.7)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Email Login View ────────────────────────────────
  Widget _buildEmailLogin(Color primaryColor) {
    final isWorker = widget.selectedRole == PortalMode.worker;
    return SingleChildScrollView(
      key: const ValueKey('email_login'),
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24.0),
          Text(
            _isSignUp ? 'Create Account' : 'Sign in with Email',
            style: AppTextStyles.heading2(color: AppColors.textPrimary).copyWith(
              fontSize: 26.0,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            _isSignUp
                ? 'Join Jugaad to explore premium services'
                : 'Enter your credentials to continue',
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 36.0),

          // Name Input Field (Only for Sign Up)
          if (_isSignUp) ...[
            Text('Full Name', style: AppTextStyles.bodyMedium(color: AppColors.textPrimary, weight: FontWeight.bold)),
            const SizedBox(height: 8.0),
            TextField(
              controller: _nameController,
              keyboardType: TextInputType.name,
              style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'John Doe',
                prefixIcon: const Icon(Icons.person_outline, color: AppColors.textSecondary, size: 20),
                filled: true,
                fillColor: AppColors.surface,
                errorText: _nameError,
                errorStyle: AppTextStyles.bodySmall(color: AppColors.danger),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08), width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide(color: primaryColor, width: 2.0),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: const BorderSide(color: AppColors.danger, width: 1.0),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: const BorderSide(color: AppColors.danger, width: 2.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              ),
            ),
            const SizedBox(height: 20.0),
          ],

          // Email Input Field
          Text('Email Address', style: AppTextStyles.bodyMedium(color: AppColors.textPrimary, weight: FontWeight.bold)),
          const SizedBox(height: 8.0),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'name@example.com',
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textSecondary, size: 20),
              filled: true,
              fillColor: AppColors.surface,
              errorText: _emailError,
              errorStyle: AppTextStyles.bodySmall(color: AppColors.danger),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.0),
                borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.0),
                borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08), width: 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.0),
                borderSide: BorderSide(color: primaryColor, width: 2.0),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.0),
                borderSide: const BorderSide(color: AppColors.danger, width: 1.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.0),
                borderSide: const BorderSide(color: AppColors.danger, width: 2.0),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            ),
          ),
          const SizedBox(height: 20.0),

          // Password Input Field
          Text('Password', style: AppTextStyles.bodyMedium(color: AppColors.textPrimary, weight: FontWeight.bold)),
          const SizedBox(height: 8.0),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textSecondary, size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: AppColors.surface,
              errorText: _passwordError,
              errorStyle: AppTextStyles.bodySmall(color: AppColors.danger),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.0),
                borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.0),
                borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08), width: 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.0),
                borderSide: BorderSide(color: primaryColor, width: 2.0),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.0),
                borderSide: const BorderSide(color: AppColors.danger, width: 1.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.0),
                borderSide: const BorderSide(color: AppColors.danger, width: 2.0),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            ),
          ),

          // Forgot Password link
          if (!_isSignUp)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _forgotPassword,
                child: Text(
                  'Forgot password?',
                  style: AppTextStyles.bodyMedium(color: primaryColor, weight: FontWeight.bold),
                ),
              ),
            ),
            
          const SizedBox(height: 24.0),

          // Submit Button
          JugaadButton(
            text: _isSignUp ? 'Create Account' : 'Sign In',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _submitEmail,
            type: isWorker ? JugaadButtonType.success : JugaadButtonType.primary,
          ),
          
          const SizedBox(height: 24.0),

          // Toggle Sign-In / Sign-Up
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _isSignUp = !_isSignUp;
                  _nameError = null;
                  _emailError = null;
                  _passwordError = null;
                });
              },
              child: RichText(
                text: TextSpan(
                  style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
                  children: [
                    TextSpan(
                      text: _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                    ),
                    TextSpan(
                      text: _isSignUp ? 'Sign In' : 'Sign Up',
                      style: AppTextStyles.bodyMedium(color: primaryColor, weight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40.0),
        ],
      ),
    );
  }
}
