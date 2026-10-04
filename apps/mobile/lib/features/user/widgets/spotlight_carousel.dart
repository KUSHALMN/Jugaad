import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/post_job/post_job_state.dart';

class SpotlightBannerItem {
  final String id;
  final String assetPath;
  final String title;
  final VoidCallback onTap;

  const SpotlightBannerItem({
    required this.id,
    required this.assetPath,
    required this.title,
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

  static const List<String> _bannerPaths = [
    'assets/images/banner_promo_1.png',
    'assets/images/banner_promo_2.png',
    'assets/images/banner_promo_3.png',
    'assets/images/banner_promo_4.png',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _bannerPaths.length;
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
      for (final path in _bannerPaths) {
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
      final nextPage = (_currentPage + 1) % _bannerPaths.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_pageController.hasClients) {
      final prevPage = (_currentPage - 1 + _bannerPaths.length) % _bannerPaths.length;
      _pageController.animateToPage(
        prevPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<SpotlightBannerItem> promoItems = [
      // 1. Trusted Local Experts at Your Doorstep (AC Service / General)
      SpotlightBannerItem(
        id: 'promo_1',
        assetPath: 'assets/images/banner_promo_1.png',
        title: 'Trusted Local Experts at Your Doorstep',
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(postJobProvider.notifier).reset();
          ref.read(postJobProvider.notifier).setSkill('AC Service');
          ref.read(postJobProvider.notifier).setUrgency('now');
          ref.read(postJobProvider.notifier).setScheduledAt(null);
          context.push('/user/post-job/step2');
        },
      ),

      // 2. Your Local Help, Just a Tap Away (Mysuru & Bengaluru)
      SpotlightBannerItem(
        id: 'promo_2',
        assetPath: 'assets/images/banner_promo_2.png',
        title: 'Your Local Help, Just a Tap Away',
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(postJobProvider.notifier).reset();
          ref.read(postJobProvider.notifier).setSkill('Electrician');
          ref.read(postJobProvider.notifier).setUrgency('now');
          ref.read(postJobProvider.notifier).setScheduledAt(null);
          context.push('/user/post-job/step2');
        },
      ),

      // 3. Your First Service FREE at ₹0 (Mysuru & Bengaluru)
      SpotlightBannerItem(
        id: 'promo_3',
        assetPath: 'assets/images/banner_promo_3.png',
        title: 'Your First Service FREE at ₹0',
        onTap: () {
          HapticFeedback.heavyImpact();
          ref.read(postJobProvider.notifier).reset();
          ref.read(postJobProvider.notifier).setSkill('Home Repair');
          ref.read(postJobProvider.notifier).setUrgency('now');
          ref.read(postJobProvider.notifier).setScheduledAt(null);
          context.push('/user/post-job/step2');
        },
      ),

      // 4. Real People. Real Solutions. (Serving Mysuru & Bengaluru)
      SpotlightBannerItem(
        id: 'promo_4',
        assetPath: 'assets/images/banner_promo_4.png',
        title: 'Real People. Real Solutions.',
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(postJobProvider.notifier).reset();
          ref.read(postJobProvider.notifier).setSkill('Plumber');
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
                      color: Color(0xFF16A34A),
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
                          color: isActive ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
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

        // Carousel Slider - Proportional aspect ratio banner container
        LayoutBuilder(
          builder: (context, constraints) {
            // Keep padding horizontal 16 on each side
            final double availableWidth = constraints.maxWidth;
            // On desktop/tablet, constrain max width for elegant presentation
            final double cardWidth = isWide
                ? (availableWidth > 960 ? 960 : availableWidth - 32)
                : (availableWidth - 32);
            // 1024 / 342 = ~2.994 aspect ratio
            final double bannerHeight = cardWidth / (1024.0 / 342.0);

            return Center(
              child: SizedBox(
                width: cardWidth,
                height: bannerHeight,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  itemCount: promoItems.length,
                  itemBuilder: (context, idx) {
                    final item = promoItems[idx];
                    return _SpotlightBannerCard(item: item);
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SpotlightBannerCard extends StatefulWidget {
  final SpotlightBannerItem item;

  const _SpotlightBannerCard({
    required this.item,
  });

  @override
  State<_SpotlightBannerCard> createState() => _SpotlightBannerCardState();
}

class _SpotlightBannerCardState extends State<_SpotlightBannerCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

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
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                item.assetPath,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFFF1F5F9),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_rounded,
                    color: Color(0xFF94A3B8),
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
