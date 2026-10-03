import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/post_job/post_job_state.dart';

class SpotlightPromoItem {
  final String tag;
  final IconData tagIcon;
  final Color tagColor;
  final String title;
  final String highlightText;
  final String subtitle;
  final List<String> perks;
  final String priceText;
  final String originalPrice;
  final String assetPath;
  final String buttonText;
  final List<Color> gradientColors;
  final Color accentGlow;
  final VoidCallback onTap;

  const SpotlightPromoItem({
    required this.tag,
    required this.tagIcon,
    required this.tagColor,
    required this.title,
    required this.highlightText,
    required this.subtitle,
    required this.perks,
    required this.priceText,
    required this.originalPrice,
    required this.assetPath,
    required this.buttonText,
    required this.gradientColors,
    required this.accentGlow,
    required this.onTap,
  });
}

class SpotlightCarousel extends ConsumerStatefulWidget {
  const SpotlightCarousel({super.key});

  @override
  ConsumerState<SpotlightCarousel> createState() => _SpotlightCarouselState();
}

class _SpotlightCarouselState extends ConsumerState<SpotlightCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.94);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % 4;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_pageController.hasClients) {
      final nextPage = (_currentPage + 1) % 4;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_pageController.hasClients) {
      final prevPage = (_currentPage - 1 + 4) % 4;
      _pageController.animateToPage(
        prevPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<SpotlightPromoItem> promoItems = [
      // 1. AC Service Spotlight (Urban Company Deep Royal Blue)
      SpotlightPromoItem(
        tag: 'SUMMER COOLING SALE • 40% OFF',
        tagIcon: Icons.ac_unit_rounded,
        tagColor: const Color(0xFF38BDF8),
        title: 'AC Deep Jet Cleaning',
        highlightText: '& Gas Boost',
        subtitle: '2X deeper cooling wash with anti-rust shield',
        perks: ['✓ 30-Day Guarantee', '✓ Certified AC Pros'],
        priceText: '₹399',
        originalPrice: '₹699',
        assetPath: 'assets/images/banner_ac_apple.jpg',
        buttonText: 'Book now',
        gradientColors: const [
          Color(0xFF0A192F),
          Color(0xFF0F3460),
          Color(0xFF1E3A8A),
        ],
        accentGlow: const Color(0xFF0284C7),
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(postJobProvider.notifier).reset();
          ref.read(postJobProvider.notifier).setSkill('AC Service');
          ref.read(postJobProvider.notifier).setUrgency('now');
          ref.read(postJobProvider.notifier).setScheduledAt(null);
          context.push('/user/post-job/step2');
        },
      ),

      // 2. Doorstep Tech Lab Spotlight (Urban Company Sleek Electric Violet)
      SpotlightPromoItem(
        tag: 'DOORSTEP TECH LAB • 4.9★ RATED',
        tagIcon: Icons.laptop_chromebook_rounded,
        tagColor: const Color(0xFFA78BFA),
        title: 'Laptop & Phone Repair',
        highlightText: 'at Your Desk',
        subtitle: 'Screen, battery & logic board diagnostics in 45m',
        perks: ['✓ 6-Month Warranty', '✓ Original Spares'],
        priceText: '₹449',
        originalPrice: '₹799',
        assetPath: 'assets/images/service_laptop.jpg',
        buttonText: 'Book now',
        gradientColors: const [
          Color(0xFF130924),
          Color(0xFF2E1065),
          Color(0xFF4C1D95),
        ],
        accentGlow: const Color(0xFF8B5CF6),
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(postJobProvider.notifier).reset();
          ref.read(postJobProvider.notifier).setSkill('Laptop Repair');
          ref.read(postJobProvider.notifier).setUrgency('now');
          ref.read(postJobProvider.notifier).setScheduledAt(null);
          context.push('/user/post-job/step2');
        },
      ),

      // 3. Instant Electrician & Plumber Express (Urban Company High Urgency Ruby)
      SpotlightPromoItem(
        tag: '⚡ 15-MIN EXPRESS ARRIVAL',
        tagIcon: Icons.bolt_rounded,
        tagColor: const Color(0xFFFBBF24),
        title: 'Emergency Electrician',
        highlightText: '& Plumber',
        subtitle: 'Immediate breakdown fixes with live GPS tracking',
        perks: ['✓ Zero Inspection Fee', '✓ Live Arrival in 15m'],
        priceText: '₹99',
        originalPrice: '₹199',
        assetPath: 'assets/images/service_electrician.jpg',
        buttonText: 'Instant Help',
        gradientColors: const [
          Color(0xFF200B0B),
          Color(0xFF831843),
          Color(0xFF991B1B),
        ],
        accentGlow: const Color(0xFFEA580C),
        onTap: () {
          HapticFeedback.heavyImpact();
          ref.read(postJobProvider.notifier).reset();
          ref.read(postJobProvider.notifier).setSkill('Electrician');
          ref.read(postJobProvider.notifier).setEmergency(true);
          ref.read(postJobProvider.notifier).setUrgency('now');
          ref.read(postJobProvider.notifier).setScheduledAt(null);
          context.push('/user/post-job/step2');
        },
      ),

      // 4. Gas Stove & Burner Overhaul (Urban Company Emerald Safety)
      SpotlightPromoItem(
        tag: 'SAFETY CERTIFIED • 100% AUDIT',
        tagIcon: Icons.local_fire_department_rounded,
        tagColor: const Color(0xFF34D399),
        title: 'Gas Stove & Hob Overhaul',
        highlightText: 'with Leak Test',
        subtitle: 'Restore blue flame efficiency & complete pipeline check',
        perks: ['✓ Blue Flame Restore', '✓ Gas Leak Audit'],
        priceText: '₹199',
        originalPrice: '₹349',
        assetPath: 'assets/images/banner_stove_apple.jpg',
        buttonText: 'Book now',
        gradientColors: const [
          Color(0xFF041F1A),
          Color(0xFF064E3B),
          Color(0xFF065F46),
        ],
        accentGlow: const Color(0xFF10B981),
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(postJobProvider.notifier).reset();
          ref.read(postJobProvider.notifier).setSkill('Stove Repair');
          ref.read(postJobProvider.notifier).setUrgency('now');
          ref.read(postJobProvider.notifier).setScheduledAt(null);
          context.push('/user/post-job/step2');
        },
      ),
    ];

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth > 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with Dots & Navigation Chevrons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'In the spotlight',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Dot indicators
                  Row(
                    children: List.generate(promoItems.length, (idx) {
                      final bool isActive = idx == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: isActive ? 20 : 6,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF1E3A8A) : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  if (isWide) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _prevPage,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(Icons.chevron_left_rounded, size: 16, color: Color(0xFF0F172A)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _nextPage,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Carousel Slider - Height dynamically adapts to screen
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SizedBox(
              height: isWide ? 205 : 180,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemCount: promoItems.length,
                itemBuilder: (context, idx) {
                  final item = promoItems[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: _UrbanCompanySpotlightCard(item: item, isWide: isWide),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UrbanCompanySpotlightCard extends StatefulWidget {
  final SpotlightPromoItem item;
  final bool isWide;

  const _UrbanCompanySpotlightCard({
    required this.item,
    required this.isWide,
  });

  @override
  State<_UrbanCompanySpotlightCard> createState() => _UrbanCompanySpotlightCardState();
}

class _UrbanCompanySpotlightCardState extends State<_UrbanCompanySpotlightCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isWide = widget.isWide;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        item.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: item.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: item.accentGlow.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
              const BoxShadow(
                color: Color(0x18000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1.2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Ambient soft radial light in background
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        item.accentGlow.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Right-side High Resolution Service Photograph with smooth cinematic blend
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: isWide ? 380 : 210,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      item.assetPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.transparent,
                        child: Icon(Icons.home_repair_service_rounded, color: Colors.white.withValues(alpha: 0.3), size: 48),
                      ),
                    ),
                    // Multi-stop directional gradient mask to blend into card seamlessly
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            item.gradientColors.first,
                            item.gradientColors.first.withValues(alpha: 0.88),
                            item.gradientColors[1].withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.28, 0.65, 1.0],
                        ),
                      ),
                    ),
                    // Top & Bottom vignette
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            item.gradientColors.first.withValues(alpha: 0.3),
                            Colors.transparent,
                            item.gradientColors.last.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Left-side Copy, Badges, Features and Urban Company Style CTA
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 26 : 18,
                  isWide ? 20 : 16,
                  isWide ? 280 : 130,
                  isWide ? 20 : 15,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Urban Company Frosted Glass Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(item.tagIcon, color: item.tagColor, size: 12),
                              const SizedBox(width: 5),
                              Text(
                                item.tag,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: isWide ? 10.5 : 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Title with highlight
                        RichText(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: isWide ? 19 : 15.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.4,
                              height: 1.16,
                            ),
                            children: [
                              TextSpan(text: '${item.title} '),
                              TextSpan(
                                text: item.highlightText,
                                style: TextStyle(
                                  color: item.tagColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),

                        // Value prop subtitle
                        Text(
                          item.subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isWide ? 12 : 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.25,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),

                    // Bottom Row: Price + Urban Company CTA Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item.priceText,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isWide ? 18 : 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  item.originalPrice,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isWide ? 12 : 11,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        // Elevated CTA Pill Button
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWide ? 18 : 14,
                            vertical: isWide ? 8.5 : 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.buttonText,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: isWide ? 12.5 : 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
