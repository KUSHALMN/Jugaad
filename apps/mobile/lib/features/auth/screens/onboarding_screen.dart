import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/jugaad_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isFinalTransition = false;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'Quick Connections',
      description: 'Connect with hundreds of certified local service professionals in Mysuru instantly.',
      painter: (progress) => ConnectingNodesPainter(progress),
    ),
    OnboardingPageData(
      title: 'Secure Wallet & Earnings',
      description: 'Transparent pricing with hassle-free secure digital payments and automated payouts.',
      painter: (progress) => FallingCoinsPainter(progress),
    ),
    OnboardingPageData(
      title: 'Hyperlocal Presence',
      description: 'Real-time worker tracking right to your doorstep anywhere in the city.',
      painter: (progress) => LocationPinPainter(progress),
    ),
  ];

  void _onPageChanged(int index) {
    if (!kIsWeb) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }
    setState(() {
      _currentIndex = index;
    });
  }

  void _onNext() async {
    if (_currentIndex < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      // Liquid fill then navigate to role select!
      setState(() => _isFinalTransition = true);
      await Future.delayed(const Duration(milliseconds: 2100));
      if (mounted) {
        context.go('/auth/role');
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top branding
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'JUGAAD',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      fontSize: 20,
                    ),
                  ),
                  if (_currentIndex < _pages.length - 1)
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.go('/auth/role');
                      },
                      child: Text(
                        'Skip',
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.textSecondary,
                          weight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Sliding pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return OnboardingPageView(
                    data: _pages[index],
                    isActive: _currentIndex == index,
                  );
                },
              ),
            ),

            // Bottom controls
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page indicator pills (stretching active pill wide)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      final bool active = _currentIndex == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        height: 8.0,
                        width: active ? 24.0 : 8.0,
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : AppColors.kNeutralBorder,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32.0),

                  // Action Button with liquid fill loading wave
                  JugaadButton(
                    text: _currentIndex == _pages.length - 1 ? 'Get Started' : 'Next',
                    onPressed: _onNext,
                    isLoading: _isFinalTransition,
                    isLiquidLoading: true,
                    loadingText: 'Launching JUGAAD...',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPageData {
  final String title;
  final String description;
  final CustomPainter Function(double progress) painter;

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.painter,
  });
}

class OnboardingPageView extends StatefulWidget {
  final OnboardingPageData data;
  final bool isActive;

  const OnboardingPageView({
    super.key,
    required this.data,
    required this.isActive,
  });

  @override
  State<OnboardingPageView> createState() => _OnboardingPageViewState();
}

class _OnboardingPageViewState extends State<OnboardingPageView> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    if (widget.isActive) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(OnboardingPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive) {
      _animController.repeat(reverse: true);
    } else {
      _animController.stop();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Graphic Canvas Area
          Expanded(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return CustomPaint(
                  painter: widget.data.painter(_animController.value),
                  child: Container(),
                );
              },
            ),
          ),
          const SizedBox(height: 24.0),

          // Title
          Text(
            widget.data.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.heading1(color: AppColors.textPrimary).copyWith(
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 12.0),

          // Description
          Text(
            widget.data.description,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge(color: AppColors.textSecondary).copyWith(
              height: 1.5,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16.0),
        ],
      ),
    );
  }
}

// ─── CUSTOM PROCEDURAL VECTOR PAINTERS ───────────────────────────────────

