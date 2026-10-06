import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/utils/jugaad_haptics.dart';

/// Reusable Micro-Celebration Widget with Confetti & Animated Green Checkmark
class CelebrationOverlay extends StatefulWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onDismiss;
  final Duration autoDismissDuration;
  final bool showDismissButton;

  const CelebrationOverlay({
    super.key,
    required this.title,
    this.subtitle = '',
    this.onDismiss,
    this.autoDismissDuration = const Duration(milliseconds: 2200),
    this.showDismissButton = false,
  });

  /// Static helper to trigger a full-screen celebration dialog
  static Future<void> show(
    BuildContext context, {
    required String title,
    String subtitle = '',
    Duration autoDismissDuration = const Duration(milliseconds: 2200),
    bool barrierDismissible = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => CelebrationOverlay(
        title: title,
        subtitle: subtitle,
        autoDismissDuration: autoDismissDuration,
        onDismiss: () {
          if (Navigator.of(ctx).canPop()) {
            Navigator.of(ctx).pop();
          }
        },
      ),
    );
  }

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _badgeAnimController;
  late AnimationController _checkAnimController;
  late AnimationController _pulseRingController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _checkProgress;
  late Animation<double> _pulseRingAnimation;

  @override
  void initState() {
    super.initState();

    // Confetti cannon (blasts for 1.2s)
    _confettiController = ConfettiController(duration: const Duration(milliseconds: 1400));

    // Badge spring scale
    _badgeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _badgeAnimController,
      curve: Curves.elasticOut,
    );

    // Checkmark draw stroke
    _checkAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _checkProgress = CurvedAnimation(
      parent: _checkAnimController,
      curve: Curves.easeInOutCubic,
    );

    // Ambient halo pulse ring
    _pulseRingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseRingAnimation = CurvedAnimation(
      parent: _pulseRingController,
      curve: Curves.easeOut,
    );

    // Sequence trigger
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _confettiController.play();
      _badgeAnimController.forward();
      _pulseRingController.forward();
      JugaadHaptics.success();

      // Delay checkmark draw slightly for visual rhythm
      await Future.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      _checkAnimController.forward();

      // Auto dismiss if configured
      if (widget.autoDismissDuration > Duration.zero) {
        await Future.delayed(widget.autoDismissDuration);
        if (mounted && widget.onDismiss != null) {
          widget.onDismiss!();
        }
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _badgeAnimController.dispose();
    _checkAnimController.dispose();
    _pulseRingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── CONFETTI CANNONS ──
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              blastDirection: pi / 2, // Downwards
              emissionFrequency: 0.08,
              numberOfParticles: 35,
              maxBlastForce: 25,
              minBlastForce: 10,
              gravity: 0.25,
              colors: const [
                Color(0xFF10B981), // Emerald
                Color(0xFF059669), // Forest Green
                Color(0xFFF59E0B), // Amber Gold
                Color(0xFF3B82F6), // Blue
                Color(0xFFEC4899), // Pink
                Color(0xFF8B5CF6), // Purple
              ],
            ),
          ),

          // ── CELEBRATION CARD ──
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 36,
                      offset: Offset(0, 16),
                    ),
                    BoxShadow(
                      color: Color(0x1A10B981),
                      blurRadius: 48,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── ANIMATED GREEN CHECKMARK WITH GLOWING HALO ──
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer expanding pulse halo
                        AnimatedBuilder(
                          animation: _pulseRingAnimation,
                          builder: (context, _) {
                            final val = _pulseRingAnimation.value;
                            return Container(
                              width: 88 + (val * 36),
                              height: 88 + (val * 36),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF10B981).withValues(alpha: (1.0 - val) * 0.35),
                              ),
                            );
                          },
                        ),

                        // Glowing emerald circle
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF059669), Color(0xFF10B981)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.45),
                                blurRadius: 24,
                                spreadRadius: 4,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _checkProgress,
                              builder: (context, _) {
                                return CustomPaint(
                                  size: const Size(42, 42),
                                  painter: _AnimatedCheckmarkPainter(progress: _checkProgress.value),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── TITLE ──
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),

                    // ── SUBTITLE ──
                    if (widget.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ],

                    if (widget.showDismissButton) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: widget.onDismiss,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Continue',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for silky smooth SVG-like stroke drawing checkmark
class _AnimatedCheckmarkPainter extends CustomPainter {
  final double progress;

  _AnimatedCheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // Checkmark coordinates normalized to size
    final start = Offset(size.width * 0.22, size.height * 0.52);
    final mid = Offset(size.width * 0.44, size.height * 0.74);
    final end = Offset(size.width * 0.80, size.height * 0.32);

    final totalFirstLeg = (mid - start).distance;
    final totalSecondLeg = (end - mid).distance;
    final totalDist = totalFirstLeg + totalSecondLeg;

    final currentDist = totalDist * progress;

    if (currentDist <= totalFirstLeg) {
      final t = currentDist / totalFirstLeg;
      final currentMid = Offset.lerp(start, mid, t)!;
      path.moveTo(start.dx, start.dy);
      path.lineTo(currentMid.dx, currentMid.dy);
    } else {
      path.moveTo(start.dx, start.dy);
      path.lineTo(mid.dx, mid.dy);

      final secondLegDist = currentDist - totalFirstLeg;
      final t = secondLegDist / totalSecondLeg;
      final currentEnd = Offset.lerp(mid, end, t)!;
      path.lineTo(currentEnd.dx, currentEnd.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AnimatedCheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
