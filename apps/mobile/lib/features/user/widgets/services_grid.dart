import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/services_list.dart';
import '../screens/post_job/post_job_state.dart';

class UrbanServiceCardItem {
  final String id;
  final String title;
  final String categoryName;
  final String subtitle;
  final String badgeText;
  final String assetPath;
  final IconData icon;
  final Color accentColor;
  final String rating;
  final String reviewCount;
  final String price;
  final String strikePrice;
  final String perk;

  const UrbanServiceCardItem({
    required this.id,
    required this.title,
    required this.categoryName,
    required this.subtitle,
    required this.badgeText,
    required this.assetPath,
    required this.icon,
    required this.accentColor,
    required this.rating,
    required this.reviewCount,
    required this.price,
    required this.strikePrice,
    required this.perk,
  });
}

class ServicesGrid extends ConsumerStatefulWidget {
  final List<ServiceDef> servicesList;
  final Map<String, int> counts;

  const ServicesGrid({
    super.key,
    required this.servicesList,
    required this.counts,
  });

  @override
  ConsumerState<ServicesGrid> createState() => _ServicesGridState();
}

class _ServicesGridState extends ConsumerState<ServicesGrid> {
  final ScrollController _scrollController = ScrollController();

  /// The EXACT 7 services specified:
  /// Plumber, Electrician, Phone Repair, Laptop Repair, AC Service, Carpenter, Stove Repair
  static const List<UrbanServiceCardItem> curatedServices = [
    UrbanServiceCardItem(
      id: 'ac_service',
      title: 'AC Jet Cleaning & Gas Check',
      categoryName: 'AC Service',
      subtitle: '2X deeper cooling • Indoor & outdoor unit',
      badgeText: 'Popular',
      assetPath: 'assets/images/banner_ac_apple.jpg',
      icon: Icons.ac_unit_rounded,
      accentColor: Color(0xFF0284C7),
      rating: '4.88',
      reviewCount: '14k',
      price: '₹399',
      strikePrice: '₹599',
      perk: '30-day warranty',
    ),
    UrbanServiceCardItem(
      id: 'phone_repair',
      title: 'Phone Screen & Battery Fix',
      categoryName: 'Phone Repair',
      subtitle: 'Original parts • Doorstep repair in 45m',
      badgeText: 'Doorstep Lab',
      assetPath: 'assets/images/banner_tech_apple.jpg',
      icon: Icons.phone_android_rounded,
      accentColor: Color(0xFF0D9488),
      rating: '4.89',
      reviewCount: '18k',
      price: '₹499',
      strikePrice: '₹799',
      perk: '6-mo warranty',
    ),
    UrbanServiceCardItem(
      id: 'electrician',
      title: 'Electrician Inspection & Wiring',
      categoryName: 'Electrician',
      subtitle: 'Switchboards, MCB, fans & short circuit',
      badgeText: '15 Min',
      assetPath: 'assets/images/banner_tools_apple.jpg',
      icon: Icons.electrical_services_rounded,
      accentColor: Color(0xFFEA580C),
      rating: '4.84',
      reviewCount: '32k',
      price: '₹99',
      strikePrice: '₹149',
      perk: 'Zero inspection fee',
    ),
    UrbanServiceCardItem(
      id: 'plumber',
      title: 'Plumber Tap Leak & Drain Fix',
      categoryName: 'Plumber',
      subtitle: 'Taps, washbasins, pipe leaks & drains',
      badgeText: 'Express',
      assetPath: 'assets/images/banner_tools_apple.jpg',
      icon: Icons.plumbing_rounded,
      accentColor: Color(0xFF2563EB),
      rating: '4.82',
      reviewCount: '26k',
      price: '₹99',
      strikePrice: '₹199',
      perk: 'Leak seal guarantee',
    ),
    UrbanServiceCardItem(
      id: 'laptop_repair',
      title: 'Laptop Diagnostic & SSD Boost',
      categoryName: 'Laptop Repair',
      subtitle: 'Screen, RAM/SSD upgrade & OS fix',
      badgeText: 'Top Rated',
      assetPath: 'assets/images/banner_tech_apple.jpg',
      icon: Icons.laptop_mac_rounded,
      accentColor: Color(0xFF6366F1),
      rating: '4.92',
      reviewCount: '9.5k',
      price: '₹449',
      strikePrice: '₹699',
      perk: 'No fix no fee',
    ),
    UrbanServiceCardItem(
      id: 'stove_repair',
      title: 'Gas Stove & Hob Burner Repair',
      categoryName: 'Stove Repair',
      subtitle: 'Burner clean, spark ignition & leak test',
      badgeText: 'Safety Audit',
      assetPath: 'assets/images/banner_stove_apple.jpg',
      icon: Icons.local_fire_department_rounded,
      accentColor: Color(0xFFE11D48),
      rating: '4.85',
      reviewCount: '16k',
      price: '₹199',
      strikePrice: '₹299',
      perk: 'Gas leak safety test',
    ),
    UrbanServiceCardItem(
      id: 'carpenter',
      title: 'Carpenter Lock & Woodwork Fix',
      categoryName: 'Carpenter',
      subtitle: 'Door lock replacement, hinges & furniture',
      badgeText: 'Custom Fit',
      assetPath: 'assets/images/banner_tools_apple.jpg',
      icon: Icons.carpenter_rounded,
      accentColor: Color(0xFFD97706),
      rating: '4.79',
      reviewCount: '12k',
      price: '₹149',
      strikePrice: '₹249',
      perk: 'Precision alignment',
    ),
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollForward() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.offset + 260,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollBackward() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.offset - 260,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth > 768;

    return Stack(
      children: [
        // Urban Company Bangalore Horizontal Scroll Showcase (No awkward white space, no uneven gaps)
        SizedBox(
          height: 258,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
            itemCount: curatedServices.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = curatedServices[index];

              return SizedBox(
                width: isWide ? 260 : 230,
                child: _UrbanServiceCard(
                  item: item,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(postJobProvider.notifier).reset();
                    ref.read(postJobProvider.notifier).setSkill(item.categoryName);
                    context.push('/user/worker-search?service=${Uri.encodeComponent(item.categoryName)}');
                  },
                  onBookTap: () {
                    HapticFeedback.heavyImpact();
                    ref.read(postJobProvider.notifier).reset();
                    ref.read(postJobProvider.notifier).setSkill(item.categoryName);
                    ref.read(postJobProvider.notifier).setUrgency('now');
                    ref.read(postJobProvider.notifier).setEmergency(true);
                    context.push('/user/post-job/step2');
                  },
                ),
              );
            },
          ),
        ),

