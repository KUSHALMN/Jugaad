// lib/features/user/screens/matching/widgets/pulsing_radar.dart
// ═══════════════════════════════════════════════════════════════════
// Animated radar with rotating sweep cone, concentric sonar rings,
// target detection blips, and service category icon.
// ═══════════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/material.dart';

class PulsingRadar extends StatefulWidget {
  final Color color;
  final String serviceType;

  const PulsingRadar({
    super.key,
    required this.color,
    required this.serviceType,
  });

  @override
  State<PulsingRadar> createState() => _PulsingRadarState();
}

class _PulsingRadarState extends State<PulsingRadar> with TickerProviderStateMixin {
  late AnimationController _sweepController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  IconData _getServiceIcon(String service) {
    final s = service.toLowerCase().replaceAll('_', ' ');
    if (s.contains('electrician') || s.contains('power outage') || s.contains('short circuit')) {
      return Icons.bolt_rounded;
    } else if (s.contains('plumber') || s.contains('plumbing') || s.contains('water') || s.contains('leakage') || s.contains('drain') || s.contains('toilet') || s.contains('pump')) {
      return Icons.plumbing_rounded;
    } else if (s.contains('laptop')) {
      return Icons.laptop_chromebook_rounded;
    } else if (s.contains('phone')) {
      return Icons.phone_android_rounded;
    } else if (s.contains('carpenter')) {
      return Icons.handyman_rounded;
    } else if (s.contains('painter')) {
      return Icons.format_paint_rounded;
    } else if (s.contains('ac ') || s.contains('air conditioning') || s.contains('ac_') || s.contains('ac breakdown')) {
      return Icons.ac_unit_rounded;
    } else if (s.contains('cleaning')) {
      return Icons.cleaning_services_rounded;
    } else if (s.contains('locked') || s.contains('key')) {
      return Icons.vpn_key_rounded;
    } else {
      return Icons.person_search_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 290,
      height: 290,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Radar sweep, distance rings & glowing worker blips
          AnimatedBuilder(
            animation: Listenable.merge([_sweepController, _pulseController]),
            builder: (context, child) {
              return CustomPaint(
                size: const Size(290, 290),
                painter: MatchingRadarPainter(
                  sweepAngle: _sweepController.value * 2 * pi,
                  pulseProgress: _pulseController.value,
                  radarColor: widget.color,
                ),
              );
            },
          ),

          // 2. Multi-tier concentric sonar pulse rings
          ...List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final double delay = i * 0.33;
                final double t = (_pulseController.value - delay) % 1.0;
                final double scale = 0.85 + (t * 1.6);
                final double opacity = (1.0 - t).clamp(0.0, 0.5);

                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.color.withValues(alpha: 0.7),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // 3. Central pulsing dish
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 0.96 + 0.08 * sin(_pulseController.value * 2 * pi);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    _getServiceIcon(widget.serviceType),
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class MatchingRadarPainter extends CustomPainter {
  final double sweepAngle;
  final double pulseProgress;
  final Color radarColor;

  MatchingRadarPainter({
    required this.sweepAngle,
    required this.pulseProgress,
    required this.radarColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 12;

    // 1. Range rings (1.5km, 3.0km, 5.0km simulation)
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final fraction in [0.32, 0.62, 0.95]) {
      canvas.drawCircle(center, maxRadius * fraction, ringPaint);
    }

    // 2. Axis lines
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), axisPaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), axisPaint);

    // 3. Sweep cone
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: pi / 2,
        colors: [
          radarColor.withValues(alpha: 0.0),
          radarColor.withValues(alpha: 0.38),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sweepAngle - (pi / 2));
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: maxRadius),
      0.0,
      pi / 2,
      true,
      sweepPaint,
    );

    // Sweep leading edge
    final leadPaint = Paint()
      ..color = radarColor.withValues(alpha: 0.85)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset.zero, Offset(maxRadius * cos(pi / 2), maxRadius * sin(pi / 2)), leadPaint);
    canvas.restore();

    // 4. Detected target blips
    final blipPositions = [
      Offset(center.dx + maxRadius * 0.55 * cos(1.1), center.dy + maxRadius * 0.55 * sin(1.1)),
      Offset(center.dx + maxRadius * 0.75 * cos(2.8), center.dy + maxRadius * 0.75 * sin(2.8)),
      Offset(center.dx + maxRadius * 0.40 * cos(4.4), center.dy + maxRadius * 0.40 * sin(4.4)),
      Offset(center.dx + maxRadius * 0.85 * cos(5.6), center.dy + maxRadius * 0.85 * sin(5.6)),
    ];

    for (int i = 0; i < blipPositions.length; i++) {
      final pos = blipPositions[i];
      final angleToBlip = atan2(pos.dy - center.dy, pos.dx - center.dx);
      double normalizedAngle = angleToBlip < 0 ? angleToBlip + 2 * pi : angleToBlip;
      double normalizedSweep = sweepAngle % (2 * pi);
      double diff = (normalizedSweep - normalizedAngle).abs();
      if (diff > pi) diff = 2 * pi - diff;

      final double intensity = (1.0 - (diff / (pi / 2))).clamp(0.25, 1.0);

      final glowPaint = Paint()
        ..color = (i % 2 == 0 ? Colors.cyanAccent : Colors.amberAccent).withValues(alpha: 0.45 * intensity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 9 * intensity, glowPaint);

      final dotPaint = Paint()
        ..color = (i % 2 == 0 ? Colors.cyanAccent : Colors.amberAccent).withValues(alpha: intensity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 4.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MatchingRadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle || oldDelegate.pulseProgress != pulseProgress;
  }
}
