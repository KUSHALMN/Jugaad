import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/post_job/post_job_state.dart';

class UrbanPromoCarousel extends ConsumerStatefulWidget {
  const UrbanPromoCarousel({super.key});

  @override
  ConsumerState<UrbanPromoCarousel> createState() => _UrbanPromoCarouselState();
}

class _UrbanPromoCarouselState extends ConsumerState<UrbanPromoCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % 3;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
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
    return Column(
      children: [
        SizedBox(
          height: 156,
          child: PageView(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            children: [
              // BANNER 1: Urban Company Assured Black & Gold Luxury
              _buildPromoCard(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                tagText: 'JUGAAD ASSURED ★',
                tagBg: const Color(0xFFD97706),
                title: 'Professional Home Services at Doorstep',
                subtitle: '100% Background-checked • 30-Day Warranty • Insurance Cover',
                buttonText: 'Book Assured Pro',
                onButtonTap: () {
                  HapticFeedback.mediumImpact();
                  context.push('/user/book');
                },
                accentIcon: Icons.verified_user_rounded,
                accentColor: const Color(0xFFF59E0B),
              ),

              // BANNER 2: 15-Min Instant Dispatch Crimson
              _buildPromoCard(
                gradient: const LinearGradient(
                  colors: [Color(0xFF991B1B), Color(0xFFE11D48)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                tagText: 'INSTANT 15-MIN DISPATCH ⚡',
                tagBg: const Color(0xFFFFF1F2),
                tagTextColor: const Color(0xFFE11D48),
                title: 'Emergency Breakdown? We Arrive Fast',
                subtitle: 'Electrician, Plumber or Locks within 30 minutes in Bangalore & Mysuru',
                buttonText: 'Request Instant Help',
                onButtonTap: () {
                  HapticFeedback.heavyImpact();
                  ref.read(postJobProvider.notifier).reset();
                  ref.read(postJobProvider.notifier).setEmergency(true);
                  context.push('/user/post-job/step1');
                },
                accentIcon: Icons.bolt_rounded,
                accentColor: const Color(0xFFFDE047),
              ),

              // BANNER 3: Welcome Offer Deep Indigo
              _buildPromoCard(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                tagText: 'SPECIAL WELCOME OFFER 🏷️',
                tagBg: const Color(0xFFEFF6FF),
                tagTextColor: const Color(0xFF2563EB),
                title: 'Flat ₹100 OFF On First Service',
                subtitle: 'Use code JUGAAD100 at checkout on any skilled home repair',
                buttonText: 'Claim Discount',
                onButtonTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/user/worker-search');
                },
                accentIcon: Icons.local_offer_rounded,
                accentColor: const Color(0xFF60A5FA),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final isActive = _currentPage == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 20 : 6,
              height: 5,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPromoCard({
    required Gradient gradient,
    required String tagText,
    required Color tagBg,
    Color tagTextColor = Colors.white,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onButtonTap,
    required IconData accentIcon,
    required Color accentColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background ambient glow / icon watermark
            Positioned(
              right: -14,
              bottom: -16,
              child: Icon(
                accentIcon,
                size: 130,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: tagBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tagText,
                      style: GoogleFonts.plusJakartaSans(
                        color: tagTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  // Middle Copy
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),

                  // Bottom Action Button
                  GestureDetector(
                    onTap: onButtonTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            buttonText,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF0F172A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