// Screen 1: Nodes linking worker and user
class ConnectingNodesPainter extends CustomPainter {
  final double progress;
  ConnectingNodesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    
    // Draw connecting hub rings
    final paintRing = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.05 + 0.03 * sin(progress * pi * 2))
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(cx, cy), 120 + 10 * sin(progress * pi * 2), paintRing);
    canvas.drawCircle(Offset(cx, cy), 60 + 5 * cos(progress * pi * 2), paintRing);

    final Paint paintNode = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final Paint paintLine = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.25)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    // Define 5 procedurally floating nodes
    final List<Offset> nodes = [
      Offset(cx + 80 * cos(progress * pi * 2), cy + 40 * sin(progress * pi * 2)),
      Offset(cx - 90 * sin(progress * pi * 2), cy + 80 * cos(progress * pi * 2)),
      Offset(cx - 40 * cos(progress * pi * 2), cy - 90 * sin(progress * pi * 2)),
      Offset(cx + 100 * sin(progress * pi * 2), cy - 60 * cos(progress * pi * 2)),
      Offset(cx, cy), // central core hub
    ];

    // Draw connecting lines
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        canvas.drawLine(nodes[i], nodes[j], paintLine);
      }
    }

    // Draw the nodes
    for (int i = 0; i < nodes.length; i++) {
      canvas.drawCircle(nodes[i], i == 4 ? 12.0 : 8.0, paintNode);
      // Glow rings for nodes
      canvas.drawCircle(
        nodes[i],
        (i == 4 ? 20.0 : 14.0) + 4 * sin(progress * pi * 4 + i),
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ConnectingNodesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Screen 2: Money Coins falling into leather wallet
class FallingCoinsPainter extends CustomPainter {
  final double progress;
  FallingCoinsPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // 1. Draw Wallet Container at bottom center
    final walletPaint = Paint()
      ..color = const Color(0xFF5C3D2E) // leather brown
      ..style = PaintingStyle.fill;
    
    final RRect walletRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 60), width: 140, height: 75),
      const Radius.circular(16),
    );
    canvas.drawRRect(walletRRect, walletPaint);

    // Wallet buckle accent
    final bucklePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 40, cy + 60), width: 24, height: 16),
        const Radius.circular(4),
      ),
      bucklePaint,
    );

    // Wallet opening shadow
    final openingPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(cx - 60, cy + 25, 120, 8),
      openingPaint,
    );

    // 2. Draw 3 coins dropping down sequentially
    final coinPaint = Paint()
      ..color = AppColors.warning // golden
      ..style = PaintingStyle.fill;

    final coinBorderPaint = Paint()
      ..color = Colors.amber.shade700
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rupeeStyle = TextStyle(
      color: Colors.amber.shade900,
      fontSize: 12,
      fontWeight: FontWeight.w900,
    );

    // Cycle math
    for (int i = 0; i < 3; i++) {
      double coinOffset = (progress + i * 0.33) % 1.0;
      double coinY = cy - 100 + 130 * coinOffset;
      double coinX = cx - 15 + i * 15 + 10 * sin(coinOffset * pi * 4);
      double scale = coinOffset < 0.85 ? 1.0 : (1.0 - (coinOffset - 0.85) / 0.15); // fade in wallet

      if (scale > 0.0) {
        canvas.drawCircle(Offset(coinX, coinY), 16 * scale, coinPaint);
        canvas.drawCircle(Offset(coinX, coinY), 16 * scale, coinBorderPaint);

        // Draw ₹ text inside coin
        final textPainter = TextPainter(
          text: TextSpan(text: '₹', style: rupeeStyle.copyWith(fontSize: 13 * scale)),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(coinX - textPainter.width / 2, coinY - textPainter.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant FallingCoinsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Screen 3: Location pin drop on map
class LocationPinPainter extends CustomPainter {
  final double progress;
  LocationPinPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // 1. Draw grid / map lines in background
    final Paint mapPaint = Paint()
      ..color = AppColors.kNeutralBorder
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Horizontal grid lines
    canvas.drawLine(Offset(cx - 120, cy - 40), Offset(cx + 120, cy - 40), mapPaint);
    canvas.drawLine(Offset(cx - 140, cy + 20), Offset(cx + 140, cy + 20), mapPaint);
    canvas.drawLine(Offset(cx - 120, cy + 80), Offset(cx + 120, cy + 80), mapPaint);

    // Diagonal/vertical road sweep
    canvas.drawLine(Offset(cx - 80, cy - 80), Offset(cx - 40, cy + 100), mapPaint);
    canvas.drawLine(Offset(cx + 40, cy - 80), Offset(cx + 80, cy + 100), mapPaint);

    // 2. Draw ground target pulsing wave (expanding concentric orange rings)
    final double pulseScale = (progress * 2.0) % 1.0;
    final Paint pulsePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.25 * (1.0 - pulseScale))
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 50), width: 80 * pulseScale, height: 35 * pulseScale),
      pulsePaint,
    );

    // Core target shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 50), width: 35, height: 16),
      Paint()..color = Colors.black.withValues(alpha: 0.08)..style = PaintingStyle.fill,
    );

    // 3. Draw location pin dropping and bouncing
    // Physics-like elastic drop formula
    double bounceOffset = 40 * (1.0 - sin(progress * pi));
    double pinY = cy + 15 - bounceOffset;

    final pinPath = Path();
    pinPath.moveTo(cx, pinY + 35); // tip of pin pointing down
    
    // Top circle of pin
    pinPath.cubicTo(cx - 24, pinY + 10, cx - 24, pinY - 24, cx, pinY - 24);
    pinPath.cubicTo(cx + 24, pinY - 24, cx + 24, pinY + 10, cx, pinY + 35);
    pinPath.close();

    final Paint pinPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    // Draw drop shadow under pin
    canvas.drawPath(pinPath, pinPaint);

    // Pin center dot cutout
    final Paint innerDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, pinY + 2), 8.0, innerDotPaint);
  }

  @override
  bool shouldRepaint(covariant LocationPinPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
