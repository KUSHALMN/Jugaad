import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as pkg_provider;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/portal_mode.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/config/supabase_config.dart';

/// Minimalist, Apple & Urban Company-grade Sign-In Screen
/// Features Claude-style warm editorial serif typography (Newsreader),
/// a serene warm cream canvas, and tactile, high-craft input elements.
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
        pkg_provider.Provider.of<PortalModeProvider>(context, listen: false)
            .setMode(widget.selectedRole);
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

  // ─── Sign In with Google ───────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    final container = ProviderScope.containerOf(context);
    container.read(authProvider.notifier).suppressAutoFetch();

    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential == null || userCredential.user == null) {
        container.read(authProvider.notifier).unsuppressAutoFetch();
        setState(() => _isLoading = false);
        return;
      }
      if (!mounted) return;
      await _handleRouting(userCredential.user!.uid);
    } on PlatformException catch (e) {
      if (!mounted) return;
      container.read(authProvider.notifier).unsuppressAutoFetch();
      setState(() => _isLoading = false);
      if (e.code == 'sign_in_cancelled') return;
      _showToast(e.code == 'sign_in_failed'
          ? 'Sign-in failed. Please verify configuration.'
          : 'Sign-in failed: ${e.message ?? e.code}');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      container.read(authProvider.notifier).unsuppressAutoFetch();
      setState(() => _isLoading = false);
      if (e.code == 'account-exists-with-different-credential') {
        _showToast('An account already exists with this email. Please sign in with email/password.');
      } else {
        _showToast(e.message ?? 'Authentication failed');
      }
    } catch (e) {
      if (!mounted) return;
      container.read(authProvider.notifier).unsuppressAutoFetch();
      setState(() => _isLoading = false);
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('cancelled')) return;
      _showToast(msg);
    }
  }

  // ─── Email Sign-In / Sign-Up ───────────────────────────────────────
  Future<void> _submitEmail() async {
    HapticFeedback.lightImpact();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    setState(() {
      _nameError = null;
      _emailError = null;
      _passwordError = null;
    });

    if (_isSignUp && name.isEmpty) {
      setState(() => _nameError = 'Please enter your full name');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _emailError = 'Please enter a valid email address');
      return;
    }
    if (password.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);

    final container = ProviderScope.containerOf(context);
    container.read(authProvider.notifier).suppressAutoFetch();

    try {
      User user;
      if (_isSignUp) {
        user = await _authService.signUpWithEmail(
            email: email, password: password, name: name);
      } else {
        user = await _authService.signInWithEmail(
            email: email, password: password);
      }
      if (!mounted) return;
      await _handleRouting(user.uid);
    } catch (e) {
      if (!mounted) return;
      container.read(authProvider.notifier).unsuppressAutoFetch();
      setState(() => _isLoading = false);
      String msg = e.toString().replaceAll('Exception: ', '');
      _showToast(msg);
    }
  }

  // ─── Forgot Password ──────────────────────────────────────────────
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showToast('Enter your email address first to reset password');
      return;
    }

    try {
      await _authService.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Password reset link sent to $email',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString().replaceAll('Exception: ', '');
      _showToast(msg);
    }
  }

  // ─── Routing Handler ───────────────────────────────────────────────
  Future<void> _handleRouting(String uid) async {
    final selectedRole = widget.selectedRole;
    pkg_provider.Provider.of<PortalModeProvider>(context, listen: false)
        .setMode(selectedRole);

    bool isFirstTime = true;
    final client = SupabaseConfig.client;

    try {
      if (selectedRole == PortalMode.worker) {
        final workerDoc = await client
            .from('workers')
            .select()
            .eq('id', uid)
            .maybeSingle();
        if (workerDoc != null) {
          isFirstTime = false;
        }
      } else {
        final userDoc = await client
            .from('users')
            .select()
            .eq('id', uid)
            .maybeSingle();
        if (userDoc != null) {
          isFirstTime = false;
        }
      }
    } catch (e) {
      debugPrint('[ROUTING] _handleRouting query error: $e');
    }

    if (!mounted) return;

    final container = ProviderScope.containerOf(context);
    final authNotifier = container.read(authProvider.notifier);

    final roleToSet = selectedRole == PortalMode.worker ? 'worker' : 'user';
    authNotifier.setRole(roleToSet);
    authNotifier.unsuppressAutoFetch();

    setState(() => _isLoading = false);

    if (selectedRole == PortalMode.user) {
      context.go('/user/home');
    } else {
      if (isFirstTime) {
        context.go('/worker/register/step1');
      } else {
        context.go('/worker/home');
      }
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        backgroundColor: const Color(0xFF191817),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWorker = widget.selectedRole == PortalMode.worker;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6), // Warm Claude / Apple cream canvas
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Top Navigation & Brand Lockup ─────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildBackButton(context),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.asset(
                                'assets/images/app_icon.png',
                                width: 30,
                                height: 30,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.flash_on_rounded, color: Color(0xFF191817), size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            'JUGAAD',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                              color: const Color(0xFF191817),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 40),
                    ],
                  ).animate().fadeIn(duration: 300.ms),

                  const SizedBox(height: 40.0),

                  // ── Claude-Style Warm Editorial Headline ─────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
                    decoration: BoxDecoration(
                      color: isWorker ? const Color(0xFFECFDF5) : const Color(0xFFF0EEE6),
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(
                        color: isWorker ? const Color(0xFFA7F3D0) : const Color(0xFFE5E2D8),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      isWorker ? 'SERVICE PARTNER PORTAL' : 'CUSTOMER DISCOVERY',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: isWorker ? const Color(0xFF044E32) : const Color(0xFF5A5852),
                      ),
                    ),
                  ).animate().fadeIn(delay: 80.ms, duration: 350.ms).slideY(begin: 0.15, end: 0.0),

                  const SizedBox(height: 16.0),

                  Text(
                    isWorker ? 'Partner Access' : 'Welcome to Jugaad',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.newsreader(
                      fontSize: 38.0,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.8,
                      color: const Color(0xFF191817),
                      height: 1.15,
                    ),
                  ).animate().fadeIn(delay: 140.ms, duration: 350.ms).slideY(begin: 0.15, end: 0.0),

                  const SizedBox(height: 10.0),

                  Text(
                    isWorker
                        ? 'Sign in to access your local dispatch requests, active customer missions, and instant payouts.'
                        : 'Sign in to book certified local professionals for fast, dependable home and office care.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF716F68),
                      height: 1.5,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 350.ms).slideY(begin: 0.15, end: 0.0),

                  const SizedBox(height: 36.0),

                  // ── Centered Sculpted Auth Card ───────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24.0),
                      border: Border.all(color: const Color(0xFFE8E5DD), width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _isEmailMode
                          ? _buildEmailForm(isWorker)
                          : _buildQuickAuthView(isWorker),
                    ),
                  ).animate().fadeIn(delay: 260.ms, duration: 400.ms).slideY(begin: 0.1, end: 0.0),

                  const SizedBox(height: 28.0),

                  // ── Discreet Security & Trust Guarantee ───────────────────
                  Text(
                    'Protected by bank-grade 256-bit encryption. Your credentials remain private and secure.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF9E9B93),
                      height: 1.4,
                    ),
                  ).animate().fadeIn(delay: 340.ms, duration: 400.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW: QUICK SOCIAL & EMAIL SELECTOR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildQuickAuthView(bool isWorker) {
    return Column(
      key: const ValueKey('quick_auth_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Google Sign-In Button (Apple & Urban Company clean styling)
        SizedBox(
          height: 52.0,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _signInWithGoogle,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE5E2DA), width: 1.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
              backgroundColor: Colors.white,
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF191817)),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Google G icon badge
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: const Center(
                          child: Text(
                            'G',
                            style: TextStyle(
                              color: Color(0xFF4285F4),
                              fontWeight: FontWeight.w900,
                              fontSize: 15.0,
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Text(
                        'Continue with Google',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF191817),
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 20.0),

        // Minimal Divider
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0xFFECEAE3), height: 1.0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Text(
                'or with email',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF9E9B93),
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Expanded(child: Divider(color: Color(0xFFECEAE3), height: 1.0)),
          ],
        ),

        const SizedBox(height: 20.0),

        // Email Action Button (Obsidian Black or Deep Emerald)
        SizedBox(
          height: 52.0,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isEmailMode = true;
                _isSignUp = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isWorker ? const Color(0xFF044E32) : const Color(0xFF191817),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
              elevation: 0,
            ),
            child: Text(
              'Continue with Email',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
            ),
          ),
        ),

        const SizedBox(height: 22.0),

        // Terms Footer
        Text(
          'By continuing, you agree to Jugaad\'s Terms of Service and Privacy Policy.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            color: const Color(0xFF9E9B93),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW: EMAIL SIGN-IN / SIGN-UP FORM
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildEmailForm(bool isWorker) {
    return Column(
      key: const ValueKey('email_form_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Form Header with Back Navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isSignUp ? 'Create Account' : 'Sign in with Email',
              style: GoogleFonts.newsreader(
                fontSize: 22.0,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: const Color(0xFF191817),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _isEmailMode = false),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  '← Options',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF716F68),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 4.0),

        Text(
          _isSignUp
              ? 'Enter your name and credentials to create an account'
              : 'Enter your email address and password to sign in',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: const Color(0xFF716F68),
          ),
        ),

        const SizedBox(height: 22.0),

        // Full Name (Only on Sign Up)
        if (_isSignUp) ...[
          _buildFieldLabel('Full Name'),
          const SizedBox(height: 6.0),
          TextField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            style: GoogleFonts.plusJakartaSans(fontSize: 14.0, color: const Color(0xFF191817)),
            decoration: _minimalInputDecoration('Full Name', _nameError),
          ),
          const SizedBox(height: 14.0),
        ],

        // Email Address
        _buildFieldLabel('Email Address'),
        const SizedBox(height: 6.0),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.plusJakartaSans(fontSize: 14.0, color: const Color(0xFF191817)),
          decoration: _minimalInputDecoration('name@example.com', _emailError),
        ),

        const SizedBox(height: 14.0),

        // Password
        _buildFieldLabel('Password'),
        const SizedBox(height: 6.0),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: GoogleFonts.plusJakartaSans(fontSize: 14.0, color: const Color(0xFF191817)),
          decoration: _minimalInputDecoration(
            '••••••••',
            _passwordError,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF8C8980),
                size: 18,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),

        if (!_isSignUp) ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _forgotPassword,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                'Forgot password?',
                style: GoogleFonts.plusJakartaSans(
                  color: isWorker ? const Color(0xFF044E32) : const Color(0xFF191817),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.0,
                ),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 18.0),
        ],

        // Submit Button
        SizedBox(
          height: 52.0,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: isWorker ? const Color(0xFF044E32) : const Color(0xFF191817),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _isSignUp ? 'Create Account' : 'Sign In',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 16.0),

        // Toggle Sign In / Sign Up
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: const Color(0xFF716F68),
                ),
                children: [
                  TextSpan(
                    text: _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                  ),
                  TextSpan(
                    text: _isSignUp ? 'Sign In' : 'Sign Up',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: isWorker ? const Color(0xFF044E32) : const Color(0xFF191817),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        color: const Color(0xFF191817),
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
    );
  }

  InputDecoration _minimalInputDecoration(String hint, String? error, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFFA8A59E), fontSize: 13.5),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF9F8F5),
      errorText: error,
      errorStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFFDC2626), fontSize: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Color(0xFFE8E5DD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Color(0xFFE8E5DD), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Color(0xFF191817), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.0),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFE8E5DD), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: Color(0xFF191817),
          size: 18.0,
        ),
        padding: EdgeInsets.zero,
        onPressed: () {
          if (_isEmailMode) {
            setState(() => _isEmailMode = false);
          } else {
            context.go('/auth/role');
          }
        },
        tooltip: 'Back',
      ),
    );
  }
}
