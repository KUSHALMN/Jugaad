import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardHeader extends StatelessWidget {
  final String name;
  final int notificationCount;
  final Animation<double> bellShakeAnimation;
  final VoidCallback onNotificationTap;

  const DashboardHeader({
    super.key,
    required this.name,
    required this.notificationCount,
    required this.bellShakeAnimation,
    required this.onNotificationTap,
  });

  String _getDynamicGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return "Good morning ";
    } else if (hour >= 12 && hour < 17) {
      return "Good afternoon ";
    } else if (hour >= 17 && hour < 22) {
      return "Good evening ";
    } else {
      return "Good night ";
    }
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _getDynamicGreeting();
    return Container(
      color: const Color(0xFFF8FAFF),
      padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 14.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting + (name.isNotEmpty ? name : 'Guest'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF1A56DB),
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      "Mysuru",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '● Workers online',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: const Color(0xFF15803D),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onNotificationTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 12,
                            offset: Offset(0, 3),
                          ),
                        ],
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                      ),
                      alignment: Alignment.center,
                      child: AnimatedBuilder(
                        animation: bellShakeAnimation,
                        builder: (context, child) {
                          final angle = sin(bellShakeAnimation.value * 3 * pi * 2) * 15 * pi / 180;
                          return Transform.rotate(
                            angle: angle,
                            child: child,
                          );
                        },
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          color: Color(0xFF0F172A),
                          size: 20,
                        ),
                      ),
                    ),
                    if (notificationCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4.0),
                          decoration: const BoxDecoration(
                            color: Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$notificationCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.go('/user/profile');
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF1A56DB), width: 1.5),
                  ),
                  padding: const EdgeInsets.all(1.5),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFEFF6FF),
                    child: Text(
                      name.trim().isEmpty || name == 'Loading...'
                          ? 'U'
                          : name
                              .trim()
                              .split(RegExp(r'\s+'))
                              .map((s) => s[0])
                              .take(2)
                              .join()
                              .toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF1A56DB),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
