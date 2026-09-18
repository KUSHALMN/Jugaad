import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/services_list.dart';
import '../screens/post_job/post_job_state.dart';

class EmergencyServiceConfig {
  final String id;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color accentColor;
  final Color bgTint;
  final IconData iconData;
  final String rating;
  final String jobsCount;

  const EmergencyServiceConfig({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.accentColor,
    required this.bgTint,
    required this.iconData,
    required this.rating,
    required this.jobsCount,
  });
}

class ServicesGrid extends ConsumerWidget {
  final List<ServiceDef> servicesList;
  final Map<String, int> counts;

  const ServicesGrid({
    super.key,
    required this.servicesList,
    required this.counts,
  });

  static const Map<String, EmergencyServiceConfig> _configMap = {
    'emergency_electrician': EmergencyServiceConfig(
      id: 'emergency_electrician',
      title: 'Emergency Electrician',
      subtitle: 'Arrives in ~30 mins',
      badgeText: 'Available Now',
      accentColor: Color(0xFFEA580C), // Orange
      bgTint: Color(0xFFFFF7ED),
      iconData: Icons.electrical_services_rounded,
      rating: '4.9',
      jobsCount: '1.2k',
    ),
    'emergency_plumbing': EmergencyServiceConfig(
      id: 'emergency_plumbing',
      title: 'Emergency Plumbing',
      subtitle: 'Arrives in ~25 mins',
      badgeText: 'Available Now',
      accentColor: Color(0xFF2563EB), // Blue
      bgTint: Color(0xFFEFF6FF),
      iconData: Icons.plumbing_rounded,
      rating: '4.8',
      jobsCount: '980',
    ),
    'water_leakage': EmergencyServiceConfig(
      id: 'water_leakage',
      title: 'Water Leakage',
      subtitle: 'Arrives in ~20 mins',
      badgeText: '24/7 Available',
      accentColor: Color(0xFF06B6D4), // Cyan
      bgTint: Color(0xFFECFEFF),
      iconData: Icons.water_damage_rounded,
      rating: '4.9',
      jobsCount: '1.5k',
    ),
    'power_outage': EmergencyServiceConfig(
      id: 'power_outage',
      title: 'Power Outage',
      subtitle: 'Arrives in ~30 mins',
      badgeText: 'Available Now',
      accentColor: Color(0xFF9333EA), // Purple
      bgTint: Color(0xFFF3E8FF),
      iconData: Icons.power_off_rounded,
      rating: '4.9',
      jobsCount: '850',
    ),
    'locked_out_of_home': EmergencyServiceConfig(
      id: 'locked_out_of_home',
      title: 'Locked Out Of Home',
      subtitle: 'Arrives in ~15 mins',
      badgeText: '24/7 Available',
      accentColor: Color(0xFF16A34A), // Green
      bgTint: Color(0xFFF0FDF4),
      iconData: Icons.vpn_key_rounded,
      rating: '4.9',
      jobsCount: '2.1k',
    ),
    'ac_breakdown': EmergencyServiceConfig(
      id: 'ac_breakdown',
      title: 'AC Repair & Service',
      subtitle: 'Arrives in ~30 mins',
      badgeText: 'Available Now',
      accentColor: Color(0xFF0284C7), // Sky Blue
      bgTint: Color(0xFFE0F2FE),
      iconData: Icons.ac_unit_rounded,
      rating: '4.8',
      jobsCount: '740',
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetIds = [
      'emergency_electrician',
      'emergency_plumbing',
      'water_leakage',
      'power_outage',
      'locked_out_of_home',
      'ac_breakdown',
    ];

    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount;
    final double childAspectRatio;

    if (screenWidth >= 1024) {
      crossAxisCount = 3;
      childAspectRatio = 1.45;
    } else if (screenWidth >= 600) {
      crossAxisCount = 2;
      childAspectRatio = 1.35;
    } else {
      // Mobile 2-column: perfect proportion (compact, rich, no dead white space)
      crossAxisCount = 2;
      childAspectRatio = 1.15;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: targetIds.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        final id = targetIds[index];
        final config = _configMap[id]!;
        final serviceDef = servicesList.firstWhere(
          (s) => s.id == id,
          orElse: () => ServiceDef(
            id: id,
            title: config.title,
            category: 'Emergency',
            icon: config.iconData,
            imageUrl: '',
            priceMin: 150,
            priceMax: 500,
            rating: 4.8,
          ),
        );

        final dynamicCount = counts[id] ?? counts[config.title.toLowerCase().replaceAll(' ', '_')];

        return _EmergencyServiceCard(
          config: config,
          dynamicCount: dynamicCount,
          onTap: () {
            HapticFeedback.mediumImpact();
            ref.read(postJobProvider.notifier).setSkill(serviceDef.title);
            ref.read(postJobProvider.notifier).setUrgency('now');
            ref.read(postJobProvider.notifier).setEmergency(true);
            ref.read(postJobProvider.notifier).setScheduledAt(null);
            context.push('/user/post-job/step2');
          },
        );
      },
    );
  }
}

class _EmergencyServiceCard extends StatefulWidget {
  final EmergencyServiceConfig config;
  final int? dynamicCount;
  final VoidCallback onTap;

  const _EmergencyServiceCard({
    required this.config,
    required this.onTap,
    this.dynamicCount,
  });

  @override
  State<_EmergencyServiceCard> createState() => _EmergencyServiceCardState();
}

class _EmergencyServiceCardState extends State<_EmergencyServiceCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final String displayBadgeText = (widget.dynamicCount != null && widget.dynamicCount! > 0)
        ? '${widget.dynamicCount} Available'
        : cfg.badgeText;

    final double scale = _isPressed ? 0.97 : (_isHovered ? 1.02 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isHovered
                    ? cfg.accentColor.withValues(alpha: 0.5)
                    : const Color(0xFFE2E8F0),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? cfg.accentColor.withValues(alpha: 0.12)
                      : const Color(0x060F172A),
                  blurRadius: _isHovered ? 16 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Bar: Icon + Availability Pill + Bookmark
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: cfg.bgTint,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cfg.accentColor.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            cfg.iconData,
                            color: cfg.accentColor,
                            size: 20,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: cfg.accentColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: cfg.accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                displayBadgeText,
                                style: GoogleFonts.plusJakartaSans(
                                  color: cfg.accentColor,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Middle: Title & Arrival info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cfg.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_filled_rounded,
                              size: 11,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                cfg.subtitle,
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Bottom Row: Rating + Quick Action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 2),
                            Text(
                              cfg.rating,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '(${cfg.jobsCount})',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: cfg.accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Book',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: cfg.accentColor,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 11,
                                color: cfg.accentColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
