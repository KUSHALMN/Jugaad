import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import 'worker_search_provider.dart';

class WorkerSearchScreen extends ConsumerStatefulWidget {
  final String? initialService;
  const WorkerSearchScreen({super.key, this.initialService});

  @override
  ConsumerState<WorkerSearchScreen> createState() => _WorkerSearchScreenState();
}

class _WorkerSearchScreenState extends ConsumerState<WorkerSearchScreen> {
  final ScrollController _scrollController = ScrollController();
  dynamic _selectedWorker;
  bool _isPickerShowing = false;

  final List<Map<String, dynamic>> _mysorePresets = [
    {'name': 'Mysore Palace', 'lat': 12.3051, 'lng': 76.6551},
    {'name': 'Gokulam', 'lat': 12.3308, 'lng': 76.6267},
    {'name': 'Vijayanagar', 'lat': 12.3374, 'lng': 76.6111},
    {'name': 'Kuvempunagar', 'lat': 12.2905, 'lng': 76.6277},
    {'name': 'Hebbal Industrial Area', 'lat': 12.3562, 'lng': 76.6047},
  ];

  final List<String> _services = [
    'All',
    'Electrician',
    'Plumber',
    'Laptop Repair',
    'Phone Repair',
    'Carpenter',
    'Painter',
    'AC Service',
    'Cleaning',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(workerSearchProvider.notifier).checkAndResolveLocation();
      if (mounted && widget.initialService != null && widget.initialService!.isNotEmpty) {
        ref.read(workerSearchProvider.notifier).updateServiceType(widget.initialService!);
      }
    });

    _scrollController.addListener(() {
      final state = ref.read(workerSearchProvider);
      if (_scrollController.hasClients &&
          _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!state.isLoading && !state.isLoadingMore && state.hasMore) {
          ref.read(workerSearchProvider.notifier).search();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showManualLocationPicker() {
    if (_isPickerShowing) return;
    _isPickerShowing = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Select Zone in Mysuru',
                style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select one of our active zones to find available workers nearby:',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: _mysorePresets.map((preset) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFEEEEEE)),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.location_on_rounded, color: AppColors.primary),
                        title: Text(
                          preset['name'],
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Coords: ${preset['lat'].toStringAsFixed(4)}, ${preset['lng'].toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () {
                          ref.read(workerSearchProvider.notifier).selectManualLocation(
                            preset['lat'],
                            preset['lng'],
                            preset['name'],
                          );
                          Navigator.pop(context);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _isPickerShowing = false;
        });
      }
    });
  }

  void _onWorkerCardTap(dynamic worker) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedWorker = worker;
    });
    _showWorkerDetailSheet(worker);
  }

  void _showWorkerDetailSheet(dynamic worker) {
    final String name = worker['name'] ?? 'Worker';
    final double rating = (worker['rating'] as num? ?? 0.0).toDouble();
    final double distanceMeters = (worker['distance_m'] as num? ?? worker['distance_meters'] as num? ?? 0.0).toDouble();
    final String rawCategory = (worker['category'] ?? worker['work_category'] ?? 'Service Expert').toString();
    final String category = rawCategory.replaceAll('_', ' ').split(' ').map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '').join(' ');
    final bool isVerified = worker['is_verified'] ?? worker['isVerified'] ?? true;
    final String? profilePhoto = worker['profile_photo'] ?? worker['id_document_url'];
    final double? hourlyRate = (worker['hourly_rate'] ?? worker['rate_per_hour'] as num?)?.toDouble();
    final int completedJobs = (worker['total_completed_jobs'] ?? worker['total_jobs'] ?? worker['totalJobsCompleted'] ?? 0) as int;

    final int etaMins = (distanceMeters > 0)
        ? ((distanceMeters / 400).ceil() + 4).clamp(5, 45)
        : 15;

    final distanceText = distanceMeters > 0
        ? (distanceMeters >= 1000 ? '${(distanceMeters / 1000).toStringAsFixed(1)} km away' : '${distanceMeters.toStringAsFixed(0)} m away')
        : 'Mysuru Citywide';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: (profilePhoto != null && profilePhoto.isNotEmpty)
                      ? CachedNetworkImageProvider(profilePhoto)
                      : null,
                  child: (profilePhoto == null || profilePhoto.isEmpty)
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'W',
                          style: GoogleFonts.dmSans(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, color: AppColors.primary, size: 18),
                          ]
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(category, style: GoogleFonts.dmSans(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (rating > 0 && completedJobs > 0) ...[
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              ' ($completedJobs jobs)',
                              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'NEW PRO',
                                style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ],
                          const SizedBox(width: 12),
                          const Icon(Icons.near_me, color: AppColors.primary, size: 16),
                          const SizedBox(width: 4),
                          Text(distanceText, style: GoogleFonts.dmSans(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('ESTIMATED ETA', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('~$etaMins mins', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                  Container(width: 1, height: 30, color: Colors.blue.withValues(alpha: 0.2)),
                  Column(
                    children: [
                      Text('RATE', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(hourlyRate != null && hourlyRate > 0 ? '₹${hourlyRate.toInt()}/hr' : 'Standard', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                    ],
                  ),
                  Container(width: 1, height: 30, color: Colors.blue.withValues(alpha: 0.2)),
                  Column(
                    children: [
                      Text('STATUS', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Available', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  final workerId = worker['id']?.toString() ?? '';
                  context.push('/user/post-job/step1?category=${Uri.encodeComponent(rawCategory)}&worker_id=${Uri.encodeComponent(workerId)}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Book $name Now', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WorkerSearchState>(workerSearchProvider, (previous, next) {
      if (next.errorMessage != null &&
          (next.errorMessage!.contains('permission') ||
           next.errorMessage!.contains('denied') ||
           next.errorMessage!.contains('disabled') ||
           next.errorMessage!.contains('Failed to get location')) &&
          !next.isResolvingLocation &&
          next.lat == 0.0 &&
          next.lng == 0.0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showManualLocationPicker();
        });
      }
    });

    final state = ref.watch(workerSearchProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Find a Worker',
          style: GoogleFonts.syne(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded, color: AppColors.primary),
            tooltip: 'Recenter GPS',
            onPressed: () {
              HapticFeedback.mediumImpact();
              ref.read(workerSearchProvider.notifier).checkAndResolveLocation();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Category selector strip
            Container(
              height: 48,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _services.length,
                itemBuilder: (context, index) {
                  final service = _services[index];
                  final filterVal = service == 'All' ? '' : service;
                  final isSelected = state.serviceType == filterVal;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        service,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.background,
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                        side: BorderSide(
                          color: isSelected ? Colors.transparent : const Color(0xFFE5E7EB),
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          HapticFeedback.selectionClick();
                          ref.read(workerSearchProvider.notifier).updateServiceType(filterVal);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

            // Map-First View with Draggable Bottom Sheet
            Expanded(
              child: Stack(
                children: [
                  // 1. Map Canvas View
                  Positioned.fill(
                    child: _buildMapCanvas(state),
                  ),

                  // 2. Fallback Banner if citywide fallback
                  if (state.isCitywideFallback || (state.total == 0 && state.workers.isNotEmpty))
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                state.serviceType.isNotEmpty
                                    ? 'No nearest ${state.serviceType}s within 5km — showing top-rated ${state.serviceType}s in Mysore.'
                                    : 'No nearest workers within 5km — showing top-rated workers in Mysore.',
                                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 3. Draggable Scrollable Sheet (Uber / Rapido Style)
                  DraggableScrollableSheet(
                    initialChildSize: 0.45,
                    minChildSize: 0.18,
                    maxChildSize: 0.88,
                    builder: (context, scrollController) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: _buildBottomSheetContent(state, scrollController),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapCanvas(WorkerSearchState state) {
    final categoryName = state.serviceType.isEmpty ? 'Workers' : state.serviceType;
    return Container(
      color: const Color(0xFFE8ECEF),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background grid map pattern simulation
          CustomPaint(
            size: Size.infinite,
            painter: _GridMapPainter(),
          ),

          // Search radar pulse when loading
          if (state.isLoading || state.isResolvingLocation)
            LocalPulsingRadar(
              color: AppColors.primary,
              serviceType: categoryName,
            )
          else ...[
            // User location pin marker
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                  ),
                ),
              ),
            ),

            // Worker pins positioned around user pin
            ...List.generate(state.workers.length.clamp(0, 8), (index) {
              final w = state.workers[index];
              final isSelected = _selectedWorker != null && _selectedWorker['id'] == w['id'];
              final name = w['name'] ?? 'Worker';
              final double dx = (index % 2 == 0 ? 1 : -1) * (40 + (index * 25));
              final double dy = (index < 4 ? -1 : 1) * (30 + (index * 20));

              return Transform.translate(
                offset: Offset(dx, dy),
                child: GestureDetector(
                  onTap: () => _onWorkerCardTap(w),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                      border: Border.all(color: isSelected ? Colors.white : AppColors.primary, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_pin_circle_rounded, color: isSelected ? Colors.white : AppColors.primary, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          name,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomSheetContent(WorkerSearchState state, ScrollController scrollController) {
    if (state.isLoading) {
      return _buildScanningState(state, scrollController);
    }

    if (state.workers.isEmpty) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 32),
          const Icon(Icons.search_off_rounded, color: Colors.grey, size: 56),
          const SizedBox(height: 16),
          Text(
            'No Workers Found Nearby',
            textAlign: TextAlign.center,
            style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try selecting a different service category or zone.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: AppColors.textSecondary),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: state.workers.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${state.workers.length} ${state.serviceType.isEmpty ? 'Workers' : '${state.serviceType}s'} Available',
                    style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  TextButton.icon(
                    onPressed: _showManualLocationPicker,
                    icon: const Icon(Icons.location_on, size: 16, color: AppColors.primary),
                    label: Text(state.activeLocationName, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          );
        }

        final w = state.workers[index - 1];
        return RepaintBoundary(
          child: _buildWorkerCard(w),
        );
      },
    );
  }

  Widget _buildWorkerCard(dynamic worker) {
    final String name = worker['name'] ?? 'Worker';
    final double rating = (worker['rating'] as num? ?? 0.0).toDouble();
    final double distanceMeters = (worker['distance_m'] as num? ?? worker['distance_meters'] as num? ?? 0.0).toDouble();
    final String rawCategory = (worker['category'] ?? worker['work_category'] ?? 'Worker').toString();
    final String category = rawCategory.replaceAll('_', ' ').split(' ').map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '').join(' ');
    final bool isVerified = worker['is_verified'] ?? worker['isVerified'] ?? true;
    final String? profilePhoto = worker['profile_photo'] ?? worker['id_document_url'];
    final double? hourlyRate = (worker['hourly_rate'] ?? worker['rate_per_hour'] as num?)?.toDouble();
    final int completedJobs = (worker['total_completed_jobs'] ?? worker['total_jobs'] ?? worker['totalJobsCompleted'] ?? 0) as int;

    final distanceText = distanceMeters > 0
        ? (distanceMeters >= 1000 ? '${(distanceMeters / 1000).toStringAsFixed(1)} km away' : '${distanceMeters.toStringAsFixed(0)} m away')
        : 'Mysuru';

    final int etaMins = distanceMeters > 0 ? ((distanceMeters / 400).ceil() + 4).clamp(5, 45) : 15;
    final isSelected = _selectedWorker != null && _selectedWorker['id'] == worker['id'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isSelected ? AppColors.primary : const Color(0xFFEEEEEE), width: isSelected ? 2 : 1),
      ),
      child: ListTile(
        onTap: () => _onWorkerCardTap(worker),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          backgroundImage: (profilePhoto != null && profilePhoto.isNotEmpty)
              ? CachedNetworkImageProvider(profilePhoto)
              : null,
          child: (profilePhoto == null || profilePhoto.isEmpty)
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'W',
                  style: GoogleFonts.dmSans(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.syne(fontWeight: FontWeight.bold, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isVerified) const Icon(Icons.verified, color: AppColors.primary, size: 16),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text('$category • ETA: ~$etaMins mins', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 5),
            Row(
              children: [
                if (rating > 0 && completedJobs > 0) ...[
                  const Icon(Icons.star, color: Colors.amber, size: 14),
                  const SizedBox(width: 2),
                  Text(rating.toStringAsFixed(1), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(width: 8),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('NEW', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                  const SizedBox(width: 8),
                ],
                const Icon(Icons.near_me, color: AppColors.primary, size: 14),
                const SizedBox(width: 2),
                Text(distanceText, style: GoogleFonts.dmSans(fontSize: 11, color: Colors.grey[600])),
                if (hourlyRate != null && hourlyRate > 0) ...[
                  const SizedBox(width: 8),
                  Text('•  ₹${hourlyRate.toInt()}/hr', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                ],
              ],
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _onWorkerCardTap(worker),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          child: Text('Book', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildScanningState(WorkerSearchState state, ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _ScanningTelemetryHeader(serviceType: state.serviceType),
        const SizedBox(height: 20),
        _buildShimmerWorkerCard(),
        const SizedBox(height: 12),
        _buildShimmerWorkerCard(),
      ],
    );
  }

  Widget _buildShimmerWorkerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2F6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 130,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 90,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF2F7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 110,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF2F7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 58,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2F6),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDCDFE3)
      ..strokeWidth = 1.0;

    const double step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanningTelemetryHeader extends StatefulWidget {
  final String serviceType;
  const _ScanningTelemetryHeader({required this.serviceType});

  @override
  State<_ScanningTelemetryHeader> createState() => _ScanningTelemetryHeaderState();
}

class _ScanningTelemetryHeaderState extends State<_ScanningTelemetryHeader> {
  int _phaseIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (t) {
      if (mounted) {
        setState(() {
          _phaseIndex = (_phaseIndex + 1) % 3;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.serviceType.isEmpty ? 'worker' : widget.serviceType;
    final phases = [
      'Locating certified $service experts nearby...',
      'Scanning 5.0 km radius in active zone...',
      'Ranking by response time, verified skills & rating...',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.radar_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'RADAR TELEMETRY',
                style: GoogleFonts.syne(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0xFF10B981), blurRadius: 4, spreadRadius: 1),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'LIVE',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              phases[_phaseIndex],
              key: ValueKey(_phaseIndex),
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class LocalPulsingRadar extends StatefulWidget {
  final Color color;
  final String serviceType;
  const LocalPulsingRadar({
    super.key,
    required this.color,
    required this.serviceType,
  });

  @override
  State<LocalPulsingRadar> createState() => _LocalPulsingRadarState();
}

class _LocalPulsingRadarState extends State<LocalPulsingRadar> with TickerProviderStateMixin {
  late AnimationController _sweepController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  IconData _getServiceIcon(String service) {
    final s = service.toLowerCase().replaceAll('_', ' ');
    if (s.contains('electr') || s.contains('power') || s.contains('short')) {
      return Icons.bolt_rounded;
    } else if (s.contains('plumb') || s.contains('water') || s.contains('leak') || s.contains('pipe')) {
      return Icons.plumbing_rounded;
    } else if (s.contains('laptop') || s.contains('pc') || s.contains('computer')) {
      return Icons.laptop_chromebook_rounded;
    } else if (s.contains('phone') || s.contains('mobile')) {
      return Icons.phone_android_rounded;
    } else if (s.contains('carpent') || s.contains('wood')) {
      return Icons.handyman_rounded;
    } else if (s.contains('paint')) {
      return Icons.format_paint_rounded;
    } else if (s.contains('ac') || s.contains('cool')) {
      return Icons.ac_unit_rounded;
    } else if (s.contains('clean')) {
      return Icons.cleaning_services_rounded;
    } else if (s.contains('ro') || s.contains('purifier')) {
      return Icons.water_drop_rounded;
    } else {
      return Icons.person_search_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Radar canvas with sweep, concentric rings, and target blips
          AnimatedBuilder(
            animation: Listenable.merge([_sweepController, _pulseController]),
            builder: (context, child) {
              return CustomPaint(
                size: const Size(280, 280),
                painter: _RadarSweepPainter(
                  sweepAngle: _sweepController.value * 2 * math.pi,
                  pulseProgress: _pulseController.value,
                  radarColor: widget.color,
                ),
              );
            },
          ),

          // 2. Concentric expanding sonar wave rings
          ...List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final double delay = i * 0.33;
                final double t = (_pulseController.value - delay) % 1.0;
                final double scale = 0.8 + (t * 1.8);
                final double opacity = (1.0 - t).clamp(0.0, 0.45);

                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.color.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // 3. Central pulsing dish core
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 0.95 + 0.08 * math.sin(_pulseController.value * 2 * math.pi);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.45),
                        blurRadius: 18,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    _getServiceIcon(widget.serviceType),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              );
            },
          ),

          // 4. Glassmorphic live telemetry pill
          Positioned(
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                ],
                border: Border.all(color: widget.color.withValues(alpha: 0.3), width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0xFF10B981), blurRadius: 4, spreadRadius: 1),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE RADAR • 5.0 KM RANGE',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarSweepPainter extends CustomPainter {
  final double sweepAngle;
  final double pulseProgress;
  final Color radarColor;

  _RadarSweepPainter({
    required this.sweepAngle,
    required this.pulseProgress,
    required this.radarColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 14;

    // 1. Concentric range circle rings (25%, 50%, 75%, 100%)
    final ringPaint = Paint()
      ..color = radarColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final fraction in [0.28, 0.52, 0.76, 1.0]) {
      canvas.drawCircle(center, maxRadius * fraction, ringPaint);
    }

    // 2. Crosshair grid lines
    final crossPaint = Paint()
      ..color = radarColor.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), crossPaint);

    // 3. Rotating radar sweep beam (SweepGradient)
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          radarColor.withValues(alpha: 0.0),
          radarColor.withValues(alpha: 0.35),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sweepAngle - (math.pi / 2));
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: maxRadius),
      0.0,
      math.pi / 2,
      true,
      sweepPaint,
    );

    // Bright leading edge line
    final leadingPaint = Paint()
      ..color = radarColor.withValues(alpha: 0.8)
      ..strokeWidth = 2.0;
    final edgeX = maxRadius * math.cos(math.pi / 2);
    final edgeY = maxRadius * math.sin(math.pi / 2);
    canvas.drawLine(Offset.zero, Offset(edgeX, edgeY), leadingPaint);
    canvas.restore();

    // 4. Detected target worker blips
    final blipPositions = [
      Offset(center.dx + maxRadius * 0.48 * math.cos(0.8), center.dy + maxRadius * 0.48 * math.sin(0.8)),
      Offset(center.dx + maxRadius * 0.68 * math.cos(2.4), center.dy + maxRadius * 0.68 * math.sin(2.4)),
      Offset(center.dx + maxRadius * 0.82 * math.cos(4.1), center.dy + maxRadius * 0.82 * math.sin(4.1)),
      Offset(center.dx + maxRadius * 0.35 * math.cos(5.3), center.dy + maxRadius * 0.35 * math.sin(5.3)),
    ];

    for (int i = 0; i < blipPositions.length; i++) {
      final pos = blipPositions[i];
      final angleToBlip = math.atan2(pos.dy - center.dy, pos.dx - center.dx);
      double normalizedAngle = angleToBlip < 0 ? angleToBlip + 2 * math.pi : angleToBlip;
      double normalizedSweep = sweepAngle % (2 * math.pi);
      double diff = (normalizedSweep - normalizedAngle).abs();
      if (diff > math.pi) diff = 2 * math.pi - diff;

      // Glow intensity spikes when sweep line is near
      final double intensity = (1.0 - (diff / (math.pi / 2))).clamp(0.2, 1.0);

      final blipGlow = Paint()
        ..color = (i % 2 == 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.4 * intensity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 8 * intensity, blipGlow);

      final blipDot = Paint()
        ..color = (i % 2 == 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: intensity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 4, blipDot);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle || oldDelegate.pulseProgress != pulseProgress;
  }
}
