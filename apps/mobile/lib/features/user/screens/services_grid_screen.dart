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
            const SizedBox(height: 4),
            // Filter Pills
            Container(
              height: 44,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
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
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                                fontSize: 12.5,
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
      childAspectRatio = 1.45;
    } else if (screenWidth >= 600) {
      crossAxisCount = 3;
      childAspectRatio = 1.35;
    } else {
      // Mobile: compact 2-column SaaS card with zero empty white gap
      crossAxisCount = 2;
      childAspectRatio = 1.15;
    }

    return GridView.builder(
      key: ValueKey(_selectedCategory),
      physics: const BouncingScrollPhysics(),
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
        return RepaintBoundary(
          child: _buildModernServiceCard(service, index),
        );
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
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isHovered
                    ? accentColor.withValues(alpha: 0.50)
                    : const Color(0xFFE2E8F0),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? accentColor.withValues(alpha: 0.12)
                      : const Color(0x060F172A),
                  blurRadius: _isHovered ? 16 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Row: Icon Container + Rating Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: widget.bgTint,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.20),
                              width: 1,
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
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFFDE68A),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 13),
                              const SizedBox(width: 2.5),
                              Text(
                                service.rating.toStringAsFixed(1),
                                style: GoogleFonts.plusJakartaSans(
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

                    // Middle: Service Title & Pricing estimate
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
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${service.priceMin.toInt()} - ₹${service.priceMax.toInt()} est.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),

                    // Bottom Row: Category chip & compact Book button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            service.category,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Book',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 11,
                                color: accentColor,
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
          ),
        ),
      ),
    );
  }
}
