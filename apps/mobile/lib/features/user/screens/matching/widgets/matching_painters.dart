// lib/features/user/screens/matching/widgets/matching_painters.dart
// ═══════════════════════════════════════════════════════════════════
// Custom painters & metadata resolvers for the matching flow.
// ═══════════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:jugaad_mvp/core/theme/user_app_theme.dart';

class ParticlePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0, use Interval(0.0, 0.6)
  final List<Color> colors = [
    UserAppTheme.skyAccent, UserAppTheme.primaryBlue,
    UserAppTheme.successGreen, UserAppTheme.skyAccent,
    UserAppTheme.primaryBlue, UserAppTheme.successGreen,
    UserAppTheme.skyAccent, UserAppTheme.primaryBlue,
  ];

  ParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45.0) * (pi / 180.0);
      final distance = progress * 100.0;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final x = center.dx + cos(angle) * distance;
      final y = center.dy + sin(angle) * distance;
      final paint = Paint()
        ..color = colors[i].withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 5.0 * (1 - progress * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => oldDelegate.progress != progress;
}

// ─────────────────────────────────────────────────────────────
// DYNAMIC CATEGORY METADATA RESOLVER
// ─────────────────────────────────────────────────────────────
class CategoryMetadata {
  final String title;
  final String serviceKey;
  final String imageUrl;

  const CategoryMetadata({
    required this.title,
    required this.serviceKey,
    required this.imageUrl,
  });

