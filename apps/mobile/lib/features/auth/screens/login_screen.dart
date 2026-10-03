import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as pkg_provider;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/portal_mode.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/config/supabase_config.dart';
import '../../../shared/widgets/jugaad_button.dart';

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
      if (msg.contains('cancelled')) return;
      _showErrorToast(msg);
    }
  }

  // ─── Email Sign-In / Sign-Up ─────────────────────────
  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

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
    final selectedRole = widget.selectedRole;
    pkg_provider.Provider.of<PortalModeProvider>(context, listen: false).setMode(selectedRole);

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
      debugPrint('[ROUTING] _handleRouting: Supabase query: $e');
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 960;
          if (isDesktop) {
            return _buildDesktopLayout(context, primaryColor);
          }
          return _buildMobileLayout(context, primaryColor);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT (2-Column SaaS Split Screen)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout(BuildContext context, Color primaryColor) {
    final isWorker = widget.selectedRole == PortalMode.worker;

    return Row(
      children: [
        // Left Column: Brand Hero & Social Proof
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isWorker
                    ? const [Color(0xFF042417), Color(0xFF063A25), Color(0xFF0D5E3E)]
                    : const [Color(0xFF060D1E), Color(0xFF0A1C3C), Color(0xFF0F2C61)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 56.0, vertical: 48.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Brand Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14.0),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Image.asset(
                        'assets/images/jugaad_logo.png',
                        width: 32,
                        height: 32,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.flash_on_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 14.0),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'JUGAAD',
                          style: AppTextStyles.heading3(color: Colors.white).copyWith(
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          isWorker ? 'SERVICE PARTNER PORTAL' : 'CUSTOMER DISCOVERY PORTAL',
                          style: AppTextStyles.labelCaps(color: Colors.white.withValues(alpha: 0.65)).copyWith(
                            fontSize: 10.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Spacer(),

                // Live pro indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(30.0),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        isWorker ? 'Instant Job Alerts Active in Mysuru' : '480+ Verified Pros Online Now',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24.0),

                Text(
                  isWorker
                      ? 'Empower Your Business.\nEarn On Your Own Terms.'
                      : 'The On-Demand Standard\nFor Quality Home Work.',
                  style: AppTextStyles.displayHero(fontSize: 38.0, color: Colors.white).copyWith(
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),

                const SizedBox(height: 16.0),

                Text(
                  isWorker
                      ? 'Join hundreds of electricians, plumbers, and technicians getting reliable daily jobs, zero commission during launch, and instant UPI payouts.'
                      : 'Experience upfront transparent pricing, 15-minute dispatch, and verified local professionals backed by ₹10,000 damage protection.',
                  style: AppTextStyles.bodyLarge(color: Colors.white.withValues(alpha: 0.75)).copyWith(
                    height: 1.5,
                    fontSize: 15.5,
                  ),
                ),

                const SizedBox(height: 36.0),

                // Metrics Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: isWorker
                        ? [
                            _buildStatItem('₹42,000', 'Avg. Monthly Pro Earn', Icons.trending_up_rounded),
                            Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.15)),
                            _buildStatItem('0%', 'Intro Commission', Icons.percent_rounded),
                            Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.15)),
                            _buildStatItem('Daily', 'Direct Payouts', Icons.flash_on_rounded),
                          ]
                        : [
                            _buildStatItem('15 min', 'Avg. Arrival', Icons.bolt_rounded),
                            Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.15)),
                            _buildStatItem('₹10,000', 'Protection Cover', Icons.shield_rounded),
                            Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.15)),
                            _buildStatItem('4.9 / 5', 'Pro Rating', Icons.star_rounded),
                          ],
                  ),
                ),

                const Spacer(),

                // Security Guarantee
                Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Bank-grade 256-bit encryption • Your data is always protected',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12.0),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Right Column: Auth Form Card
        Expanded(
          flex: 6,
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: 24,
                    left: 32,
                    child: _buildBackButton(context),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 40.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: _buildFormCard(context, primaryColor),
                      ),
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

  // ═══════════════════════════════════════════════════════════════════════
  // MOBILE / TABLET COMPACT LAYOUT
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout(BuildContext context, Color primaryColor) {
    final isWorker = widget.selectedRole == PortalMode.worker;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Top Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 28.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isWorker
                      ? const [Color(0xFF042417), Color(0xFF063A25), Color(0xFF16A34A)]
                      : const [Color(0xFF071329), Color(0xFF0E2856), Color(0xFF1A56DB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28.0),
                  bottomRight: Radius.circular(28.0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildBackButton(context, isDark: true),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Text(
                          isWorker ? 'WORKER PORTAL' : 'CUSTOMER PORTAL',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20.0),
                  Text(
                    isWorker ? 'Sign In as Partner' : 'Welcome to Jugaad',
                    style: AppTextStyles.heading1(color: Colors.white).copyWith(
                      fontSize: 26.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    isWorker
                        ? 'Access your jobs, earnings, and profile'
                        : 'Book verified skills and track services live',
                    style: AppTextStyles.bodyMedium(color: Colors.white.withValues(alpha: 0.85)).copyWith(
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),

            // Form Body Card
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: _buildFormCard(context, primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // AUTH FORM CARD
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildFormCard(BuildContext context, Color primaryColor) {
    final isWorker = widget.selectedRole == PortalMode.worker;

    return Container(
      padding: const EdgeInsets.all(28.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _isEmailMode
            ? _buildEmailForm(primaryColor, isWorker)
            : _buildMainAuthView(primaryColor, isWorker),
      ),
    );
  }

  Widget _buildMainAuthView(Color primaryColor, bool isWorker) {
    return Column(
      key: const ValueKey('main_auth_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Portal Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.5),
          decoration: BoxDecoration(
            color: isWorker
                ? const Color(0xFF16A34A).withValues(alpha: 0.08)
                : const Color(0xFF1A56DB).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Text(
            isWorker ? 'SERVICE PARTNER LOGIN' : 'SIGN IN TO CONTINUE',
            style: TextStyle(
              color: isWorker ? const Color(0xFF16A34A) : const Color(0xFF1A56DB),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),

        const SizedBox(height: 14.0),

        Text(
          isWorker ? 'Sign in to Partner Portal' : 'Sign in to Jugaad',
          style: AppTextStyles.heading2(color: const Color(0xFF0F172A)).copyWith(
            fontSize: 24.0,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6.0),
        Text(
          isWorker
              ? 'Receive live leads and manage earnings nearby'
              : 'Book top-rated verified experts in minutes',
          style: AppTextStyles.bodyMedium(color: const Color(0xFF64748B)),
        ),

        const SizedBox(height: 32.0),

        // Google Sign-In Button
        SizedBox(
          width: double.infinity,
          height: 52.0,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _signInWithGoogle,
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(primaryColor)),
                  )
                : const Icon(Icons.g_mobiledata, color: Color(0xFF4285F4), size: 28),
            label: Text(
              'Continue with Google',
              style: AppTextStyles.bodyLarge(color: const Color(0xFF0F172A), weight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
              backgroundColor: Colors.white,
              elevation: 0,
            ),
          ),
        ),

        const SizedBox(height: 20.0),

        // Divider
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0xFFE2E8F0), height: 1.0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'or continue with email',
                style: AppTextStyles.bodySmall(color: const Color(0xFF94A3B8), weight: FontWeight.w600),
              ),
            ),
            const Expanded(child: Divider(color: Color(0xFFE2E8F0), height: 1.0)),
          ],
        ),

        const SizedBox(height: 20.0),

        // Email Button
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
        ),

        const SizedBox(height: 28.0),

        // Terms Footer
        Center(
          child: Text(
            'By continuing, you agree to Jugaad\'s Terms of Service & Privacy Policy',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall(color: const Color(0xFF94A3B8)).copyWith(
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm(Color primaryColor, bool isWorker) {
    return Column(
      key: const ValueKey('email_form_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isSignUp ? 'Create Account' : 'Sign in with Email',
              style: AppTextStyles.heading2(color: const Color(0xFF0F172A)).copyWith(
                fontSize: 22.0,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _isEmailMode = false),
              child: const Text('Back'),
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        Text(
          _isSignUp
              ? 'Join Jugaad and unlock instant hyperlocal services'
              : 'Enter your credentials to access your dashboard',
          style: AppTextStyles.bodyMedium(color: const Color(0xFF64748B)),
        ),

        const SizedBox(height: 24.0),

        // Full Name Field (Sign Up only)
        if (_isSignUp) ...[
          _buildFieldLabel('Full Name'),
          const SizedBox(height: 6.0),
          TextField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
            decoration: _inputDecoration('John Doe', Icons.person_outline_rounded, _nameError, primaryColor),
          ),
          const SizedBox(height: 16.0),
        ],

        // Email Field
        _buildFieldLabel('Email Address'),
        const SizedBox(height: 6.0),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
          decoration: _inputDecoration('name@example.com', Icons.email_outlined, _emailError, primaryColor),
        ),

        const SizedBox(height: 16.0),

        // Password Field
        _buildFieldLabel('Password'),
        const SizedBox(height: 6.0),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
          decoration: _inputDecoration(
            '••••••••',
            Icons.lock_outline_rounded,
            _passwordError,
            primaryColor,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF64748B),
                size: 20,
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
              child: Text(
                'Forgot password?',
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13.0),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 20.0),
        ],

        // Submit Button
        JugaadButton(
          text: _isSignUp ? 'Create Account' : 'Sign In',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _submitEmail,
          type: isWorker ? JugaadButtonType.success : JugaadButtonType.primary,
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
                style: AppTextStyles.bodyMedium(color: const Color(0xFF64748B)),
                children: [
                  TextSpan(text: _isSignUp ? 'Already have an account? ' : "Don't have an account? "),
                  TextSpan(
                    text: _isSignUp ? 'Sign In' : 'Sign Up',
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
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
      style: const TextStyle(
        color: Color(0xFF1E293B),
        fontWeight: FontWeight.w700,
        fontSize: 13.5,
      ),
    );
  }

  InputDecoration _inputDecoration(
    String hint,
    IconData icon,
    String? error,
    Color primaryColor, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14.5),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      errorText: error,
      errorStyle: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: BorderSide(color: primaryColor, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16.0),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11.0),
        ),
      ],
    );
  }

  Widget _buildBackButton(BuildContext context, {bool isDark = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          size: 20.0,
        ),
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
