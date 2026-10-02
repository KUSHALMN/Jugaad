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
  final String imageUrl;
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
    required this.imageUrl,
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
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final List<UrbanPromoItem> promoItems = [
      // 1. AC Service Spotlight
      UrbanPromoItem(
        tag: 'Summer Special',
        tagBg: const Color(0xFF0284C7),
        tagTextColor: Colors.white,
        title: 'AC Jet Cleaning & Gas Refill',
        subtitle: '2X deeper cooling & anti-rust foam wash at home',
        priceText: 'Starting ₹399',
        imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?auto=format&fit=crop&w=800&q=80',
        buttonText: 'Book now',
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(postJobProvider.notifier).reset();
          ref.read(postJobProvider.notifier).setSkill('AC Service');
          context.push('/user/worker-search?service=AC%20Service');
        },
      ),

      // 2. Doorstep Phone & Laptop Lab Spotlight
      UrbanPromoItem(
        tag: 'Doorstep Tech Lab',
        tagBg: const Color(0xFF6366F1),
        tagTextColor: Colors.white,
        title: 'Phone & Laptop Quick Repairs',
        subtitle: 'Cracked screen or dead battery fixed right at your desk',
        priceText: 'Starting ₹499',
        imageUrl: 'https://images.unsplash.com/photo-1597740985671-2a8a3b80532e?auto=format&fit=crop&w=800&q=80',
        buttonText: 'Book now',
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(postJobProvider.notifier).reset();
          ref.read(postJobProvider.notifier).setSkill('Phone Repair');
          context.push('/user/worker-search?service=Phone%20Repair');
        },
      ),

      // 3. Instant Electrician & Plumber Express Dispatch
      UrbanPromoItem(
        tag: '⚡ 15-Min Arrival',
        tagBg: const Color(0xFFDC2626),
        tagTextColor: Colors.white,
        title: 'Electrician & Plumber at Doorstep',
        subtitle: 'Rapid arrival in Bengaluru & Mysuru with 30-day warranty',
        priceText: 'Starting ₹99',
        imageUrl: 'https://images.unsplash.com/photo-1621905251918-48416bd8575a?auto=format&fit=crop&w=800&q=80',
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

      // 4. Gas Stove & Burner Overhaul
      UrbanPromoItem(
        tag: 'Safety Guaranteed',
        tagBg: const Color(0xFFD97706),
        tagTextColor: Colors.white,
        title: 'Gas Stove & Hob Deep Overhaul',
        subtitle: 'Restore blue flame, unclog burners & gas leak check',
        priceText: 'Starting ₹199',
        imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?auto=format&fit=crop&w=800&q=80',
        buttonText: 'Book now',
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(postJobProvider.notifier).reset();
          ref.read(postJobProvider.notifier).setSkill('Stove Repair');
          context.push('/user/worker-search?service=Stove%20Repair');
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Urban Company "In the spotlight" Section Title
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
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Carousel Slider Cards with Stock Web Photography
        SizedBox(
          height: 165,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            itemCount: promoItems.length,
            itemBuilder: (context, idx) {
              final item = promoItems[idx];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                child: _buildSpotlightCard(item),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpotlightCard(UrbanPromoItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Right-aligned stock photo
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 170,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFFF1F5F9),
                    child: const Icon(Icons.home_repair_service_rounded, color: Color(0xFF94A3B8), size: 36),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(color: const Color(0xFFF1F5F9));
                  },
                ),
                // Gradient fade to card background
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white,
                        Color(0x22FFFFFF),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Left side content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 160, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
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
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    GestureDetector(
                      onTap: item.onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                            fontSize: 11.5,
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
        ],
      ),
    );
  }
}
