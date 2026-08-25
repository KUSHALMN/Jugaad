import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as pkg_provider;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/portal_mode.dart';
import '../../../app.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late AnimationController _controller;

  // Keyframe Animations
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _taglineOpacity;
  late Animation<Offset> _taglineSlide;
  late Animation<double> _waveProgress;
  late Animation<double> _irisRadius;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    );

    // 1. Logo Pop In (0ms - 1375ms)
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.20, curve: Curves.easeOut),
      ),
    );

    // 2. Title "JUGAAD" Slide & Fade In (825ms - 2200ms)
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.35, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0.0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.40, curve: Curves.easeOutCubic),
      ),
    );

    // 3. Tagline "Your city. Your skills." (1650ms - 3025ms)
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.50, curve: Curves.easeOut),
      ),
    );
    _taglineSlide = Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    // 4. Bottom Wave Sweep (550ms - 3575ms)
    _waveProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.10, 0.65, curve: Curves.easeInOutCubic),
      ),
    );

    // 5. Iris Circular Reveal Page Transition (4840ms - 5500ms)
    _irisRadius = Tween<double>(begin: 0.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.88, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _executeNavigation();
      }
    });

    _controller.forward();
  }

  void _executeNavigation() async {
    AppRouter.hasSeenSplash = true;
    try {
      final user = _authService.currentUser;

      if (user != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final savedModeString = prefs.getString('portal_mode');

          if (!mounted) return;
          final modeProvider = pkg_provider.Provider.of<PortalModeProvider>(context, listen: false);

          if (savedModeString != null) {
            final savedMode = savedModeString == 'worker' ? PortalMode.worker : PortalMode.user;
            await modeProvider.setMode(savedMode);
            if (mounted) {
              context.go(savedMode == PortalMode.worker ? '/worker/home' : '/user/home');
            }
            return;
          }

          final role = await _authService.fetchUserRole(user.uid);
          if (role != null) {
            if (!mounted) return;
            if (role == 'worker') {
              await modeProvider.setMode(PortalMode.worker);
              if (mounted) context.go('/worker/home');
            } else {
              await modeProvider.setMode(PortalMode.user);
              if (mounted) context.go('/user/home');
            }
            return;
          }
        } catch (e) {
          debugPrint('[SPLASH] Navigation state check error: $e');
        }

        if (mounted) {
          final mode = pkg_provider.Provider.of<PortalModeProvider>(context, listen: false).mode;
          context.go(mode == PortalMode.worker ? '/worker/home' : '/user/home');
        }
      } else {
        if (mounted) {
          context.go('/auth/onboarding');
        }
      }
    } catch (e) {
      debugPrint('[SPLASH] Fallback navigation error: $e');
      if (mounted) {
        context.go('/auth/onboarding');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double maxRevealRadius = size.longestSide * 1.5;
    final double waveCenterHeight = size.height * 0.18 * 1.2375;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: Stack(
        children: [
          // 1. Center Brand Content
          SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo Box
                      Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Container(
                            width: 120.0,
                            height: 120.0,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26.0),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.18),
                                  blurRadius: 32,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(26.0),
                              child: Image.asset(
                                'assets/images/app_icon.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32.0),

                      // Brand Title "JUGAAD"
                      Opacity(
                        opacity: _titleOpacity.value,
                        child: SlideTransition(
                          position: _titleSlide,
                          child: const Text(
                            'JUGAAD',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 42.0,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B),
                              letterSpacing: 4.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12.0),

                      // Tagline "Your city. Your skills."
                      Opacity(
                        opacity: _taglineOpacity.value,
                        child: SlideTransition(
                          position: _taglineSlide,
                          child: Text(
                            'Your city. Your skills.',
                            style: AppTextStyles.bodyLarge(
                              color: const Color(0xFF64748B),
                              weight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // 2. Orange Wave Sweep across bottom
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _waveProgress,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _BottomWavePainter(_waveProgress.value),
                  );
                },
              ),
            ),
          ),

          // 3. Powered by VOWELS
          Positioned(
            bottom: waveCenterHeight + 24.0,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _taglineOpacity,
                builder: (context, child) {
                  return Opacity(
                    opacity: _taglineOpacity.value,
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 13.0,
                        ),
                        children: [
                          TextSpan(
                            text: 'Powered by ',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                          TextSpan(
                            text: 'VOWELS',
                            style: TextStyle(
                              color: Color(0xFFFF6B2C),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 4. Iris Circular Reveal page transition overlay
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _irisRadius,
                builder: (context, child) {
                  if (_irisRadius.value == 0.0) return const SizedBox.shrink();
                  return CustomPaint(
                    painter: _IrisRevealPainter(
                      radius: _irisRadius.value * maxRevealRadius,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomWavePainter extends CustomPainter {
  final double progress;
  _BottomWavePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0.0) return;

    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final path = Path();
    double currentHeight = size.height * 0.18 * progress;
    double startY = size.height - currentHeight;
    path.moveTo(0, size.height);
    path.lineTo(0, startY);

    double controlX = size.width * (0.2 + 0.6 * progress);
    double controlY = size.height - (currentHeight * 1.6);
    double endX = size.width;
    double endY = size.height - (currentHeight * 0.75);

    path.quadraticBezierTo(controlX, controlY, endX, endY);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BottomWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _IrisRevealPainter extends CustomPainter {
  final double radius;
  _IrisRevealPainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    if (radius == 0.0) return;

    final paint = Paint()
      ..color = const Color(0xFFF8F9FC)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _IrisRevealPainter oldDelegate) {
    return oldDelegate.radius != radius;
  }
}
