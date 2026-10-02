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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Headline: "Home services at your doorstep"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.6,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Verified Bangalore & Mysuru technicians • 15–30 min arrival',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/user/book');
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                        fontSize: 12.5,
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
        const SizedBox(height: 16),

        // Spacious Container Card for Categories
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
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
              builder: (context, constraints) {
                // If wide desktop (>= 740px), show all 7 categories in a single balanced row!
                // Otherwise (tablet/mobile), use 4 columns with spacious squircle proportions.
                final bool isDesktop = constraints.maxWidth >= 740;
                final int columns = isDesktop ? 7 : 4;
                final double spacing = isDesktop ? 12 : 10;
                final double itemWidth = (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: 18,
                  alignment: isDesktop ? WrapAlignment.spaceBetween : WrapAlignment.center,
                  children: categories.map((cat) {
                    return SizedBox(
                      width: itemWidth,
                      child: _CategoryTile(
                        category: cat,
                        isDesktop: isDesktop,
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

        const SizedBox(height: 16),

        // Bangalore & Mysuru Proof Bar: 4.85 ★ Service Rating | 250K+ Happy Homes
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 19),
                    const SizedBox(width: 5),
                    Text(
                      '4.85',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Service Rating*',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 1,
                  height: 16,
                  color: const Color(0xFFCBD5E1),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_alt_rounded, color: Color(0xFF2563EB), size: 17),
                    const SizedBox(width: 6),
                    Text(
                      '250K+',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Happy Homes*',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
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
      ],
    );
  }
}

class _CategoryTile extends StatefulWidget {
  final CategoryGridItem category;
  final bool isDesktop;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
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
    final double cardHeight = widget.isDesktop ? 96.0 : 76.0;

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
                  borderRadius: BorderRadius.circular(widget.isDesktop ? 18 : 14),
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
                    // Apple asset image with subtle soft fade
                    Image.asset(
                      cat.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            cat.icon,
                            color: cat.iconColor,
                            size: widget.isDesktop ? 32 : 26,
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
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.isDesktop ? 7 : 5,
                            vertical: widget.isDesktop ? 2.5 : 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [cat.iconColor, cat.iconColor.withValues(alpha: 0.90)],
                            ),
                            borderRadius: BorderRadius.circular(6),
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
                              fontSize: widget.isDesktop ? 8.5 : 7.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    // Bottom right icon badge
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: EdgeInsets.all(widget.isDesktop ? 5 : 3.5),
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
                          size: widget.isDesktop ? 13 : 11,
                          color: cat.iconColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Text(
                cat.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: widget.isDesktop ? 12.5 : 11,
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

