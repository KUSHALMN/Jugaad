import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/theme/app_colors.dart';

class WorkerListScreen extends StatefulWidget {
  const WorkerListScreen({super.key});

  @override
  State<WorkerListScreen> createState() => _WorkerListScreenState();
}

class _WorkerListScreenState extends State<WorkerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;
  bool _isLoading = true;

  List<Map<String, dynamic>> _workers = [];
  List<Map<String, dynamic>> _filteredWorkersCache = [];
  final Map<String, Map<String, dynamic>> _userCache = {};
  StreamSubscription? _workersSubscription;
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Electrician',
    'Plumber',
    'Laptop repair',
    'Phone repair',
    'Carpenter',
    'Painter',
    'AC service',
    'Cleaning',
  ];

  static final List<Map<String, dynamic>> _mockWorkers = [];

  @override
  void initState() {
    super.initState();
    _updateFilteredWorkers();
    _initWorkersStream();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _workersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _makeCall(String rawPhone) async {
    HapticFeedback.mediumImpact();
    if (rawPhone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number not available'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final clean = rawPhone.replaceAll(RegExp(r'\D'), '');
    final number = clean.length == 10 ? '+91$clean' : '+$clean';
    final uri = Uri.parse('tel:$number');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      final fallbackUri = Uri.parse('tel:$rawPhone');
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calling $rawPhone...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _initWorkersStream() {
    _workersSubscription = SupabaseConfig.client
        .from('workers')
        .stream(primaryKey: ['id'])
        .eq('status', 'approved')
        .listen((List<Map<String, dynamic>> workersData) async {
          if (!mounted) return;

          final requiredUserIds = workersData.map((w) => w['id'] as String).toList();
          if (requiredUserIds.isNotEmpty) {
            final missingIds = requiredUserIds.where((id) => !_userCache.containsKey(id)).toList();
            if (missingIds.isNotEmpty) {
              try {
                final usersData = await SupabaseConfig.client
                    .from('users')
                    .select()
                    .inFilter('id', missingIds);

                for (final u in usersData) {
                  _userCache[u['id']] = u;
                }
              } catch (e) {
                print('[WorkerListScreen] Error caching users: $e');
              }
            }
          }

          if (mounted) {
            setState(() {
              _workers = workersData;
              _isLoading = false;
              _updateFilteredWorkers();
            });
          }
        }, onError: (err) {
          print('[WorkerListScreen] Stream error: $err');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _updateFilteredWorkers();
            });
          }
        });
  }

  void _updateFilteredWorkers() {
    final listToFilter = (_workers.isNotEmpty ? _workers : _mockWorkers).where((w) {
      if (w['id'].toString().startsWith('mock_')) {
        return w['is_available'] == true;
      }
      return w['availability_status'] == 'online' || w['is_available'] == true;
    }).toList();

    if (_workers.isEmpty) {
      _userCache['mock_1'] = {'email': 'rahul.sharma@jugaad.com', 'phone': '+91 98765 43210'};
      _userCache['mock_2'] = {'email': 'priya.singh@jugaad.com', 'phone': '+91 98765 43211'};
      _userCache['mock_3'] = {'email': 'amit.kumar@jugaad.com', 'phone': '+91 98765 43212'};
      _userCache['mock_4'] = {'email': 'vikram.patel@jugaad.com', 'phone': '+91 98765 43213'};
    }

    var categoryFiltered = listToFilter;
    if (_selectedCategory != 'All') {
      final normalizedSel = _selectedCategory.toLowerCase().replaceAll(' ', '_');
      categoryFiltered = listToFilter.where((w) {
        final skills = List<String>.from(w['skills'] as List? ?? [])
            .map((s) => s.toLowerCase().replaceAll(' ', '_'))
            .toList();
        final specialities = List<String>.from(w['specialities'] as List? ?? [])
            .map((s) => s.toLowerCase().replaceAll(' ', '_'))
            .toList();
        return skills.contains(normalizedSel) || specialities.contains(normalizedSel);
      }).toList();
    }

    if (_searchQuery.trim().isEmpty) {
      _filteredWorkersCache = categoryFiltered;
      return;
    }
    final query = _searchQuery.toLowerCase();
    _filteredWorkersCache = categoryFiltered.where((w) {
      final name = (w['name'] as String? ?? '').toLowerCase();
      final bio = (w['bio'] as String? ?? '').toLowerCase();
      final area = (w['area'] as String? ?? '').toLowerCase();
      final skills = List<String>.from(w['skills'] as List? ?? [])
          .map((s) => s.toLowerCase())
          .toList();

      final cachedUser = _userCache[w['id']] ?? {};
      final email = (cachedUser['email'] as String? ?? '').toLowerCase();

      return name.contains(query) ||
             bio.contains(query) ||
             area.contains(query) ||
             email.contains(query) ||
             skills.any((s) => s.contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jugaad Experts',
                    style: GoogleFonts.syne(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Browse all skilled workers and their live status.',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // Search bar with 250ms debounce
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
                      if (mounted) {
                        setState(() {
                          _searchQuery = val;
                          _updateFilteredWorkers();
                        });
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name, skill, area, or email...',
                    hintStyle: GoogleFonts.dmSans(
                      color: const Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _updateFilteredWorkers();
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Category Filter Chips
            Container(
              height: 48,
              margin: const EdgeInsets.only(bottom: 4),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        category,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF1A56DB),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50.0),
                        side: BorderSide(
                          color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                      labelPadding: EdgeInsets.zero,
                      showCheckmark: false,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = category;
                            _updateFilteredWorkers();
                          });
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Main List with lazy building and no per-scroll animation overhead
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    )
                  : _filteredWorkersCache.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          itemCount: _filteredWorkersCache.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final worker = _filteredWorkersCache[index];
                            return _WorkerCard(
                              key: ValueKey(worker['id']),
                              worker: worker,
                              userData: _userCache[worker['id']] ?? {},
                              onTap: () => _showWorkerDetailsBottomSheet(worker),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(
              Icons.engineering_outlined,
              color: Color(0xFF94A3B8),
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Workers Found',
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Try adjusting your search query to find nearby experts.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: const Color(0xFF64748B),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWorkerDetailsBottomSheet(Map<String, dynamic> worker) {
    final cachedUser = _userCache[worker['id']] ?? {};
    final String workerId = worker['id'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2.25),
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchWorkerReviews(workerId),
                      builder: (context, snapshot) {
                        final reviews = snapshot.data ?? [];
                        final reviewsLoading = snapshot.connectionState == ConnectionState.waiting;

                        return ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                          children: [
                            // Worker Detail Header
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  backgroundImage: (worker['id_document_url'] is String && (worker['id_document_url'] as String).isNotEmpty)
                                      ? CachedNetworkImageProvider(worker['id_document_url'] as String)
                                      : null,
                                  child: (worker['id_document_url'] == null || (worker['id_document_url'] as String).isEmpty)
                                      ? Text(
                                          (worker['name'] as String? ?? 'W').substring(0, 1).toUpperCase(),
                                          style: GoogleFonts.dmSans(
                                            color: const Color(0xFF1A56DB),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 28,
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
                                              worker['name'] ?? 'Worker Name',
                                              style: GoogleFonts.syne(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF0F172A),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const SizedBox(width: 6),
                                          _buildVerificationStages(worker, size: 14),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: (worker['is_available'] == true)
                                              ? const Color(0xFFE8F5E9)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: (worker['is_available'] == true)
                                                    ? const Color(0xFF2E7D32)
                                                    : const Color(0xFF64748B),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              (worker['is_available'] == true) ? 'Available Now' : 'Offline',
                                              style: GoogleFonts.dmSans(
                                                color: (worker['is_available'] == true)
                                                    ? const Color(0xFF2E7D32)
                                                    : const Color(0xFF64748B),
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          _buildVerificationChip('Phone', worker['phone_verified'] == true, Icons.phone_android_rounded, const Color(0xFF1A56DB)),
                                          _buildVerificationChip('Identity', worker['identity_verified'] == true || worker['id_verified'] == true || worker['isVerified'] == true, Icons.verified_user_rounded, const Color(0xFF16A34A)),
                                          _buildVerificationChip('Skill', worker['skill_verified'] == true, Icons.star_rounded, const Color(0xFFEAB308)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Stats Grid
                            Row(
                              children: [
                                _buildDetailStatCard(
                                  icon: Icons.star_rounded,
                                  iconColor: const Color(0xFFEAB308),
                                  title: 'Rating',
                                  value: '${worker['rating'] ?? 0.0}',
                                ),
                                const SizedBox(width: 12),
                                _buildDetailStatCard(
                                  icon: Icons.done_all_rounded,
                                  iconColor: const Color(0xFF16A34A),
                                  title: 'Jobs Done',
                                  value: '${worker['total_jobs'] ?? worker['totalJobsCompleted'] ?? 0}',
                                ),
                                const SizedBox(width: 12),
                                _buildDetailStatCard(
                                  icon: Icons.work_history_rounded,
                                  iconColor: const Color(0xFF1A56DB),
                                  title: 'Experience',
                                  value: worker['experience'] ?? 'N/A',
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Bio section
                            if (worker['bio'] != null && (worker['bio'] as String).trim().isNotEmpty) ...[
                              Text(
                                'About Me',
                                style: GoogleFonts.syne(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                worker['bio'],
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  color: const Color(0xFF475569),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Skills Section
                            Text(
                              'Skills',
                              style: GoogleFonts.syne(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List<String>.from(worker['skills'] as List? ?? [])
                                  .map((s) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          s,
                                          style: GoogleFonts.dmSans(
                                            color: const Color(0xFF475569),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 24),

                            // Contact details
                            Text(
                              'Contact Details',
                              style: GoogleFonts.syne(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildContactRow(Icons.phone_rounded, worker['phone'] ?? cachedUser['phone'] ?? 'N/A'),
                            const SizedBox(height: 8),
                            _buildContactRow(Icons.email_rounded, cachedUser['email'] ?? 'N/A'),
                            const SizedBox(height: 8),
                            _buildContactRow(Icons.location_on_rounded, worker['area'] ?? 'N/A'),
                            const SizedBox(height: 24),

                            // Reviews List (Recent Jobs History)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Reviews & Job History',
                                  style: GoogleFonts.syne(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                if (reviews.isNotEmpty)
                                  Text(
                                    '${reviews.length} total',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (reviewsLoading)
                              const Center(child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ))
                            else if (reviews.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                child: Text(
                                  'No reviews yet for this worker.',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13.5,
                                    color: const Color(0xFF94A3B8),
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: reviews.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final r = reviews[index];
                                  final reviewer = r['reviewer'] ?? {};
                                  final reviewerName = reviewer['name'] as String? ?? 'Jugaad Customer';
                                  final rating = r['rating'] as int? ?? 5;
                                  final comment = r['comment'] as String? ?? '';
                                  final dateStr = r['created_at'] as String?;
                                  String timeStr = '';
                                  if (dateStr != null) {
                                    try {
                                      final date = DateTime.parse(dateStr).toLocal();
                                      timeStr = '${date.day}/${date.month}/${date.year}';
                                    } catch (_) {}
                                  }

                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFF),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFEFF3F8)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              reviewerName,
                                              style: GoogleFonts.dmSans(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: const Color(0xFF1E293B),
                                              ),
                                            ),
                                            Text(
                                              timeStr,
                                              style: GoogleFonts.dmSans(
                                                fontSize: 11,
                                                color: const Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: List.generate(5, (starIdx) {
                                            return Icon(
                                              Icons.star_rounded,
                                              color: starIdx < rating
                                                  ? const Color(0xFFEAB308)
                                                  : const Color(0xFFE2E8F0),
                                              size: 14,
                                            );
                                          }),
                                        ),
                                        if (comment.trim().isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            comment,
                                            style: GoogleFonts.dmSans(
                                              fontSize: 13,
                                              color: const Color(0xFF475569),
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                            const SizedBox(height: 24),

                            // Call button
                            ElevatedButton.icon(
                              onPressed: () {
                                final phone = (worker['phone'] as String? ?? '').isNotEmpty
                                    ? worker['phone'] as String
                                    : (cachedUser['phone'] as String? ?? '');
                                _makeCall(phone);
                              },
                              icon: const Icon(Icons.call_rounded),
                              label: Text('Call ${worker['name'] ?? 'Worker'}'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A56DB),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchWorkerReviews(String workerId) async {
    if (workerId.startsWith('mock_')) {
      await Future.delayed(const Duration(milliseconds: 150)); // simulate slight database latency
      return [
        {
          'id': 'rev_${workerId}_1',
          'reviewer_id': 'u_mock_1',
          'reviewee_id': workerId,
          'rating': 5,
          'comment': 'Awesome work! Came on time and did the job very professionally.',
          'created_at': DateTime.now().subtract(const Duration(days: 3)).toUtc().toIso8601String(),
          'reviewer': {'name': 'Arjun Mehta'}
        },
        {
          'id': 'rev_${workerId}_2',
          'reviewer_id': 'u_mock_2',
          'reviewee_id': workerId,
          'rating': 4,
          'comment': 'Quick and reliable service. Rates were very reasonable.',
          'created_at': DateTime.now().subtract(const Duration(days: 8)).toUtc().toIso8601String(),
          'reviewer': {'name': 'Sneha Reddy'}
        }
      ];
    }

    try {
      final response = await SupabaseConfig.client
          .from('reviews')
          .select('*, reviewer:users!reviewer_id(name)')
          .eq('reviewee_id', workerId)
          .order('created_at', ascending: false)
          .limit(5);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('[WorkerListScreen] _fetchWorkerReviews error: $e');
      return [];
    }
  }

  Widget _buildDetailStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEFF3F8)),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String detail) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF64748B), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            detail,
            style: GoogleFonts.dmSans(
              fontSize: 13.5,
              color: const Color(0xFF334155),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _WorkerCard extends StatefulWidget {
  final Map<String, dynamic> worker;
  final Map<String, dynamic> userData;
  final VoidCallback onTap;

  const _WorkerCard({
    super.key,
    required this.worker,
    required this.userData,
    required this.onTap,
  });

  @override
  State<_WorkerCard> createState() => _WorkerCardState();
}

class _WorkerCardState extends State<_WorkerCard> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.worker['name'] ?? 'Expert';
    final area = widget.worker['area'] ?? 'N/A';
    final skills = List<String>.from(widget.worker['skills'] as List? ?? []);
    final int jobs = widget.worker['total_jobs'] ?? widget.worker['totalJobsCompleted'] ?? 0;
    final rawRating = widget.worker['rating'];
    final double? rating = (rawRating != null && jobs > 0) ? (double.tryParse(rawRating.toString())) : null;
    final exp = widget.worker['experience'] ?? 'N/A';
    final rate = widget.worker['rate_per_hour'] ?? 150;
    final isAvailable = widget.worker['is_available'] == true || widget.worker['availability_status'] == 'online';
    final photoUrl = widget.worker['id_document_url'] as String?;
    final specialities = List<String>.from(widget.worker['specialities'] as List? ?? []);
    final categoryText = specialities.isNotEmpty 
        ? specialities.first 
        : (skills.isNotEmpty ? skills.first : 'Worker');

    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'W';
    final scale = _isPressed ? 0.97 : (_isHovered ? 1.02 : 1.0);


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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered ? const Color(0xFF1A56DB).withValues(alpha: 0.3) : const Color(0xFFECEFF1),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered 
                      ? const Color(0xFF1A56DB).withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.02),
                  blurRadius: _isHovered ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with online pulse dot
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFFEFF6FF),
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                          ? CachedNetworkImageProvider(photoUrl)
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? Text(
                              initials,
                              style: GoogleFonts.dmSans(
                                color: const Color(0xFF1A56DB),
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: isAvailable ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.0),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // Content Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name & verified badge
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: GoogleFonts.syne(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildVerificationStages(widget.worker, size: 12),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Category Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: Text(
                          categoryText.toUpperCase(),
                          style: GoogleFonts.dmSans(
                            color: const Color(0xFF1E40AF),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Rating & job count
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFEAB308), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            rating != null ? rating.toStringAsFixed(1) : 'New',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: const Color(0xFF1E293B),
                            ),
                          ),

                          const SizedBox(width: 6),
                          Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF94A3B8))),
                          const SizedBox(width: 6),
                          Text(
                            '$jobs completed',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Skills Chips
                      if (skills.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: skills.take(3).map((s) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  s,
                                  style: GoogleFonts.dmSans(
                                    color: const Color(0xFF475569),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Experience & Rate
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.work_outline_rounded, color: Color(0xFF94A3B8), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '$exp Exp',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '₹$rate/hr',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Area location
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: Color(0xFF94A3B8), size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              area,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildVerificationStages(Map<String, dynamic> worker, {double size = 14}) {
  final phone = worker['phone_verified'] == true;
  final identity = worker['identity_verified'] == true || worker['id_verified'] == true || worker['isVerified'] == true;
  final skill = worker['skill_verified'] == true;

  if (!phone && !identity && !skill) return const SizedBox.shrink();

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (phone) ...[
        Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            color: Color(0xFFEFF6FF),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.phone_android_rounded, color: const Color(0xFF1D4ED8), size: size),
        ),
      ],
      if (identity) ...[
        Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            color: Color(0xFFE8F5E9),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.verified_user_rounded, color: const Color(0xFF15803D), size: size),
        ),
      ],
      if (skill) ...[
        Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF8E1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.star_rounded, color: const Color(0xFFB45309), size: size),
        ),
      ],
    ],
  );
}

Widget _buildVerificationChip(String label, bool isVerified, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: isVerified ? color.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isVerified ? color.withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: isVerified ? color : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            color: isVerified ? color : const Color(0xFF64748B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
