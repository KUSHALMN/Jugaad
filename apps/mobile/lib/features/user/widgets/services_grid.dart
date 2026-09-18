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
  final String startingPrice;
  final String strikePrice;
  final String perk;

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
    required this.startingPrice,
    required this.strikePrice,
    required this.perk,
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
      startingPrice: '₹199',
      strikePrice: '₹299',
      perk: 'Zero inspection fee',
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
      startingPrice: '₹149',
      strikePrice: '₹249',
      perk: '30-day warranty',
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
      startingPrice: '₹199',
      strikePrice: '₹299',
      perk: 'Rapid pipe seal',
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
      startingPrice: '₹249',
      strikePrice: '₹349',
      perk: 'Safety check',
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
      startingPrice: '₹199',
      strikePrice: '₹299',
      perk: 'Safe unlock',
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
      startingPrice: '₹299',
      strikePrice: '₹449',
      perk: 'Deep coil clean',
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

    if (screenWidth >= 1100) {
      crossAxisCount = 3;
      childAspectRatio = 1.95;
    } else if (screenWidth >= 768) {
      crossAxisCount = 3;
      childAspectRatio = 1.65;
    } else if (screenWidth >= 540) {
      crossAxisCount = 2;
      childAspectRatio = 1.6;
    } else {
      // Standard mobile phone screen (e.g. 360px - 430px)
      crossAxisCount = 2;
      childAspectRatio = 1.14;
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isHovered
                    ? cfg.accentColor.withValues(alpha: 0.45)
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
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 1. Top Bar: Icon + Live Pill Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cfg.bgTint,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: cfg.accentColor.withValues(alpha: 0.18),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            cfg.iconData,
                            color: cfg.accentColor,
                            size: 19,
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

                    // 2. Middle Section: Title + Arrival + Rating
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
                            height: 1.15,
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
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Rating & Verified row
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 2),
                              Text(
                                cfg.rating,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '(${cfg.jobsCount})',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF94A3B8),
                                ),
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
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, size: 11, color: Color(0xFF16A34A)),
                              const SizedBox(width: 2),
                              Text(
                                'Verified',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // 3. Urban Company Value Perk Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 10, color: const Color(0xFF64748B)),
                          const SizedBox(width: 3),
                          Text(
                            cfg.perk,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 4. Bottom Row: Price & Book Pill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'From ',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                                Text(
                                  cfg.strikePrice,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    decoration: TextDecoration.lineThrough,
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              cfg.startingPrice,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: cfg.accentColor,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: cfg.accentColor.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Book',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 10.5,
                                color: Colors.white,
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
