import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

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
  final List<String> _categories = ['All', 'Home', 'Tech', 'Vehicle', 'Beauty'];

  Color _getCategoryColor(String category, String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('electric') || lowerTitle.contains('power')) {
      return const Color(0xFFEA580C); // Orange
    } else if (lowerTitle.contains('plumb') || lowerTitle.contains('water')) {
      return const Color(0xFF2563EB); // Blue
    } else if (lowerTitle.contains('ac') || lowerTitle.contains('cool')) {
      return const Color(0xFF0284C7); // Sky Blue
    } else if (lowerTitle.contains('key') || lowerTitle.contains('lock')) {
      return const Color(0xFF16A34A); // Green
    } else if (category == 'Tech' || lowerTitle.contains('laptop') || lowerTitle.contains('phone')) {
      return const Color(0xFF9333EA); // Purple
    } else if (category == 'Beauty' || lowerTitle.contains('salon') || lowerTitle.contains('spa')) {
      return const Color(0xFFE11D48); // Rose
    } else if (category == 'Vehicle' || lowerTitle.contains('car') || lowerTitle.contains('bike')) {
      return const Color(0xFFD97706); // Amber
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(servicesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'All Services',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontSize: 19,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Pills
            Container(
              height: 48,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              category,
                              style: GoogleFonts.inter(
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
                  final filteredServices = _selectedCategory == 'All'
                      ? servicesList
                      : servicesList.where((s) => s.category == _selectedCategory).toList();
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
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
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
      crossAxisCount = 4;
      childAspectRatio = 1.20;
    } else if (screenWidth >= 600) {
      crossAxisCount = 3;
      childAspectRatio = 1.10;
    } else {
      crossAxisCount = 2;
      childAspectRatio = 0.92;
    }

    return GridView.builder(
      key: ValueKey(_selectedCategory),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12.0,
        crossAxisSpacing: 12.0,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return _buildModernServiceCard(service, index);
      },
    );
  }

  Widget _buildModernServiceCard(ServiceDef service, int index) {
    final Color accentColor = _getCategoryColor(service.category, service.title);
    final Color bgTint = accentColor.withValues(alpha: 0.08);

    return _ServiceCardItem(
      service: service,
      accentColor: accentColor,
      bgTint: bgTint,
      onTap: () {
        HapticFeedback.mediumImpact();
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
  final Color bgTint;
  final VoidCallback onTap;

  const _ServiceCardItem({
    required this.service,
    required this.accentColor,
    required this.bgTint,
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
    final double translateY = _isHovered ? -4.0 : 0.0;

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
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, translateY, 0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFFAFBFC),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered
                    ? accentColor.withValues(alpha: 0.50)
                    : const Color(0xFFECECEC),
                width: _isHovered ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? accentColor.withValues(alpha: 0.14)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: _isHovered ? 20 : 12,
                  offset: _isHovered ? const Offset(0, 8) : const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Icon Container + Rating Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: widget.bgTint,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.15),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            service.icon,
                            color: accentColor,
                            size: 20,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 12),
                              const SizedBox(width: 3),
                              Text(
                                service.rating.toStringAsFixed(1),
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Service Title
                    Text(
                      service.title,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Price Range Estimate
                    Text(
                      '₹${service.priceMin.toInt()} - ₹${service.priceMax.toInt()} est.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),

                    const Spacer(),

                    // Book Action Button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
                      decoration: BoxDecoration(
                        color: _isHovered ? accentColor : accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Book Now',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _isHovered ? Colors.white : accentColor,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedSlide(
                            offset: _isHovered ? const Offset(0.25, 0) : Offset.zero,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 13,
                              color: _isHovered ? Colors.white : accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
