import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/post_job/post_job_state.dart';

class CategoryGridItem {
  final String id;
  final String title;
  final String? badge;
  final String imageUrl;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String serviceSkill;
  final bool isEmergency;

  const CategoryGridItem({
    required this.id,
    required this.title,
    this.badge,
    required this.imageUrl,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.serviceSkill,
    this.isEmergency = false,
  });
}

class HomeCategoriesGrid extends ConsumerWidget {
  const HomeCategoriesGrid({super.key});

  /// The EXACT 7 services specified:
  /// Plumber, Electrician, Phone Repair, Laptop Repair, AC Service, Carpenter, Stove Repair
  static const List<CategoryGridItem> categories = [
    CategoryGridItem(
      id: 'electrician',
      title: 'Electrician',
      badge: '15 Min',
      imageUrl: 'assets/images/banner_tools_apple.jpg',
      icon: Icons.electrical_services_rounded,
      iconColor: Color(0xFFEA580C),
      bgColor: Color(0xFFFFF7ED),
      serviceSkill: 'Electrician',
      isEmergency: true,
    ),
    CategoryGridItem(
      id: 'plumber',
      title: 'Plumber',
      badge: 'Popular',
      imageUrl: 'assets/images/banner_tools_apple.jpg',
      icon: Icons.plumbing_rounded,
      iconColor: Color(0xFF2563EB),
      bgColor: Color(0xFFEFF6FF),
      serviceSkill: 'Plumber',
      isEmergency: true,
    ),
    CategoryGridItem(
      id: 'phone_repair',
      title: 'Phone Repair',
      badge: 'Doorstep',
      imageUrl: 'assets/images/banner_tech_apple.jpg',
      icon: Icons.phone_android_rounded,
      iconColor: Color(0xFF0D9488),
      bgColor: Color(0xFFCCFBF1),
      serviceSkill: 'Phone Repair',
    ),
    CategoryGridItem(
      id: 'laptop_repair',
      title: 'Laptop Repair',
      badge: 'Top Rated',
      imageUrl: 'assets/images/banner_tech_apple.jpg',
      icon: Icons.laptop_mac_rounded,
      iconColor: Color(0xFF6366F1),
      bgColor: Color(0xFFEEF2FF),
      serviceSkill: 'Laptop Repair',
    ),
    CategoryGridItem(
      id: 'ac_service',
      title: 'AC Service',
      badge: 'Trending',
      imageUrl: 'assets/images/banner_ac_apple.jpg',
      icon: Icons.ac_unit_rounded,
      iconColor: Color(0xFF0284C7),
      bgColor: Color(0xFFE0F2FE),
      serviceSkill: 'AC Service',
    ),
    CategoryGridItem(
      id: 'carpenter',
      title: 'Carpenter',
      badge: 'Custom',
      imageUrl: 'assets/images/banner_tools_apple.jpg',
      icon: Icons.carpenter_rounded,
      iconColor: Color(0xFFD97706),
      bgColor: Color(0xFFFEF3C7),
      serviceSkill: 'Carpenter',
    ),
    CategoryGridItem(
      id: 'stove_repair',
      title: 'Stove Repair',
      badge: 'Instant',
      imageUrl: 'assets/images/banner_stove_apple.jpg',
      icon: Icons.local_fire_department_rounded,
      iconColor: Color(0xFFE11D48),
      bgColor: Color(0xFFFFF1F2),
      serviceSkill: 'Stove Repair',
      isEmergency: true,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, rootConstraints) {
        final double screenWidth = rootConstraints.maxWidth;
        final bool isSmallMobile = screenWidth < 360;
        final bool isTablet = screenWidth >= 600 && screenWidth < 900;
        final bool isDesktop = screenWidth >= 900;

        final double horizontalMargin = isDesktop
            ? 24.0
            : (isSmallMobile ? 12.0 : 16.0);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Headline: "Home services at your doorstep"
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Home services at your doorstep',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: isDesktop ? 22 : (isSmallMobile ? 17 : 19.5),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.6,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Verified Bangalore & Mysuru technicians • 15–30 min arrival',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: isDesktop ? 13 : (isSmallMobile ? 11 : 12),
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context.push('/user/book');
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallMobile ? 10 : 14,
                            vertical: isSmallMobile ? 6 : 8,
                          ),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View All',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF1D4ED8),
                                fontSize: isSmallMobile ? 11.5 : 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFF1D4ED8),
                              size: 13,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isSmallMobile ? 12 : 16),

                // Responsive Container Card for Categories
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 22 : (isSmallMobile ? 12 : 16),
                      vertical: isDesktop ? 20 : (isSmallMobile ? 14 : 18),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x060F172A),
                          blurRadius: 20,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, cardConstraints) {
                        final double availableWidth = cardConstraints.maxWidth;
                        // On wide screens (>= 680), show all 7 categories in a balanced single row!
                        // On mobile, use 4 columns with centered second row.
                        final bool showSingleRow = availableWidth >= 680;
                        final int columns = showSingleRow ? 7 : 4;
                        final double spacing = showSingleRow
                            ? 12.0
                            : (isSmallMobile ? 8.0 : 10.0);
                        final double runSpacing = showSingleRow ? 0.0 : (isSmallMobile ? 14.0 : 18.0);
                        final double itemWidth = (availableWidth - ((columns - 1) * spacing)) / columns;

                        // Responsive height & font size proportional to itemWidth
                        final double cardHeight = showSingleRow
                            ? (itemWidth * 0.82).clamp(84.0, 105.0)
                            : (itemWidth * 0.96).clamp(64.0, 86.0);

                        final double titleFontSize = showSingleRow
                            ? (isDesktop ? 12.5 : 11.5)
                            : (isSmallMobile ? 10.2 : 11.5);

                        return Wrap(
                          spacing: spacing,
                          runSpacing: runSpacing,
                          alignment: showSingleRow ? WrapAlignment.spaceBetween : WrapAlignment.center,
                          children: categories.map((cat) {
                            return SizedBox(
                              width: itemWidth,
                              child: _CategoryTile(
                                category: cat,
                                cardHeight: cardHeight,
                                titleFontSize: titleFontSize,
                                isDesktop: isDesktop || isTablet,
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  ref.read(postJobProvider.notifier).reset();
                                  ref.read(postJobProvider.notifier).setSkill(cat.serviceSkill);
                                  if (cat.isEmergency) {
                                    ref.read(postJobProvider.notifier).setEmergency(true);
                                    ref.read(postJobProvider.notifier).setUrgency('now');
                                    context.push('/user/post-job/step2');
                                  } else {
                                    context.push('/user/worker-search?service=${Uri.encodeComponent(cat.serviceSkill)}');
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ),

                SizedBox(height: isSmallMobile ? 12 : 16),

                // Proof Bar: 4.85 ★ Service Rating | 250K+ Happy Homes
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallMobile ? 12 : 16,
                      vertical: isSmallMobile ? 9 : 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
                              const SizedBox(width: 4),
                              Text(
                                '4.85',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Service Rating*',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 24),
                          Container(
                            width: 1,
                            height: 14,
                            color: const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(width: 24),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_alt_rounded, color: Color(0xFF2563EB), size: 16),
                              const SizedBox(width: 5),
                              Text(
                                '250K+',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Happy Homes*',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoryTile extends StatefulWidget {
  final CategoryGridItem category;
  final double cardHeight;
  final double titleFontSize;
  final bool isDesktop;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.cardHeight,
    required this.titleFontSize,
    required this.isDesktop,
    required this.onTap,
  });

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final cardHeight = widget.cardHeight;
    final isCompact = cardHeight < 76;

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
          scale: _isPressed ? 0.94 : (_isHovered ? 1.03 : 1.0),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                height: cardHeight,
                decoration: BoxDecoration(
                  color: cat.bgColor,
                  borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
                  border: Border.all(
                    color: _isHovered
                        ? cat.iconColor.withValues(alpha: 0.6)
                        : cat.iconColor.withValues(alpha: 0.20),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isHovered
                          ? cat.iconColor.withValues(alpha: 0.22)
                          : cat.iconColor.withValues(alpha: 0.08),
                      blurRadius: _isHovered ? 14 : 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Asset image
                    Image.asset(
                      cat.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            cat.icon,
                            color: cat.iconColor,
                            size: isCompact ? 22 : (widget.isDesktop ? 30 : 25),
                          ),
                        );
                      },
                    ),
                    // Soft gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.04),
                            Colors.black.withValues(alpha: 0.28),
                          ],
                        ),
                      ),
                    ),
                    // Inset Badge on top left
                    if (cat.badge != null)
                      Positioned(
                        top: isCompact ? 4 : 6,
                        left: isCompact ? 4 : 6,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 4 : (widget.isDesktop ? 7 : 5),
                            vertical: isCompact ? 1.5 : (widget.isDesktop ? 2.5 : 2),
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [cat.iconColor, cat.iconColor.withValues(alpha: 0.90)],
                            ),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: Colors.white, width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: cat.iconColor.withValues(alpha: 0.35),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            cat.badge!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: isCompact ? 7.0 : (widget.isDesktop ? 8.5 : 7.5),
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    // Bottom right icon badge
                    Positioned(
                      bottom: isCompact ? 4 : 6,
                      right: isCompact ? 4 : 6,
                      child: Container(
                        padding: EdgeInsets.all(isCompact ? 2.5 : (widget.isDesktop ? 5 : 3.5)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          cat.icon,
                          size: isCompact ? 9.5 : (widget.isDesktop ? 13 : 11),
                          color: cat.iconColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                cat.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: widget.titleFontSize,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                  height: 1.15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


