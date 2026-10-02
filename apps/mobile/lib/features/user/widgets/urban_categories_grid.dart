import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/post_job/post_job_state.dart';

class UrbanCategoryItem {
  final String id;
  final String title;
  final String? badge;
  final String imageUrl;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String serviceSkill;
  final bool isEmergency;

  const UrbanCategoryItem({
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

class UrbanCategoriesGrid extends ConsumerWidget {
  const UrbanCategoriesGrid({super.key});

  /// The EXACT 7 services specified:
  /// Plumber, Electrician, Phone Repair, Laptop Repair, AC Service, Carpenter, Stove Repair
  static const List<UrbanCategoryItem> categories = [
    UrbanCategoryItem(
      id: 'electrician',
      title: 'Electrician',
      badge: '15 Min',
      imageUrl: 'https://images.unsplash.com/photo-1621905251918-48416bd8575a?auto=format&fit=crop&w=400&q=80',
      icon: Icons.electrical_services_rounded,
      iconColor: Color(0xFFEA580C),
      bgColor: Color(0xFFFFF7ED),
      serviceSkill: 'Electrician',
      isEmergency: true,
    ),
    UrbanCategoryItem(
      id: 'plumber',
      title: 'Plumber',
      badge: 'Popular',
      imageUrl: 'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?auto=format&fit=crop&w=400&q=80',
      icon: Icons.plumbing_rounded,
      iconColor: Color(0xFF2563EB),
      bgColor: Color(0xFFEFF6FF),
      serviceSkill: 'Plumber',
      isEmergency: true,
    ),
    UrbanCategoryItem(
      id: 'phone_repair',
      title: 'Phone Repair',
      badge: 'Doorstep',
      imageUrl: 'https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?auto=format&fit=crop&w=400&q=80',
      icon: Icons.phone_android_rounded,
      iconColor: Color(0xFF0D9488),
      bgColor: Color(0xFFCCFBF1),
      serviceSkill: 'Phone Repair',
    ),
    UrbanCategoryItem(
      id: 'laptop_repair',
      title: 'Laptop Repair',
      badge: 'Top Rated',
      imageUrl: 'https://images.unsplash.com/photo-1588702547954-4800f964702a?auto=format&fit=crop&w=400&q=80',
      icon: Icons.laptop_mac_rounded,
      iconColor: Color(0xFF6366F1),
      bgColor: Color(0xFFEEF2FF),
      serviceSkill: 'Laptop Repair',
    ),
    UrbanCategoryItem(
      id: 'ac_service',
      title: 'AC Service',
      badge: 'Trending',
      imageUrl: 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?auto=format&fit=crop&w=400&q=80',
      icon: Icons.ac_unit_rounded,
      iconColor: Color(0xFF0284C7),
      bgColor: Color(0xFFE0F2FE),
      serviceSkill: 'AC Service',
    ),
    UrbanCategoryItem(
      id: 'carpenter',
      title: 'Carpenter',
      badge: 'Custom',
      imageUrl: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=400&q=80',
      icon: Icons.carpenter_rounded,
      iconColor: Color(0xFFD97706),
      bgColor: Color(0xFFFEF3C7),
      serviceSkill: 'Carpenter',
    ),
    UrbanCategoryItem(
      id: 'stove_repair',
      title: 'Stove Repair',
      badge: 'Instant',
      imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?auto=format&fit=crop&w=400&q=80',
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
        // Urban Company Bangalore Signature Headline: "Home services at your doorstep"
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
                    const SizedBox(height: 3),
                    Text(
                      'Verified Bangalore & Mysuru technicians • 15–30 min arrival',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        fontSize: 12,
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
        const SizedBox(height: 14),

        // Urban Company Clean Container Card for Categories
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x060F172A),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double itemWidth = (constraints.maxWidth - (3 * 8)) / 4;
                return Wrap(
                  spacing: 8,
                  runSpacing: 14,
                  alignment: WrapAlignment.start,
                  children: categories.map((cat) {
                    return SizedBox(
                      width: itemWidth,
                      child: _UrbanCategoryTile(
                        category: cat,
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

        const SizedBox(height: 12),

        // Urban Company Bangalore Proof Bar: 4.85 ★ Service Rating | 250K+ Happy Homes
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
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
                const Spacer(),
                Container(
                  width: 1,
                  height: 14,
                  color: const Color(0xFFCBD5E1),
                ),
                const Spacer(),
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
      ],
    );
  }
}

class _UrbanCategoryTile extends StatefulWidget {
  final UrbanCategoryItem category;
  final VoidCallback onTap;

  const _UrbanCategoryTile({
    required this.category,
    required this.onTap,
  });

  @override
  State<_UrbanCategoryTile> createState() => _UrbanCategoryTileState();
}

class _UrbanCategoryTileState extends State<_UrbanCategoryTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  height: 62,
                  decoration: BoxDecoration(
                    color: cat.bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cat.iconColor.withValues(alpha: 0.2),
                      width: 1.0,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Stock image with soft fade
                      Image.network(
                        cat.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              cat.icon,
                              color: cat.iconColor,
                              size: 26,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: Icon(
                              cat.icon,
                              color: cat.iconColor.withValues(alpha: 0.5),
                              size: 24,
                            ),
                          );
                        },
                      ),
                      // Soft gradient overlay so badge and category are clear
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.05),
                              Colors.black.withValues(alpha: 0.25),
                            ],
                          ),
                        ),
                      ),
                      // Bottom small icon badge
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            cat.icon,
                            size: 11,
                            color: cat.iconColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (cat.badge != null)
                  Positioned(
                    top: -5,
                    left: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cat.iconColor, cat.iconColor.withValues(alpha: 0.85)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white, width: 1.2),
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
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              cat.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
                letterSpacing: -0.2,
                height: 1.15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
