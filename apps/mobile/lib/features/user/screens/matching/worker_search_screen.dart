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
    final String category = worker['category'] ?? worker['work_category'] ?? 'Service Expert';
    final bool isVerified = worker['is_verified'] ?? worker['isVerified'] ?? true;
    final String? profilePhoto = worker['profile_photo'] ?? worker['id_document_url'];

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
                          Text(
                            name,
                            style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, color: AppColors.primary, size: 18),
                          ]
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(category, style: GoogleFonts.dmSans(color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                          ),
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
                      Text('STATUS', style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Available Now', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
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
                  context.push('/user/post-job/step1?category=$category');
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
      return Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Searching for nearby ${state.serviceType.isEmpty ? 'workers' : state.serviceType}s...',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
        ],
      );
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
      cacheExtent: 500.0,
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
    final String category = worker['category'] ?? worker['work_category'] ?? 'Worker';
    final bool isVerified = worker['is_verified'] ?? worker['isVerified'] ?? true;
    final String? profilePhoto = worker['profile_photo'] ?? worker['id_document_url'];

    final distanceText = distanceMeters > 0
        ? (distanceMeters >= 1000 ? '${(distanceMeters / 1000).toStringAsFixed(1)} km' : '${distanceMeters.toStringAsFixed(0)} m')
        : 'Mysuru';

    final int etaMins = distanceMeters > 0 ? ((distanceMeters / 400).ceil() + 4).clamp(5, 45) : 15;
    final isSelected = _selectedWorker != null && _selectedWorker['id'] == worker['id'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isSelected ? AppColors.primary : const Color(0xFFEEEEEE), width: isSelected ? 2 : 1),
      ),
      child: ListTile(
        onTap: () => _onWorkerCardTap(worker),
        contentPadding: const EdgeInsets.all(12),
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
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 14),
                const SizedBox(width: 2),
                Text(rating.toStringAsFixed(1), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(width: 12),
                const Icon(Icons.near_me, color: AppColors.primary, size: 14),
                const SizedBox(width: 2),
                Text(distanceText, style: GoogleFonts.dmSans(fontSize: 11, color: Colors.grey[600])),
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

class _LocalPulsingRadarState extends State<LocalPulsingRadar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildRing(0),
          _buildRing(0.33),
          _buildRing(0.66),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 4,
                )
              ],
            ),
            child: const Icon(
              Icons.search_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRing(double delayFraction) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double t = (_controller.value - delayFraction) % 1.0;
        double scale = 1.0 + (t * 1.4);
        double opacity = (1.0 - t) * 0.5;

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.color,
                  width: 2.0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
