import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart' as pkg_provider;

import '../../../core/config/supabase_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/portal_mode.dart';

/// Next-Gen Jugaad Authentication Screen
/// Perfectly matches the modern light-theme mockup design with:
/// - Top Navigation with Back button, JUGAAD brand lockup & Location pill
/// - Center Card with Google & Email Sign-In, and full Email/Password flow
/// - Surrounding Floating Category Badges (Home Repairs, Electrical, Plumbing, Cleaning)
/// - Bottom 3-Column Trust Bar (Verified Professionals, Secure Payments, Local Service Network)
/// - Robust backend authentication and routing for both Customer and Partner roles
class LoginScreen extends StatefulWidget {
  final PortalMode selectedRole;

  const LoginScreen({super.key, required this.selectedRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  bool _isGoogleLoading = false;
  bool _isEmailLoading = false;
  bool _isEmailMode = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  // Selected city pill
  String _selectedCity = 'Mysuru';

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

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTHENTICATION LOGIC (FRONTEND & BACKEND)
  // ═══════════════════════════════════════════════════════════════════════════

  // ─── Sign In with Google ───────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    HapticFeedback.lightImpact();
    setState(() => _isGoogleLoading = true);

    final container = ProviderScope.containerOf(context);
    container.read(authProvider.notifier).suppressAutoFetch();

    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential == null || userCredential.user == null) {
        container.read(authProvider.notifier).unsuppressAutoFetch();
        if (mounted) setState(() => _isGoogleLoading = false);
        return;
      }
      if (!mounted) return;
      await _handleRouting(userCredential.user!.uid);
    } on PlatformException catch (e) {
      if (!mounted) return;
      container.read(authProvider.notifier).unsuppressAutoFetch();
      setState(() => _isGoogleLoading = false);
      if (e.code == 'sign_in_cancelled') return;
      _showToast(e.code == 'sign_in_failed'
          ? 'Sign-in failed. Please verify configuration.'
          : 'Sign-in failed: ${e.message ?? e.code}');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      container.read(authProvider.notifier).unsuppressAutoFetch();
      setState(() => _isGoogleLoading = false);
      if (e.code == 'account-exists-with-different-credential') {
        _showToast('An account already exists with this email. Please sign in with email/password.');
      } else {
        _showToast(e.message ?? 'Authentication failed');
      }
    } catch (e) {
      if (!mounted) return;
      container.read(authProvider.notifier).unsuppressAutoFetch();
      setState(() => _isGoogleLoading = false);
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

    setState(() => _isEmailLoading = true);

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
      setState(() => _isEmailLoading = false);
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
          backgroundColor: const Color(0xFF0D7844),
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
        } else {
          // Direct fallback upsert to ensure user row always exists in Supabase
          final currentUser = FirebaseAuth.instance.currentUser;
          try {
            await client.from('users').upsert({
              'id': uid,
              'firebase_uid': uid,
              'email': currentUser?.email,
              'name': currentUser?.displayName ?? '',
              'role': 'employer',
            });
            debugPrint('[ROUTING] Direct fallback user row ensured in Supabase');
          } catch (upsertErr) {
            debugPrint('[ROUTING] Direct upsert fallback (non-fatal): $upsertErr');
          }
        }
      }
    } catch (e) {
      debugPrint('[ROUTING] _handleRouting query error: $e');
    }

    if (!mounted) return;

    final container = ProviderScope.containerOf(context);
    final authNotifier = container.read(authProvider.notifier);

    // If worker is new, don't prematurely set 'worker' role until registration completes
    final roleToSet = selectedRole == PortalMode.worker
        ? (isFirstTime ? null : 'worker')
        : 'user';
    if (roleToSet != null) {
      authNotifier.setRole(roleToSet);
    }
    authNotifier.unsuppressAutoFetch();

    setState(() {
      _isGoogleLoading = false;
      _isEmailLoading = false;
    });

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
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showLegalModal(String title, String content) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                color: const Color(0xFF475569),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D7844),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  'Understood',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCitySelector() {
    HapticFeedback.lightImpact();
    final cities = ['Mysuru', 'Bengaluru', 'Mangaluru', 'Hubballi', 'Shivamogga'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Service Location',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            ...cities.map(
              (city) => ListTile(
                leading: Icon(
                  Icons.location_on_rounded,
                  color: city == _selectedCity ? const Color(0xFF0D7844) : const Color(0xFF94A3B8),
                ),
                title: Text(
                  city,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: city == _selectedCity ? FontWeight.w700 : FontWeight.w500,
                    color: city == _selectedCity ? const Color(0xFF0D7844) : const Color(0xFF0F172A),
                  ),
                ),
                trailing: city == _selectedCity
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF0D7844))
                    : null,
                onTap: () {
                  setState(() => _selectedCity = city);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MAIN BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isWorker = widget.selectedRole == PortalMode.worker;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF7), // Warm soft cream canvas
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 940;

            return Stack(
              children: [
                // ── Decorative Soft Organic Background Shapes ──────────────
                Positioned(
                  top: -80,
                  left: -100,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE8F5E9).withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -100,
                  right: -80,
                  child: Container(
                    width: 360,
                    height: 360,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFF3E0).withValues(alpha: 0.5),
                    ),
                  ),
                ),

                // ── Foreground Scrollable Content ──────────────────────────
                Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1140),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 1. Top Navigation Bar
                          _buildTopNavigationBar(context),

                          const SizedBox(height: 28.0),

                          // 2. Portal Access Pill
                          _buildPlatformAccessBadge(isWorker),

                          const SizedBox(height: 14.0),

                          // 3. Welcome Headline
                          _buildHeadline(isWorker),

                          const SizedBox(height: 10.0),

                          // 4. Subtitle
                          _buildSubtitle(isWorker),

                          const SizedBox(height: 36.0),

                          // 5. Center Section: Floating Categories + Central Card
                          if (isWide)
                            _buildWideCenterLayout(isWorker)
                          else
                            _buildMobileCenterLayout(isWorker),

                          const SizedBox(height: 48.0),

                          // 6. Bottom 3-Column Trust Bar
                          _buildBottomTrustBar(isWide),

                          const SizedBox(height: 20.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TOP NAVIGATION BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTopNavigationBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Rounded Back Button
        _buildBackButton(context),

        // JUGAAD Brand Identity & Tagline
        _buildBrandIdentity(),

        // Location Pill Selector
        _buildLocationPill(),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildBackButton(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.0),
          onTap: () {
            HapticFeedback.lightImpact();
            if (_isEmailMode) {
              setState(() => _isEmailMode = false);
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/auth/role');
            }
          },
          child: const Center(
            child: Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF0F172A),
              size: 20.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandIdentity() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Map pin emblem
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF0D7844),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8.0),
            RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
                children: const [
                  TextSpan(text: 'JUG', style: TextStyle(color: Color(0xFF0D7844))),
                  TextSpan(text: 'AAD', style: TextStyle(color: Color(0xFFF25C05))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2.0),
        Text(
          'Local Help. Anytime.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationPill() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(20.0),
        onTap: _showCitySelector,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF0F172A)),
              const SizedBox(width: 6),
              Text(
                _selectedCity,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HERO HEADLINE & BADGES
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPlatformAccessBadge(bool isWorker) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // soft blue pill
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isWorker ? 'PARTNER ACCESS' : 'CUSTOMER ACCESS',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: const Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 80.ms, duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildHeadline(bool isWorker) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.plusJakartaSans(
          fontSize: 34.0,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: const Color(0xFF0F172A),
        ),
        children: [
          TextSpan(text: isWorker ? 'Welcome Partner to ' : 'Welcome to '),
          const TextSpan(
            text: 'Jug',
            style: TextStyle(color: Color(0xFF0D7844)),
          ),
          const TextSpan(
            text: 'aad',
            style: TextStyle(color: Color(0xFFF25C05)),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 130.ms, duration: 350.ms).slideY(begin: 0.15, end: 0.0);
  }

  Widget _buildSubtitle(bool isWorker) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Text(
        isWorker
            ? 'Sign in to access your local dispatch requests, active customer missions, and instant payouts.'
            : 'Sign in to book trusted local professionals for fast, dependable home and office services.',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF64748B),
          height: 1.5,
        ),
      ),
    ).animate().fadeIn(delay: 180.ms, duration: 350.ms).slideY(begin: 0.15, end: 0.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESKTOP WIDE CENTER LAYOUT (With Floating Badges on sides)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWideCenterLayout(bool isWorker) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Column of Badges
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFloatingBadge(
              icon: Icons.handyman_rounded,
              iconColor: const Color(0xFF16A34A),
              iconBgColor: const Color(0xFFDCFCE7),
              title: 'Home\nRepairs',
            ),
            const SizedBox(height: 52),
            _buildFloatingBadge(
              icon: Icons.bolt_rounded,
              iconColor: const Color(0xFFD97706),
              iconBgColor: const Color(0xFFFEF3C7),
              title: 'Electrical',
            ),
          ],
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideX(begin: -0.1, end: 0),

        const SizedBox(width: 48),

        // Center Sculpted Card with Corner Spark Accents
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Top Left Sparks
            Positioned(
              top: -12,
              left: -12,
              child: _buildSparkAccents(isLeft: true),
            ),

            // Top Right Sparks
            Positioned(
              top: -12,
              right: -12,
              child: _buildSparkAccents(isLeft: false),
            ),

            // Main Card
            Container(
              width: 480,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _isEmailMode
                    ? _buildEmailForm(isWorker)
                    : _buildQuickAuthView(isWorker),
              ),
            ),
          ],
        ).animate().fadeIn(delay: 240.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),

        const SizedBox(width: 48),

        // Right Column of Badges
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFloatingBadge(
              icon: Icons.water_drop_rounded,
              iconColor: const Color(0xFF2563EB),
              iconBgColor: const Color(0xFFDBEAFE),
              title: 'Plumbing',
            ),
            const SizedBox(height: 52),
            _buildFloatingBadge(
              icon: Icons.cleaning_services_rounded,
              iconColor: const Color(0xFFEA580C),
              iconBgColor: const Color(0xFFFFEDD5),
              title: 'Cleaning',
            ),
          ],
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideX(begin: 0.1, end: 0),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE CENTER LAYOUT (Adaptive & Responsive)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileCenterLayout(bool isWorker) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top Mini Badge Row for mobile
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCompactBadge(Icons.handyman_rounded, const Color(0xFF16A34A), const Color(0xFFDCFCE7), 'Home Repairs'),
              const SizedBox(width: 10),
              _buildCompactBadge(Icons.bolt_rounded, const Color(0xFFD97706), const Color(0xFFFEF3C7), 'Electrical'),
              const SizedBox(width: 10),
              _buildCompactBadge(Icons.water_drop_rounded, const Color(0xFF2563EB), const Color(0xFFDBEAFE), 'Plumbing'),
              const SizedBox(width: 10),
              _buildCompactBadge(Icons.cleaning_services_rounded, const Color(0xFFEA580C), const Color(0xFFFFEDD5), 'Cleaning'),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Main Card
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _isEmailMode
                ? _buildEmailForm(isWorker)
                : _buildQuickAuthView(isWorker),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FLOATING FEATURE BADGES & ORNAMENTS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFloatingBadge({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
  }) {
    final cleanTitle = title.replaceAll('\n', ' ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: () {
          HapticFeedback.lightImpact();
          _showToast('$cleanTitle services ready in $_selectedCity');
        },
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 22),
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactBadge(IconData icon, Color iconColor, Color iconBgColor, String title) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.lightImpact();
          _showToast('$title services ready in $_selectedCity');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSparkAccents({required bool isLeft}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: isLeft ? -0.4 : 0.4,
          child: Container(
            width: 3.5,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFF25C05),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Transform.rotate(
          angle: isLeft ? -0.2 : 0.2,
          child: Container(
            width: 3.5,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFF0D7844),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW: QUICK SOCIAL & EMAIL SELECTOR (Matching Mockup Exactly)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildQuickAuthView(bool isWorker) {
    return Column(
      key: const ValueKey('quick_auth_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 1. Continue with Google Button ─────────────────────────────────
        SizedBox(
          height: 52.0,
          child: OutlinedButton(
            onPressed: (_isGoogleLoading || _isEmailLoading) ? null : _signInWithGoogle,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
              backgroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
            ),
            child: _isGoogleLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D7844)),
                    ),
                  )
                : Row(
                    children: [
                      // Multi-color Google 'G'
                      const _GoogleGLogo(),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Text(
                          'Continue with Google',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF334155),
                        size: 20.0,
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 18.0),

        // ── 2. Minimal OR Divider ──────────────────────────────────────────
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0xFFE2E8F0), height: 1.0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Text(
                'OR',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF94A3B8),
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Expanded(child: Divider(color: Color(0xFFE2E8F0), height: 1.0)),
          ],
        ),

        const SizedBox(height: 18.0),

        // ── 3. Continue with Email Button (Solid Forest Green) ─────────────
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
              backgroundColor: const Color(0xFF0D7844), // Vibrant Forest Green
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
            ),
            child: Row(
              children: [
                const Icon(Icons.mail_rounded, color: Colors.white, size: 20.0),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    'Continue with Email',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 20.0,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 22.0),

        // ── 4. Terms of Service & Privacy Policy ───────────────────────────
        Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: const Color(0xFF64748B),
                height: 1.45,
              ),
              children: [
                const TextSpan(text: 'By continuing, you agree to Jugaad\'s '),
                TextSpan(
                  text: 'Terms of Service',
                  style: const TextStyle(
                    color: Color(0xFF0D7844),
                    fontWeight: FontWeight.w700,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _showLegalModal(
                          'Terms of Service',
                          'By accessing Jugaad, you agree to comply with our fair marketplace policies, safety guidelines, and user standards for high quality home services.',
                        ),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: const TextStyle(
                    color: Color(0xFF0D7844),
                    fontWeight: FontWeight.w700,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _showLegalModal(
                          'Privacy Policy',
                          'Your privacy is rigorously protected. We encrypt user credentials and contact information, ensuring secure matching without unsolicited tracking.',
                        ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20.0,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: const Color(0xFF0F172A),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _isEmailMode = false),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_rounded, size: 14, color: Color(0xFF0D7844)),
                    const SizedBox(width: 4),
                    Text(
                      'Options',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D7844),
                      ),
                    ),
                  ],
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
            color: const Color(0xFF64748B),
          ),
        ),

        const SizedBox(height: 20.0),

        // Full Name (Only on Sign Up)
        if (_isSignUp) ...[
          _buildFieldLabel('Full Name'),
          const SizedBox(height: 6.0),
          TextField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            style: GoogleFonts.plusJakartaSans(fontSize: 14.0, color: const Color(0xFF0F172A)),
            decoration: _minimalInputDecoration('Your full name', _nameError),
          ),
          const SizedBox(height: 14.0),
        ],

        // Email Address
        _buildFieldLabel('Email Address'),
        const SizedBox(height: 6.0),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.plusJakartaSans(fontSize: 14.0, color: const Color(0xFF0F172A)),
          decoration: _minimalInputDecoration('name@example.com', _emailError),
        ),

        const SizedBox(height: 14.0),

        // Password
        _buildFieldLabel('Password'),
        const SizedBox(height: 6.0),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: GoogleFonts.plusJakartaSans(fontSize: 14.0, color: const Color(0xFF0F172A)),
          decoration: _minimalInputDecoration(
            '••••••••',
            _passwordError,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF94A3B8),
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
                  color: const Color(0xFF0D7844),
                  fontWeight: FontWeight.w700,
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
            onPressed: _isEmailLoading ? null : _submitEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D7844),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
              elevation: 0,
            ),
            child: _isEmailLoading
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
                      fontWeight: FontWeight.w700,
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
                  color: const Color(0xFF64748B),
                ),
                children: [
                  TextSpan(
                    text: _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                  ),
                  TextSpan(
                    text: _isSignUp ? 'Sign In' : 'Sign Up',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0D7844),
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
        color: const Color(0xFF0F172A),
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
    );
  }

  InputDecoration _minimalInputDecoration(String hint, String? error, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 13.5),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      errorText: error,
      errorStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFFDC2626), fontSize: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Color(0xFF0D7844), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.0),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM 3-COLUMN TRUST BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBottomTrustBar(bool isWide) {
    if (isWide) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildTrustItem(
              icon: Icons.shield_rounded,
              iconColor: const Color(0xFF16A34A),
              bgColor: const Color(0xFFDCFCE7),
              title: 'Verified Professionals',
              subtitle: 'Trusted and rated by people near you',
            ),
            Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
            _buildTrustItem(
              icon: Icons.credit_card_rounded,
              iconColor: const Color(0xFFEA580C),
              bgColor: const Color(0xFFFFEDD5),
              title: 'Secure Payments',
              subtitle: 'Multiple payment options',
            ),
            Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
            _buildTrustItem(
              icon: Icons.location_on_rounded,
              iconColor: const Color(0xFF16A34A),
              bgColor: const Color(0xFFDCFCE7),
              title: 'Local Service Network',
              subtitle: 'Trusted professionals near you',
            ),
          ],
        ),
      );
    } else {
      return Column(
        children: [
          _buildTrustItem(
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFF16A34A),
            bgColor: const Color(0xFFDCFCE7),
            title: 'Verified Professionals',
            subtitle: 'Trusted and rated by people near you',
          ),
          const SizedBox(height: 16),
          _buildTrustItem(
            icon: Icons.credit_card_rounded,
            iconColor: const Color(0xFFEA580C),
            bgColor: const Color(0xFFFFEDD5),
            title: 'Secure Payments',
            subtitle: 'Multiple payment options',
          ),
          const SizedBox(height: 16),
          _buildTrustItem(
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFF16A34A),
            bgColor: const Color(0xFFDCFCE7),
            title: 'Local Service Network',
            subtitle: 'Trusted professionals near you',
          ),
        ],
      );
    }
  }

  Widget _buildTrustItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.lightImpact();
          _showToast('$title: $subtitle');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PIXEL-PERFECT MULTI-COLOR GOOGLE 'G' LOGO
// ═════════════════════════════════════════════════════════════════════════════
class _GoogleGLogo extends StatelessWidget {
  const _GoogleGLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    final strokeWidth = w * 0.22;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // Blue arc (Right side)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.75, 1.5, false, paint);

    // Green arc (Bottom right)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.75, 1.4, false, paint);

    // Yellow arc (Bottom left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.15, 1.35, false, paint);

    // Red arc (Top left)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.5, 1.6, false, paint);

    // Blue horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.45, h * 0.39, w * 0.52, h * 0.22),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