        // Desktop Web Forward/Backward Floating Navigation Chevrons
        if (isWide) ...[
          Positioned(
            left: 6,
            top: 105,
            child: GestureDetector(
              onTap: _scrollBackward,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x15000000), blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.chevron_left_rounded, size: 20, color: Color(0xFF0F172A)),
              ),
            ),
          ),
          Positioned(
            right: 6,
            top: 105,
            child: GestureDetector(
              onTap: _scrollForward,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x15000000), blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF0F172A)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _UrbanServiceCard extends StatefulWidget {
  final UrbanServiceCardItem item;
  final VoidCallback onTap;
  final VoidCallback onBookTap;

  const _UrbanServiceCard({
    required this.item,
    required this.onTap,
    required this.onBookTap,
  });

  @override
  State<_UrbanServiceCard> createState() => _UrbanServiceCardState();
}

class _UrbanServiceCardState extends State<_UrbanServiceCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top High-End Apple Asset Image with Rating Pill
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 124,
                    child: Image.asset(
                      item.assetPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFF1F5F9),
                        child: Center(
                          child: Icon(item.icon, color: item.accentColor, size: 30),
                        ),
                      ),
                    ),
                  ),
                  // Rating Badge in photo
                  Positioned(
                    bottom: 7,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 3),
                          Text(
                            item.rating,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '(${item.reviewCount})',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Category Tag badge top right
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      child: Text(
                        item.badgeText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: item.accentColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // 2. Compact Bottom Content: Title + Subtitle + Price & Book Pill (Zero white void)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                              height: 1.18,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.subtitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              color: const Color(0xFF64748B),
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),

                      // Price Row with tactile Urban Company style "Book" pill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.price,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.strikePrice,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  color: const Color(0xFF94A3B8),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: widget.onBookTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Book',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
