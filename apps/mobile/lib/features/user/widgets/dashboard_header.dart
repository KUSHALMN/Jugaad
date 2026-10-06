import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/user_location_provider.dart';

class DashboardHeader extends ConsumerWidget {
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

  void _showLocationSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final liveLocation = ref.watch(userLocationProvider);

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Service Location',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Live on-demand worker coverage across Karnataka',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // GPS Detect Button (High-profile Urban Company Style)
                GestureDetector(
                  onTap: liveLocation.isLoading
                      ? null
                      : () async {
                          HapticFeedback.mediumImpact();
                          await ref.read(userLocationProvider.notifier).detectCurrentLocation();
                          if (ctx.mounted) {
                            final err = ref.read(userLocationProvider).errorMessage;
                            if (err != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(err),
                                  backgroundColor: const Color(0xFFDC2626),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            } else {
                              Navigator.pop(ctx);
                            }
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        if (liveLocation.isLoading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Color(0xFF2563EB),
                            ),
                          )
                        else
                          const Icon(Icons.gps_fixed_rounded, color: Color(0xFF2563EB), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                liveLocation.isLoading ? 'Detecting your GPS location...' : 'Use Current Location (GPS)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E40AF),
                                ),
                              ),
                              Text(
                                liveLocation.isGpsDetected
                                    ? 'GPS Active: ${liveLocation.shortName}'
                                    : 'Tap to fetch precise doorstep address',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: const Color(0xFF3B82F6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF2563EB), size: 18),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                Text(
                  'OR SELECT CITY',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 8),

                // Mysuru City Option
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: liveLocation.city == 'Mysuru' ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                      width: liveLocation.city == 'Mysuru' ? 1.5 : 1.0,
                    ),
                  ),
                  tileColor: liveLocation.city == 'Mysuru' ? const Color(0xFFF0FDF4) : Colors.white,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFDCFCE7),
                    child: Icon(Icons.temple_hindu_rounded, color: Color(0xFF16A34A)),
                  ),
                  title: Row(
                    children: [
                      Text(
                        'Mysuru',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '⚡ 15-Min Live Hub',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Gokulam, Kuvempunagar, Jayalakshmipuram, Vijayanagar',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                  ),
                  trailing: liveLocation.city == 'Mysuru'
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22)
                      : const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(userLocationProvider.notifier).setManualLocation(
                          city: 'Mysuru',
                          locality: 'Gokulam',
                          latitude: 12.3051,
                          longitude: 76.6551,
                        );
                    Navigator.pop(ctx);
                  },
                ),

                const SizedBox(height: 10),

                // Bengaluru City Option
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: liveLocation.city == 'Bengaluru' ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                      width: liveLocation.city == 'Bengaluru' ? 1.5 : 1.0,
                    ),
                  ),
                  tileColor: liveLocation.city == 'Bengaluru' ? const Color(0xFFEFF6FF) : Colors.white,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(Icons.location_city_rounded, color: Color(0xFF2563EB)),
                  ),
                  title: Row(
                    children: [
                      Text(
                        'Bengaluru',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Metro Express',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Indiranagar, Koramangala, Whitefield, HSR Layout',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF64748B)),
                  ),
                  trailing: liveLocation.city == 'Bengaluru'
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 22)
                      : const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(userLocationProvider.notifier).setManualLocation(
                          city: 'Bengaluru',
                          locality: 'Indiranagar',
                          latitude: 12.9716,
                          longitude: 77.5946,
                        );
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greeting = _getDynamicGreeting();
    final userLocation = ref.watch(userLocationProvider);

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row: Location & live status pill
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _showLocationSheet(context, ref),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: userLocation.isGpsDetected ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                              width: 1.1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x06000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (userLocation.isLoading)
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: SizedBox(
                                    width: 11,
                                    height: 11,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  userLocation.isGpsDetected ? Icons.gps_fixed_rounded : Icons.location_on_rounded,
                                  color: const Color(0xFF2563EB),
                                  size: 14,
                                ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  userLocation.shortName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    color: const Color(0xFF0F172A),
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF64748B),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                color: Color(0xFFCBD5E1),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Online",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                color: const Color(0xFF16A34A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  greeting + (name.isNotEmpty ? name : 'Guest'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.6,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Notification Bell button
              GestureDetector(
                onTap: onNotificationTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 10,
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
                          color: Color(0xFF1E293B),
                          size: 21,
                        ),
                      ),
                    ),
                    if (notificationCount > 0)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33DC2626),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '$notificationCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // User Monogram Avatar
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.go('/user/profile');
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
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
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.5,
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