  /// Dynamically resolves category title, specialty display name, and preview image.
  factory CategoryMetadata.resolve({
    required String? rawCategory,
    String? customImageUrl,
    String? customTitle,
  }) {
    final raw = (rawCategory ?? '').trim().toLowerCase();

    // 1. Dynamic Title formatting:
    String resolvedTitle = customTitle?.trim() ?? '';
    if (resolvedTitle.isEmpty) {
      if (raw.contains('ro') || raw.contains('water') || raw.contains('purifier')) {
        resolvedTitle = 'Water Purifier Services';
      } else if (raw.contains('electric')) {
        resolvedTitle = 'Electrician & Power';
      } else if (raw.contains('plumb')) {
        resolvedTitle = 'Plumbing & Pipe Repair';
      } else if (raw.contains('ac') || raw.contains('air_cond') || raw.contains('cool')) {
        resolvedTitle = 'AC Service & Repair';
      } else if (raw.contains('carpent')) {
        resolvedTitle = 'Carpentry & Woodwork';
      } else if (raw.contains('clean')) {
        resolvedTitle = 'Deep Cleaning & Sanitization';
      } else if (raw.contains('paint')) {
        resolvedTitle = 'Painting & Waterproofing';
      } else if (raw.contains('pest')) {
        resolvedTitle = 'Pest Control Services';
      } else if (raw.contains('salon') || raw.contains('beauty') || raw.contains('hair')) {
        resolvedTitle = 'Salon & Grooming';
      } else if (raw.contains('appliance') || raw.contains('fridge') || raw.contains('washing')) {
        resolvedTitle = 'Appliance Repair';
      } else if (raw.contains('cctv') || raw.contains('security')) {
        resolvedTitle = 'CCTV & Security Systems';
      } else if (raw.contains('solar')) {
        resolvedTitle = 'Solar Installation & Service';
      } else if (raw.contains('mechanic') || raw.contains('vehicle') || raw.contains('bike') || raw.contains('car')) {
        resolvedTitle = 'Automobile Mechanic';
      } else if (raw.isNotEmpty) {
        resolvedTitle = raw
            .replaceAll(RegExp(r'[_\-]+'), ' ')
            .split(' ')
            .where((w) => w.isNotEmpty)
            .map((w) => w[0].toUpperCase() + w.substring(1))
            .join(' ');
      } else {
        resolvedTitle = 'Home & Technical Services';
      }
    }

    final resolvedServiceKey = '• $resolvedTitle Specialist';

    // 2. Dynamic Image Resolution
    if (customImageUrl != null && customImageUrl.trim().isNotEmpty && customImageUrl.startsWith('http')) {
      return CategoryMetadata(
        title: resolvedTitle,
        serviceKey: resolvedServiceKey,
        imageUrl: customImageUrl.trim(),
      );
    }

    String resolvedImage = 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=600&auto=format&fit=crop&q=80';

    if (raw.contains('ro') || raw.contains('water') || raw.contains('purifier')) {
      resolvedImage = 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=600&auto=format&fit=crop&q=80';
    } else if (raw.contains('electric')) {
      resolvedImage = 'https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=600&auto=format&fit=crop&q=80';
    } else if (raw.contains('plumb')) {
      resolvedImage = 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?w=600&auto=format&fit=crop&q=80';
    } else if (raw.contains('ac') || raw.contains('air_cond') || raw.contains('cool')) {
      resolvedImage = 'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?w=600&auto=format&fit=crop&q=80';
    } else if (raw.contains('carpent')) {
      resolvedImage = 'https://images.unsplash.com/photo-1530124566582-a618bc2615dc?w=600&auto=format&fit=crop&q=80';
    } else if (raw.contains('clean')) {
      resolvedImage = 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=600&auto=format&fit=crop&q=80';
    } else if (raw.contains('paint')) {
      resolvedImage = 'https://images.unsplash.com/photo-1589939705384-5185137a7f0f?w=600&auto=format&fit=crop&q=80';
    } else if (raw.contains('pest')) {
      resolvedImage = 'https://images.unsplash.com/photo-1584820927498-cfe5211fd8bf?w=600&auto=format&fit=crop&q=80';
    } else if (raw.contains('salon') || raw.contains('beauty') || raw.contains('hair')) {
      resolvedImage = 'https://images.unsplash.com/photo-1560066984-138dadb4c035?w=600&auto=format&fit=crop&q=80';
    } else if (raw.contains('appliance') || raw.contains('fridge') || raw.contains('washing')) {
      resolvedImage = 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=600&auto=format&fit=crop&q=80';
    } else if (raw.contains('cctv') || raw.contains('security')) {
      resolvedImage = 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=600&auto=format&fit=crop&q=80';
    } else if (raw.contains('solar')) {
      resolvedImage = 'https://images.unsplash.com/photo-1509391365360-2e959784a276?w=600&auto=format&fit=crop&q=80';
    } else if (raw.contains('mechanic') || raw.contains('vehicle') || raw.contains('bike') || raw.contains('car')) {
      resolvedImage = 'https://images.unsplash.com/photo-1486006920555-c77dce18193b?w=600&auto=format&fit=crop&q=80';
    }

    return CategoryMetadata(
      title: resolvedTitle,
      serviceKey: resolvedServiceKey,
      imageUrl: resolvedImage,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MINI LIVE MAP PREVIEW PAINTER
// ─────────────────────────────────────────────────────────────
class MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Soft map background
    final bgPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Road grid lines
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;

    final subRoadPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Subtle background sub-grid
    canvas.drawLine(Offset(0, size.height * 0.15), Offset(size.width, size.height * 0.15), subRoadPaint);
    canvas.drawLine(Offset(0, size.height * 0.52), Offset(size.width, size.height * 0.52), subRoadPaint);
    canvas.drawLine(Offset(0, size.height * 0.88), Offset(size.width, size.height * 0.88), subRoadPaint);

    // Main horizontal roads
    canvas.drawLine(Offset(0, size.height * 0.35), Offset(size.width, size.height * 0.35), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.70), Offset(size.width, size.height * 0.70), roadPaint);

    // Main vertical roads
    canvas.drawLine(Offset(size.width * 0.25, 0), Offset(size.width * 0.25, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.65, 0), Offset(size.width * 0.65, size.height), roadPaint);

    // Diagonal route line
    final routePaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.25, size.height * 0.35);
    path.quadraticBezierTo(
      size.width * 0.45,
      size.height * 0.50,
      size.width * 0.65,
      size.height * 0.70,
    );
    canvas.drawPath(path, routePaint);

    // Start point: Worker pulse circle
    final workerDot = Offset(size.width * 0.25, size.height * 0.35);
    canvas.drawCircle(
      workerDot,
      7,
      Paint()..color = const Color(0xFF3B82F6).withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      workerDot,
      4.5,
      Paint()..color = const Color(0xFF2563EB),
    );
    canvas.drawCircle(
      workerDot,
      2,
      Paint()..color = Colors.white,
    );

    // Destination point: Destination pin
    final destDot = Offset(size.width * 0.65, size.height * 0.70);
    canvas.drawCircle(
      destDot,
      6,
      Paint()..color = const Color(0xFF0F172A),
    );
    canvas.drawCircle(
      destDot,
      2.5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
