// lib/features/worker/screens/widgets/active_job_map_widgets.dart
// ═══════════════════════════════════════════════════════════════════
// Vector mini-map preview, pulse indicator, and launch navigation widget.
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jugaad_mvp/core/theme/worker_app_theme.dart';

class MockMiniMap extends StatelessWidget {
  final double height;
  final double radius;
  final double? userLat;
  final double? userLng;

  const MockMiniMap({
    super.key,
    this.height = 180.0,
    this.radius = 12.0,
    this.userLat,
    this.userLng,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: WorkerAppTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: MapVectorPainter(),
              ),
            ),
            const Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MapPulseRing(),
                  Icon(
                    Icons.location_on_rounded,
                    color: WorkerAppTheme.urgentRed,
                    size: 36,
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: () async {
                  if (userLat != null && userLng != null) {
                    final nativeUri = Uri.parse('google.navigation:q=$userLat,$userLng&mode=d');
                    final webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$userLat,$userLng&travelmode=driving');
                    if (await canLaunchUrl(nativeUri)) {
                      await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
                    } else if (await canLaunchUrl(webUri)) {
                      await launchUrl(webUri, mode: LaunchMode.externalApplication);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Customer location not available for navigation')),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.navigation_rounded,
                        color: WorkerAppTheme.primaryGreen,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Navigate →',
                        style: WorkerAppTheme.label(
                          color: WorkerAppTheme.primaryGreen,
                          size: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MapPulseRing extends StatefulWidget {
  const MapPulseRing({super.key});

  @override
  State<MapPulseRing> createState() => _MapPulseRingState();
}

class _MapPulseRingState extends State<MapPulseRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 50 * _pulseController.value,
          height: 50 * _pulseController.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: WorkerAppTheme.urgentRed.withValues(alpha: 1.0 - _pulseController.value),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

class MapVectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.5), paint);
    canvas.drawLine(Offset(size.width * 0.4, 0), Offset(size.width * 0.6, size.height), paint);
    canvas.drawLine(Offset(0, size.height * 0.8), Offset(size.width, size.height * 0.7), paint);

    final greenPaint = Paint()
      ..color = const Color(0xFFC8E6C9)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12, 12, size.width * 0.25, size.height * 0.25),
        const Radius.circular(8),
      ),
      greenPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.7, size.height * 0.6, size.width * 0.2, size.height * 0.35),
        const Radius.circular(8),
      ),
      greenPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
