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

class _SpotlightCarouselState extends ConsumerState<SpotlightCarousel>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  int _currentPage = 0;
  double _pageOffset = 0.0;
  Timer? _timer;
  bool _isHovered = false;
  bool _isDragging = false;
  Timer? _resumeTimer;
  late final AnimationController _pulseDotController;

  static const List<String> _bannerPaths = [
    'assets/images/banner_promo_1.png',
    'assets/images/banner_promo_2.png',
    'assets/images/banner_promo_3.png',
    'assets/images/banner_promo_4.png',
  ];

  @override
  void initState() {
    super.initState();
    // 0.93 viewportFraction allows adjacent cards to peek into frame for a premium 3D depth effect
    _pageController = PageController(viewportFraction: 0.93);
    _pageController.addListener(_onScroll);

    _pulseDotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _startAutoPlay();
  }

  void _onScroll() {
    if (_pageController.hasClients && _pageController.position.haveDimensions) {
      final page = _pageController.page ?? _currentPage.toDouble();
      if ((page - _pageOffset).abs() > 0.005) {
        setState(() {
          _pageOffset = page;
        });
      }
    }
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _isHovered || _isDragging) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;

      if (_pageController.hasClients && _pageController.positions.length == 1) {
        final nextPage = (_currentPage + 1) % _bannerPaths.length;
        try {
          _pageController
              .animateToPage(
                nextPage,
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeInOutCubic,
              )
              .catchError((_) {});
        } catch (_) {}
      }
    });
  }

  void _restartAutoPlayWithDelay([int seconds = 4]) {
    _timer?.cancel();
    _resumeTimer?.cancel();
    _resumeTimer = Timer(Duration(seconds: seconds), () {
      if (mounted && !_isHovered && !_isDragging) {
        _startAutoPlay();
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
    _resumeTimer?.cancel();
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    _pulseDotController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (!mounted) return;
    if (_pageController.hasClients && _pageController.positions.length == 1) {
      HapticFeedback.selectionClick();
      _restartAutoPlayWithDelay(5);
      try {
        _pageController
            .animateToPage(
              page,
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOutCubic,
            )
            .catchError((_) {});
      } catch (_) {}
    }
  }

  void _nextPage() {
    final nextPage = (_currentPage + 1) % _bannerPaths.length;
    _goToPage(nextPage);
  }

  void _prevPage() {
    final prevPage = (_currentPage - 1 + _bannerPaths.length) % _bannerPaths.length;
    _goToPage(prevPage);
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
        // ── SECTION HEADER ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Animated live dot + "In the spotlight" title
              Expanded(
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseDotController,
                      builder: (context, _) {
                        final val = _pulseDotController.value;
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.3 + (val * 0.45)),
                                blurRadius: 4 + (val * 6),
                                spreadRadius: 1 + (val * 2.5),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'In the spotlight',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Right: Interactive Dot Indicators + Navigation Chevrons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Clickable Dot / Capsule indicators
                  Row(
                    children: List.generate(promoItems.length, (idx) {
                      final bool isActive = idx == _currentPage;
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => _goToPage(idx),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 6.0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                              width: isActive ? 22 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                gradient: isActive
                                    ? const LinearGradient(
                                        colors: [Color(0xFF059669), Color(0xFF10B981)],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      )
                                    : null,
                                color: isActive ? null : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                          blurRadius: 5,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  // Desktop/Tablet Chevrons
                  if (isWide) ...[
                    const SizedBox(width: 14),
                    _HeaderChevronBtn(
                      icon: Icons.chevron_left_rounded,
                      onTap: _prevPage,
                      tooltip: 'Previous banner',
                    ),
                    const SizedBox(width: 6),
                    _HeaderChevronBtn(
                      icon: Icons.chevron_right_rounded,
                      onTap: _nextPage,
                      tooltip: 'Next banner',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── 3D DEPTH CAROUSEL SLIDER ──
        LayoutBuilder(
          builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth;
            if (availableWidth <= 40) {
              return const SizedBox.shrink();
            }

            // Target width with optimal presentation on widescreen desktop
            final double maxWidth = isWide ? 980.0 : availableWidth;
            final double containerWidth = availableWidth.clamp(0.0, maxWidth);

            // Banner image nominal ratio: 1024 / 342 = ~2.994
            // On cards with 0.93 viewportFraction, calculate proportional height with padding
            final double cardWidth = (containerWidth * 0.93);
            final double bannerHeight = (cardWidth / (1024.0 / 342.0)).clamp(115.0, 360.0);

            return MouseRegion(
              onEnter: (_) {
                _isHovered = true;
                _timer?.cancel();
              },
              onExit: (_) {
                _isHovered = false;
                _startAutoPlay();
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification) {
                    _isDragging = true;
                    _timer?.cancel();
                  } else if (notification is ScrollEndNotification) {
                    _isDragging = false;
                    _restartAutoPlayWithDelay(4);
                  }
                  return false;
                },
                child: Center(
                  child: SizedBox(
                    width: containerWidth,
                    height: bannerHeight,
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (idx) {
                        if (mounted) {
                          setState(() {
                            _currentPage = idx;
                          });
                        }
                      },
                      itemCount: promoItems.length,
                      itemBuilder: (context, idx) {
                        final item = promoItems[idx];

                        // Calculate difference between current scroll offset and item index
                        final double diff = (idx - _pageOffset);
                        // Active card is 1.0; neighboring cards shrink smoothly to 0.935 for Apple-like card depth
                        final double scale = (1.0 - (diff.abs() * 0.065)).clamp(0.915, 1.0);
                        // Subtle opacity fade for peek cards
                        final double opacity = (1.0 - (diff.abs() * 0.22)).clamp(0.78, 1.0);

                        return Transform.scale(
                          scale: scale,
                          alignment: Alignment.center,
                          child: Opacity(
                            opacity: opacity,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5.0),
                              child: _SpotlightBannerCard(item: item),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HeaderChevronBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _HeaderChevronBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<_HeaderChevronBtn> createState() => _HeaderChevronBtnState();
}

class _HeaderChevronBtnState extends State<_HeaderChevronBtn> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.tooltip,
          child: AnimatedScale(
            scale: _isPressed ? 0.90 : (_isHovered ? 1.08 : 1.0),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _isHovered ? const Color(0xFFF1F5F9) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isHovered ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered ? const Color(0x160F172A) : const Color(0x0A0F172A),
                    blurRadius: _isHovered ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                size: 16,
                color: _isHovered ? const Color(0xFF059669) : const Color(0xFF0F172A),
              ),
            ),
          ),
        ),
      ),
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
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (mounted) setState(() => _isHovered = true);
        },
        onExit: (_) {
          if (mounted) setState(() => _isHovered = false);
        },
        child: GestureDetector(
          onTapDown: (_) {
            if (mounted) setState(() => _isPressed = true);
          },
          onTapUp: (_) {
            if (mounted) setState(() => _isPressed = false);
            item.onTap();
          },
          onTapCancel: () {
            if (mounted) setState(() => _isPressed = false);
          },
          child: AnimatedScale(
            scale: _isPressed ? 0.982 : (_isHovered ? 1.006 : 1.0),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _isHovered ? 0.12 : 0.07),
                    blurRadius: _isHovered ? 22 : 14,
                    offset: Offset(0, _isHovered ? 8 : 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
                border: Border.all(
                  color: _isHovered ? const Color(0x3310B981) : Colors.black.withValues(alpha: 0.05),
                  width: _isHovered ? 1.5 : 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
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
      ),
    );
  }
}
