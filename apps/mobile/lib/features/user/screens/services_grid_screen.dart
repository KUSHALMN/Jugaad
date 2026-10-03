import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/config/services_list.dart';
import '../../../core/providers/services_provider.dart';
import 'post_job/post_job_state.dart';

class ServicesGridScreen extends ConsumerStatefulWidget {
  const ServicesGridScreen({super.key});

  @override
  ConsumerState<ServicesGridScreen> createState() => _ServicesGridScreenState();
}

class _ServicesGridScreenState extends ConsumerState<ServicesGridScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Home', 'Tech'];

  Color _getCategoryColor(String category, String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('electric') || lowerTitle.contains('power')) {
      return const Color(0xFFEA580C);
    } else if (lowerTitle.contains('plumb') || lowerTitle.contains('water')) {
      return const Color(0xFF2563EB);
    } else if (lowerTitle.contains('ac') || lowerTitle.contains('cool')) {
      return const Color(0xFF0284C7);
    } else if (lowerTitle.contains('carpenter')) {
      return const Color(0xFFD97706);
    } else if (lowerTitle.contains('stove') || lowerTitle.contains('gas') || lowerTitle.contains('fire')) {
      return const Color(0xFFE11D48);
    } else if (lowerTitle.contains('phone')) {
      return const Color(0xFF0D9488);
    } else if (lowerTitle.contains('laptop')) {
      return const Color(0xFF6366F1);
    }
    return AppColors.primary;
  }

  String _getServiceImage(String id) {
    switch (id.toLowerCase()) {
      case 'electrician':
        return 'assets/images/service_electrician.jpg';
      case 'plumber':
        return 'assets/images/service_plumber.jpg';
      case 'laptop_repair':
        return 'assets/images/service_laptop.jpg';
      case 'phone_repair':
        return 'assets/images/banner_tech_apple.jpg';
      case 'ac_service':
        return 'assets/images/banner_ac_apple.jpg';
      case 'stove_repair':
        return 'assets/images/banner_stove_apple.jpg';
      case 'carpenter':
        return 'assets/images/banner_tools_apple.jpg';
      default:
        return 'assets/images/banner_tools_apple.jpg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(servicesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Services',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Select a specialist for instant booking',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            // Filter Pills
            Container(
              height: 44,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 2.0),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF2563EB) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    const BoxShadow(
                                      color: Color(0x332563EB),
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ]
                                : [
                                    const BoxShadow(
                                      color: Color(0x05000000),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: Text(
                              category,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Grid containing services
            Expanded(
              child: Builder(
                builder: (context) {
                  final servicesList = servicesAsync.value ?? kAllServices;
                  const allowedIds = {
                    'electrician',
                    'plumber',
                    'phone_repair',
                    'laptop_repair',
                    'ac_service',
                    'carpenter',
                    'stove_repair',
                  };
                  final coreServices = servicesList
                      .where((s) => allowedIds.contains(s.id.toLowerCase()))
                      .toList();
                  final baseList = coreServices.isNotEmpty ? coreServices : kAllServices;
                  final filteredServices = _selectedCategory == 'All'
                      ? baseList
                      : baseList.where((s) => s.category == _selectedCategory).toList();
                  return _buildGrid(filteredServices);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<ServiceDef> services) {
    if (services.isEmpty) {
      return Center(
        child: Text(
          'No services found in this category',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount;
    final double childAspectRatio;

    if (screenWidth >= 1024) {
      crossAxisCount = 3;
      childAspectRatio = 0.95;
    } else if (screenWidth >= 650) {
      crossAxisCount = 2;
      childAspectRatio = 0.92;
    } else {
      crossAxisCount = 2;
      childAspectRatio = 0.74;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: GridView.builder(
          key: ValueKey(_selectedCategory),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14.0,
            crossAxisSpacing: 14.0,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index];
            return RepaintBoundary(
              child: _buildModernServiceCard(service, index),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModernServiceCard(ServiceDef service, int index) {
    final Color accentColor = _getCategoryColor(service.category, service.title);
    final String imagePath = _getServiceImage(service.id);

    return _ServiceCardItem(
      service: service,
      accentColor: accentColor,
      imagePath: imagePath,
      onTap: () {
        HapticFeedback.mediumImpact();
        ref.read(postJobProvider.notifier).reset();
        ref.read(postJobProvider.notifier).setSkill(service.title);
        ref.read(postJobProvider.notifier).setUrgency('now');
        ref.read(postJobProvider.notifier).setScheduledAt(null);
        context.push('/user/post-job/step2');
      },
    );
  }
}

class _ServiceCardItem extends StatefulWidget {
  final ServiceDef service;
  final Color accentColor;
  final String imagePath;
  final VoidCallback onTap;

  const _ServiceCardItem({
    required this.service,
    required this.accentColor,
    required this.imagePath,
    required this.onTap,
  });

  @override
  State<_ServiceCardItem> createState() => _ServiceCardItemState();
}

class _ServiceCardItemState extends State<_ServiceCardItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final accentColor = widget.accentColor;

    final double scale = _isPressed ? 0.97 : (_isHovered ? 1.02 : 1.0);

    return RepaintBoundary(
      child: MouseRegion(
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
            scale: scale,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _isHovered
                      ? accentColor.withValues(alpha: 0.50)
                      : const Color(0xFFE2E8F0),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered
                        ? accentColor.withValues(alpha: 0.14)
                        : const Color(0x080F172A),
                    blurRadius: _isHovered ? 16 : 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top High-Resolution Service Image with Floating Badges
                  Expanded(
                    flex: 12,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          widget.imagePath,
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFFF1F5F9),
                            child: Center(
                              child: Icon(service.icon, color: accentColor, size: 28),
                            ),
                          ),
                        ),
                      // Subtle gradient mask
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.25),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.45),
                            ],
                          ),
                        ),
                      ),
                      // Top Left: Category Icon Badge
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x15000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            service.icon,
                            color: accentColor,
                            size: 16,
                          ),
                        ),
                      ),
                      // Top Right: Rating Pill
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 12),
                              const SizedBox(width: 3),
                              Text(
                                service.rating.toStringAsFixed(1),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Content: Title, Price, Category & Book Button
                Expanded(
                  flex: 11,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                                height: 1.15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${service.priceMin.toInt()} - ₹${service.priceMax.toInt()} est.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),

                        // Bottom Row: Category Chip & Urban Company Book Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                service.category,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x18000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Book',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 11,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
