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
      childAspectRatio = 1.30;
    } else if (screenWidth >= 600) {
      crossAxisCount = 2;
      childAspectRatio = 1.15;
    } else {
      // Mobile - 2 columns, tall cards (0.92 ratio) to comfortably fit all text and buttons
      crossAxisCount = 2;
      childAspectRatio = 0.92;
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
  bool _isBookmarked = false;

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final String displayBadgeText = (widget.dynamicCount != null && widget.dynamicCount! > 0)
        ? '${widget.dynamicCount} Available'
        : cfg.badgeText;

    final double scale = _isPressed ? 0.97 : (_isHovered ? 1.02 : 1.0);
    final double translateY = _isHovered ? -6.0 : 0.0;

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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, translateY, 0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFFAFBFC),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered
                    ? cfg.accentColor.withValues(alpha: 0.50)
                    : const Color(0xFFECECEC),
                width: _isHovered ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? cfg.accentColor.withValues(alpha: 0.16)
                      : const Color.fromRGBO(0, 0, 0, 0.06),
                  blurRadius: _isHovered ? 24 : 16,
                  offset: _isHovered ? const Offset(0, 10) : const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Availability Badge + Favorite Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cfg.accentColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: cfg.accentColor.withValues(alpha: 0.20),
                            ),
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
                                style: GoogleFonts.inter(
                                  color: cfg.accentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _isBookmarked = !_isBookmarked);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Icon(
                                _isBookmarked
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                size: 16,
                                color: _isBookmarked
                                    ? cfg.accentColor
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Icon + Service Details
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: cfg.bgTint,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cfg.accentColor.withValues(alpha: 0.15),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            cfg.iconData,
                            color: cfg.accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cfg.title,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                  height: 1.15,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cfg.subtitle,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF64748B),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Trust Bar
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 2),
                        Text(
                          cfg.rating,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '(${cfg.jobsCount})',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
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
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Primary CTA Button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        color: _isHovered
                            ? cfg.accentColor
                            : cfg.accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Book Service',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _isHovered ? Colors.white : cfg.accentColor,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedSlide(
                            offset: _isHovered ? const Offset(0.25, 0) : Offset.zero,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: _isHovered ? Colors.white : cfg.accentColor,
                            ),
                          ),
                        ],
                      ),
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
