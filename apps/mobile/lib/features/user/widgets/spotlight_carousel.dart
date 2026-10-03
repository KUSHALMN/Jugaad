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
  final Color tagBgColor;
  final Color tagBorderColor;
  final String title;
  final String highlightText;
  final Color highlightColor;
  final String subtitle;
  final List<String> perks;
  final String priceText;
  final String originalPrice;
  final String assetPath;
  final String buttonText;
  final List<Color> gradientColors;
  final Color accentGlow;
  final Color borderColor;
  final Color buttonBgColor;
  final Color buttonTextColor;
  final VoidCallback onTap;

  const SpotlightPromoItem({
    required this.tag,
    required this.tagIcon,
    required this.tagColor,
    required this.tagBgColor,
    required this.tagBorderColor,
    required this.title,
    required this.highlightText,
    required this.highlightColor,
    required this.subtitle,
    required this.perks,
    required this.priceText,
    required this.originalPrice,
    required this.assetPath,
    required this.buttonText,
    required this.gradientColors,
    required this.accentGlow,
    required this.borderColor,
    this.buttonBgColor = const Color(0xFF0F172A),
    this.buttonTextColor = Colors.white,
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

  bool _imagesPrecached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      for (final path in const [
        'assets/images/banner_ac_apple.jpg',
        'assets/images/service_laptop.jpg',
        'assets/images/service_electrician.jpg',
        'assets/images/banner_stove_apple.jpg',
      ]) {
        precacheImage(AssetImage(path), context);
      }
    }
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
      // 1. AC Service Spotlight (Light Fresh Azure / Sky Blue)
      SpotlightPromoItem(
        tag: 'SUMMER COOLING SALE • 40% OFF',
        tagIcon: Icons.ac_unit_rounded,
        tagColor: const Color(0xFF0284C7),
        tagBgColor: const Color(0xFFE0F2FE),
        tagBorderColor: const Color(0xFFBAE6FD),
        title: 'AC Deep Jet Cleaning',
        highlightText: '& Gas Boost',
        highlightColor: const Color(0xFF0284C7),
        subtitle: '2X deeper cooling wash with anti-rust shield',
        perks: ['✓ 30-Day Guarantee', '✓ Certified AC Pros'],
        priceText: '₹399',
        originalPrice: '₹699',
        assetPath: 'assets/images/banner_ac_apple.jpg',
        buttonText: 'Book now',
        gradientColors: const [
          Color(0xFFF0F9FF),
          Color(0xFFE0F2FE),
          Color(0xFFBAE6FD),
        ],
        accentGlow: const Color(0xFF38BDF8),
        borderColor: const Color(0xFFBAE6FD),
        buttonBgColor: const Color(0xFF0F172A),
        buttonTextColor: Colors.white,
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(postJobProvider.notifier).reset();
          ref.read(postJobProvider.notifier).setSkill('AC Service');
          ref.read(postJobProvider.notifier).setUrgency('now');
          ref.read(postJobProvider.notifier).setScheduledAt(null);
          context.push('/user/post-job/step2');
        },
      ),

      // 2. Doorstep Tech Lab Spotlight (Light Elegant Lavender / Violet)
      SpotlightPromoItem(
        tag: 'DOORSTEP TECH LAB • 4.9★ RATED',
        tagIcon: Icons.laptop_chromebook_rounded,
        tagColor: const Color(0xFF7C3AED),
        tagBgColor: const Color(0xFFF3E8FF),
        tagBorderColor: const Color(0xFFDDD6FE),
        title: 'Laptop & Phone Repair',
        highlightText: 'at Your Desk',
        highlightColor: const Color(0xFF7C3AED),
        subtitle: 'Screen, battery & logic board diagnostics in 45m',
        perks: ['✓ 6-Month Warranty', '✓ Original Spares'],
        priceText: '₹449',
        originalPrice: '₹799',
        assetPath: 'assets/images/service_laptop.jpg',
        buttonText: 'Book now',
        gradientColors: const [
          Color(0xFFFAF5FF),
          Color(0xFFF3E8FF),
          Color(0xFFEDE9FE),
        ],
        accentGlow: const Color(0xFFA78BFA),
        borderColor: const Color(0xFFDDD6FE),
        buttonBgColor: const Color(0xFF0F172A),
        buttonTextColor: Colors.white,
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(postJobProvider.notifier).reset();
          ref.read(postJobProvider.notifier).setSkill('Laptop Repair');
          ref.read(postJobProvider.notifier).setUrgency('now');
          ref.read(postJobProvider.notifier).setScheduledAt(null);
          context.push('/user/post-job/step2');
        },
      ),

      // 3. Instant Electrician & Plumber Express (Light Warm Amber / Peach Cream)
      SpotlightPromoItem(
        tag: '⚡ 15-MIN EXPRESS ARRIVAL',
        tagIcon: Icons.bolt_rounded,
        tagColor: const Color(0xFFD97706),
        tagBgColor: const Color(0xFFFEF3C7),
        tagBorderColor: const Color(0xFFFDE68A),
        title: 'Emergency Electrician',
        highlightText: '& Plumber',
        highlightColor: const Color(0xFFEA580C),
        subtitle: 'Immediate breakdown fixes with live GPS tracking',
        perks: ['✓ Zero Inspection Fee', '✓ Live Arrival in 15m'],
        priceText: '₹99',
        originalPrice: '₹199',
        assetPath: 'assets/images/service_electrician.jpg',
        buttonText: 'Instant Help',
        gradientColors: const [
          Color(0xFFFFFBEB),
          Color(0xFFFEF3C7),
          Color(0xFFFFEDD5),
        ],
        accentGlow: const Color(0xFFFB923C),
        borderColor: const Color(0xFFFED7AA),
        buttonBgColor: const Color(0xFF0F172A),
        buttonTextColor: Colors.white,
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

      // 4. Gas Stove & Burner Overhaul (Light Fresh Mint / Botanical Sage)
      SpotlightPromoItem(
        tag: 'SAFETY CERTIFIED • 100% AUDIT',
        tagIcon: Icons.local_fire_department_rounded,
        tagColor: const Color(0xFF059669),
        tagBgColor: const Color(0xFFDCFCE7),
        tagBorderColor: const Color(0xFFA7F3D0),
        title: 'Gas Stove & Hob Overhaul',
        highlightText: 'with Leak Test',
        highlightColor: const Color(0xFF059669),
        subtitle: 'Restore blue flame efficiency & complete pipeline check',
        perks: ['✓ Blue Flame Restore', '✓ Gas Leak Audit'],
        priceText: '₹199',
        originalPrice: '₹349',
        assetPath: 'assets/images/banner_stove_apple.jpg',
        buttonText: 'Book now',
        gradientColors: const [
          Color(0xFFF0FDF4),
          Color(0xFFDCFCE7),
          Color(0xFFD1FAE5),
        ],
        accentGlow: const Color(0xFF34D399),
        borderColor: const Color(0xFFA7F3D0),
        buttonBgColor: const Color(0xFF0F172A),
        buttonTextColor: Colors.white,
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
                          color: isActive ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1),
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
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x080F172A),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
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
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x080F172A),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
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

    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          item.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.985 : 1.0,
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
                  color: item.accentGlow.withValues(alpha: 0.16),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                const BoxShadow(
                  color: Color(0x080F172A),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: item.borderColor,
                width: 1.2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Ambient soft radial light in background
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          item.accentGlow.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Right-side High Resolution Service Photograph with smooth light blend
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
                        cacheWidth: isWide ? 760 : 420,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.transparent,
                          child: Icon(
                            Icons.home_repair_service_rounded,
                            color: item.tagColor.withValues(alpha: 0.35),
                            size: 48,
                          ),
                        ),
                      ),
                      // Multi-stop directional gradient mask to blend into the light card seamlessly
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              item.gradientColors.first,
                              item.gradientColors.first.withValues(alpha: 0.96),
                              item.gradientColors[1].withValues(alpha: 0.60),
                              item.gradientColors[1].withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.25, 0.55, 0.80, 1.0],
                          ),
                        ),
                      ),
                      // Subtle top & bottom edge blend
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              item.gradientColors.first.withValues(alpha: 0.25),
                              Colors.transparent,
                              item.gradientColors.last.withValues(alpha: 0.35),
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
                          // Urban Company Clean Tag Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                            decoration: BoxDecoration(
                              color: item.tagBgColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: item.tagBorderColor,
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
                                    color: item.tagColor,
                                    letterSpacing: 0.4,
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
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.4,
                                height: 1.16,
                              ),
                              children: [
                                TextSpan(text: '${item.title} '),
                                TextSpan(
                                  text: item.highlightText,
                                  style: TextStyle(
                                    color: item.highlightColor,
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
                              color: const Color(0xFF475569),
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
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    item.originalPrice,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: isWide ? 12 : 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF94A3B8),
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          // High-contrast Apple/Urban Company CTA Pill Button
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isWide ? 18 : 14,
                              vertical: isWide ? 8.5 : 7,
                            ),
                            decoration: BoxDecoration(
                              color: item.buttonBgColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x220F172A),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
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
                                    color: item.buttonTextColor,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: item.buttonTextColor,
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
      ),
    );
  }
}
