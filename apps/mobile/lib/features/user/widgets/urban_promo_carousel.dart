import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/post_job/post_job_state.dart';

class UrbanPromoItem {
  final String tag;
  final Color tagBg;
  final Color tagTextColor;
  final String title;
  final String subtitle;
  final String priceText;
  final String assetPath;
  final String buttonText;
  final Color buttonBg;
  final Color buttonTextColor;
  final VoidCallback onTap;

  const UrbanPromoItem({
    required this.tag,
    required this.tagBg,
    required this.tagTextColor,
    required this.title,
    required this.subtitle,
    required this.priceText,
    required this.assetPath,
    required this.buttonText,
    this.buttonBg = const Color(0xFF0F172A),
    this.buttonTextColor = Colors.white,
    required this.onTap,
  });
}

class UrbanPromoCarousel extends ConsumerStatefulWidget {
  const UrbanPromoCarousel({super.key});

  @override
  ConsumerState<UrbanPromoCarousel> createState() => _UrbanPromoCarouselState();
}

class _UrbanPromoCarouselState extends ConsumerState<UrbanPromoCarousel> {
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
    final List<UrbanPromoItem> promoItems = [
      // 1. AC Service Spotlight (Apple Minimalist Aether Design)
      UrbanPromoItem(
        tag: 'Summer Special',
        tagBg: const Color(0xFF0284C7),
        tagTextColor: Colors.white,
        title: 'AC Jet Clean & Cooling Boost',
        subtitle: 'Deep anti-rust foam wash & gas check at home',
        priceText: 'From ₹399',
        assetPath: 'assets/images/banner_ac_apple.jpg',
        buttonText: 'Book now',
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(postJobProvider.notifier).reset();
          ref.read(postJobProvider.notifier).setSkill('AC Service');
          context.push('/user/worker-search?service=AC%20Service');
        },
      ),

      // 2. Doorstep Phone & Laptop Lab Spotlight (Apple Titanium Workbench)
      UrbanPromoItem(
        tag: 'Doorstep Tech Lab',
        tagBg: const Color(0xFF6366F1),
        tagTextColor: Colors.white,
        title: 'Phone & Laptop Precision Care',
        subtitle: 'Screen, battery & motherboard diagnostic at your desk',
        priceText: 'From ₹499',
        assetPath: 'assets/images/banner_tech_apple.jpg',
        buttonText: 'Book now',
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(postJobProvider.notifier).reset();
          ref.read(postJobProvider.notifier).setSkill('Phone Repair');
          context.push('/user/worker-search?service=Phone%20Repair');
        },
      ),

      // 3. Instant Electrician & Plumber Express (Symmetric Pro Tools)
      UrbanPromoItem(
        tag: '⚡ 15-Min Arrival',
        tagBg: const Color(0xFFDC2626),
        tagTextColor: Colors.white,
        title: 'Rapid Electrician & Plumber',
        subtitle: 'Doorstep breakdown fixes with 30-day warranty',
        priceText: 'From ₹99',
        assetPath: 'assets/images/banner_tools_apple.jpg',
        buttonText: 'Instant Help',
        buttonBg: const Color(0xFFDC2626),
        onTap: () {
          HapticFeedback.heavyImpact();
          ref.read(postJobProvider.notifier).reset();
          ref.read(postJobProvider.notifier).setEmergency(true);
          ref.read(postJobProvider.notifier).setUrgency('now');
          context.push('/user/post-job/step1');
        },
      ),

      // 4. Gas Stove & Burner Overhaul (Sleek Induction & Blue Flame)
      UrbanPromoItem(
        tag: 'Safety Guaranteed',
        tagBg: const Color(0xFFD97706),
        tagTextColor: Colors.white,
        title: 'Gas Stove & Hob Overhaul',
        subtitle: 'Restore blue flame & comprehensive gas leak audit',
        priceText: 'From ₹199',
        assetPath: 'assets/images/banner_stove_apple.jpg',
        buttonText: 'Book now',
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(postJobProvider.notifier).reset();
          ref.read(postJobProvider.notifier).setSkill('Stove Repair');
          context.push('/user/worker-search?service=Stove%20Repair');
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
              Text(
                'In the spotlight',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              Row(
                children: [
                  // Dot indicators
                  Row(
                    children: List.generate(promoItems.length, (idx) {
                      final bool isActive = idx == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: isActive ? 16 : 6,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
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
              height: isWide ? 190 : 160,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemCount: promoItems.length,
                itemBuilder: (context, idx) {
                  final item = promoItems[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: _buildAppleSpotlightCard(item, isWide),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppleSpotlightCard(UrbanPromoItem item, bool isWide) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 18,
            offset: Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // Left Content - Proportional 55% or 50%
          Expanded(
            flex: isWide ? 6 : 6,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isWide ? 24 : 16,
                isWide ? 18 : 14,
                isWide ? 16 : 10,
                isWide ? 18 : 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.tagBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.tag,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: item.tagTextColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        item.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isWide ? 16.5 : 13.5,
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
                          fontSize: isWide ? 12 : 10.5,
                          color: const Color(0xFF64748B),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        item.priceText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isWide ? 14 : 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      GestureDetector(
                        onTap: item.onTap,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWide ? 18 : 12,
                            vertical: isWide ? 8 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: item.buttonBg,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: item.buttonBg.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            item.buttonText,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: isWide ? 12.5 : 11,
                              fontWeight: FontWeight.w700,
                              color: item.buttonTextColor,
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

          // Right Content - Proportional 45% or 50% Image that spans full height with subtle fade
          Expanded(
            flex: isWide ? 5 : 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  item.assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFFF1F5F9),
                    child: const Center(
                      child: Icon(Icons.home_repair_service_rounded, color: Color(0xFF94A3B8), size: 36),
                    ),
                  ),
                ),
                // Gradient fade to card background
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white,
                        Color(0x33FFFFFF),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
