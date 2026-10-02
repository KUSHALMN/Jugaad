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
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String serviceSkill;
  final bool isEmergency;

  const UrbanCategoryItem({
    required this.id,
    required this.title,
    this.badge,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.serviceSkill,
    this.isEmergency = false,
  });
}

class UrbanCategoriesGrid extends ConsumerWidget {
  const UrbanCategoriesGrid({super.key});

  static const List<UrbanCategoryItem> categories = [
    UrbanCategoryItem(
      id: 'electrician',
      title: 'Electrician',
      badge: '15 Min',
      icon: Icons.electrical_services_rounded,
      iconColor: Color(0xFFEA580C),
      bgColor: Color(0xFFFFF7ED),
      serviceSkill: 'Electrician',
      isEmergency: true,
    ),
    UrbanCategoryItem(
      id: 'plumbing',
      title: 'Plumbing',
      badge: 'Available',
      icon: Icons.plumbing_rounded,
      iconColor: Color(0xFF2563EB),
      bgColor: Color(0xFFEFF6FF),
      serviceSkill: 'Plumber',
      isEmergency: true,
    ),
    UrbanCategoryItem(
      id: 'carpenter',
      title: 'Carpentry',
      icon: Icons.carpenter_rounded,
      iconColor: Color(0xFFD97706),
      bgColor: Color(0xFFFEF3C7),
      serviceSkill: 'Carpenter',
    ),
    UrbanCategoryItem(
      id: 'ac_repair',
      title: 'AC & Appliance',
      badge: 'Popular',
      icon: Icons.ac_unit_rounded,
      iconColor: Color(0xFF0284C7),
      bgColor: Color(0xFFE0F2FE),
      serviceSkill: 'AC Repair & Service',
    ),
    UrbanCategoryItem(
      id: 'cleaning',
      title: 'Cleaning',
      icon: Icons.cleaning_services_rounded,
      iconColor: Color(0xFF16A34A),
      bgColor: Color(0xFFF0FDF4),
      serviceSkill: 'Cleaning',
    ),
    UrbanCategoryItem(
      id: 'painting',
      title: 'Painting',
      icon: Icons.format_paint_rounded,
      iconColor: Color(0xFF9333EA),
      bgColor: Color(0xFFF3E8FF),
      serviceSkill: 'Painter',
    ),
    UrbanCategoryItem(
      id: 'mechanic',
      title: 'Mechanic',
      badge: 'On-Spot',
      icon: Icons.two_wheeler_rounded,
      iconColor: Color(0xFFE11D48),
      bgColor: Color(0xFFFFF1F2),
      serviceSkill: 'Bike Mechanic',
      isEmergency: true,
    ),
    UrbanCategoryItem(
      id: 'locksmith',
      title: 'Locksmith',
      badge: 'Instant',
      icon: Icons.vpn_key_rounded,
      iconColor: Color(0xFF0D9488),
      bgColor: Color(0xFFCCFBF1),
      serviceSkill: 'Locked Out Of Home',
      isEmergency: true,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Home Services & Repairs',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Doorstep service by verified experts',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/user/book');
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                        color: const Color(0xFF2563EB),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF2563EB),
                      size: 13,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Urban Company style 4x2 grid of modern category icons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = (constraints.maxWidth - (3 * 10)) / 4;
              return Wrap(
                spacing: 10,
                runSpacing: 14,
                children: categories.map((cat) {
                  return SizedBox(
                    width: cardWidth,
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
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x060F172A),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cat.bgColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        cat.icon,
                        color: cat.iconColor,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                if (cat.badge != null)
                  Positioned(
                    top: -5,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cat.iconColor, cat.iconColor.withValues(alpha: 0.85)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: cat.iconColor.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        cat.badge!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              cat.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
                letterSpacing: -0.2,
                height: 1.2,
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
