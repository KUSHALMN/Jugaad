import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'package:jugaad_mvp/core/services/auth_service.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:jugaad_mvp/core/theme/user_app_theme.dart';
import 'package:jugaad_mvp/shared/widgets/jugaad_card.dart';
import 'package:jugaad_mvp/shared/widgets/status_badge.dart';
import 'package:jugaad_mvp/shared/widgets/empty_state.dart';
import 'package:jugaad_mvp/shared/widgets/shimmer_card.dart';
import 'package:url_launcher/url_launcher.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>>? _activeJobs;
  bool _isLoadingActiveJobs = true;
  String? _activeJobsError;
  StreamSubscription<List<Map<String, dynamic>>>? _activeJobsSubscription;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeToActiveJobs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _activeJobsSubscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _subscribeToActiveJobs() {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _isLoadingActiveJobs = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingActiveJobs = true;
        _activeJobsError = null;
      });
    }

    // Start 8-second timeout timer
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 8), () {
      if (_isLoadingActiveJobs && mounted) {
        print('[JobsScreen] Active jobs stream timed out after 8s. Falling back to one-time select query.');
        _fallbackToSelectQuery(uid);
      }
    });

    try {
      _activeJobsSubscription?.cancel();
      _activeJobsSubscription = SupabaseConfig.client
          .from('jobs')
          .stream(primaryKey: ['id'])
          .eq('employer_id', uid)
          .listen(
            (list) {
              _timeoutTimer?.cancel();
              if (mounted) {
                setState(() {
                  _activeJobs = list
                      .where((b) => ['open', 'matched', 'accepted', 'in_progress'].contains(b['status']))
                      .toList();
                  _isLoadingActiveJobs = false;
                  _activeJobsError = null;
                });
              }
            },
            onError: (err) {
              print('[JobsScreen] Realtime stream error: $err. Falling back to one-time select query.');
              _timeoutTimer?.cancel();
              _fallbackToSelectQuery(uid);
            },
            cancelOnError: true,
          );
    } catch (e) {
      print('[JobsScreen] Exception subscribing to stream: $e. Falling back to one-time select query.');
      _timeoutTimer?.cancel();
      _fallbackToSelectQuery(uid);
    }
  }

  Future<void> _fallbackToSelectQuery(String uid) async {
    _activeJobsSubscription?.cancel();
    try {
      final response = await SupabaseConfig.client
          .from('jobs')
          .select()
          .eq('employer_id', uid)
          .inFilter('status', ['open', 'matched', 'accepted', 'in_progress'])
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _activeJobs = List<Map<String, dynamic>>.from(response);
          _isLoadingActiveJobs = false;
          _activeJobsError = null;
        });
      }
    } catch (e) {
      print('[JobsScreen] Fallback select query failed: $e');
      if (mounted) {
        setState(() {
          _isLoadingActiveJobs = false;
          _activeJobsError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UserAppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'My Jobs',
                  style: UserAppTheme.display(size: 28, weight: FontWeight.w800, color: UserAppTheme.textPrimary),
                ).animate().fadeIn(duration: 300.ms),
              ),
            ),

            // ── Custom Pill Tab Bar ───────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              height: 50.0,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(50.0),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: UserAppTheme.textSecondary,
                indicator: BoxDecoration(
                  color: UserAppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(50.0),
                  boxShadow: [
                    BoxShadow(
                      color: UserAppTheme.primaryBlue.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: UserAppTheme.body(
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
                unselectedLabelStyle: UserAppTheme.body(
                  color: UserAppTheme.textSecondary,
                  weight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Active'),
                  Tab(text: 'Scheduled'),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 80.ms),

            const SizedBox(height: 16),

            // ── Tab Views ─────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildActiveTab(),
                  _buildScheduledTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchScheduledJobs(String uid) async {
    final response = await SupabaseConfig.client
        .from('jobs')
        .select('*, worker:users!jobs_worker_id_fkey(name, phone)')
        .eq('employer_id', uid)
        .not('scheduled_at', 'is', null)
        .neq('status', 'completed')
        .neq('status', 'cancelled');
    return List<Map<String, dynamic>>.from(response);
  }

  Widget _buildActiveTab() {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      return EmptyState(
        icon: Icons.lock_outline_rounded,
        heading: 'Not logged in',
        subtitle: 'Please log in to see your active jobs.',
        buttonText: 'Log In',
        onButtonPressed: () => context.go('/splash'),
      );
    }

    if (_activeJobsError != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        heading: 'Something went wrong',
        subtitle: 'Failed to load your active jobs. Please try again.',
        iconColor: UserAppTheme.urgentRed,
        iconBackground: UserAppTheme.urgentRed.withValues(alpha: 0.1),
        buttonText: 'Retry',
        onButtonPressed: () => _subscribeToActiveJobs(),
      );
    }

    if (_isLoadingActiveJobs) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: const [ShimmerList(itemCount: 3)],
      );
    }

    final docs = _activeJobs ?? [];

    if (docs.isEmpty) {
      return EmptyState(
        icon: Icons.calendar_today_rounded,
        heading: 'No active jobs',
        subtitle: 'Need something done? Book an expert in minutes.',
        buttonText: 'Book a Service',
        onButtonPressed: () => context.push('/user/book'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index];
        final status = data['status'] as String? ?? 'open';
        return _ActiveJobCard(
          title: data['skill_required'] as String? ?? 'Service',
          status: status,
          index: index,
          onTap: () {
            if (status == 'open' || status == 'matched') {
              context.push('/user/matching?job_id=${data['id']}');
            } else if (status == 'accepted' || status == 'in_progress') {
              context.push('/user/tracking?job_id=${data['id']}');
            }
          },
        );
      },
    );
  }

  Widget _buildScheduledTab() {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      return EmptyState(
        icon: Icons.lock_outline_rounded,
        heading: 'Not logged in',
        subtitle: 'Please log in to see your scheduled jobs.',
        buttonText: 'Log In',
        onButtonPressed: () => context.go('/splash'),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchScheduledJobs(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.error_outline_rounded,
            heading: 'Something went wrong',
            subtitle: 'Failed to load scheduled jobs. Please try again.',
            iconColor: UserAppTheme.urgentRed,
            iconBackground: UserAppTheme.urgentRed.withValues(alpha: 0.1),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: const [ShimmerList(itemCount: 3)],
          );
        }

        final docs = snapshot.data ?? [];

        if (docs.isEmpty) {
          return EmptyState(
            icon: Icons.event_available_rounded,
            heading: 'No scheduled jobs',
            subtitle: 'Schedule a job for a specific time and date.',
            buttonText: 'Schedule a Service',
            onButtonPressed: () => context.push('/user/book'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index];
            final workerData = data['worker'] as Map? ?? {};
            return _ScheduledJobCard(
              title: data['skill_required'] as String? ?? 'Service',
              location: data['address'] as String? ?? 'Unknown location',
              datetime: _formatDateTime(data['scheduled_at']),
              status: data['status'] as String? ?? 'pending',
              workerName: workerData['name'] as String?,
              workerPhone: workerData['phone'] as String?,
              index: index,
            );
          },
        );
      },
    );
  }

  String _formatDateTime(dynamic scheduledAt) {
    if (scheduledAt == null) return 'Unknown time';
    DateTime dt;
    if (scheduledAt is String) {
      dt = DateTime.tryParse(scheduledAt) ?? DateTime.now();
    } else {
      return 'Unknown time';
    }
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final day = days[dt.weekday - 1];
    final hour =
        dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day $hour:$minute $period';
  }
}

// ─── ACTIVE JOB CARD ────────────────────────────────────────────
class _ActiveJobCard extends StatelessWidget {
  final String title;
  final String status;
  final int index;
  final VoidCallback onTap;

  const _ActiveJobCard({
    required this.title,
    required this.status,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    BadgeStatus badgeStatus;
    if (status == 'matched' || status == 'accepted') {
      badgeStatus = BadgeStatus.assigned;
    } else if (status == 'in_progress') {
      badgeStatus = BadgeStatus.inProgress;
    } else {
      badgeStatus = BadgeStatus.searching;
    }

    Color badgeColor;
    if (badgeStatus == BadgeStatus.inProgress) {
      badgeColor = UserAppTheme.successGreen;
    } else if (badgeStatus == BadgeStatus.assigned) {
      badgeColor = const Color(0xFFF59E0B);
    } else {
      badgeColor = UserAppTheme.primaryBlue;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: JugaadCard(
        index: index,
        borderRadius: UserAppTheme.cardRadius,
        color: UserAppTheme.surface,
        padding: const EdgeInsets.all(16),
        onTap: onTap,
        child: Row(
          children: [
            // Status icon container
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: UserAppTheme.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.build_circle_rounded,
                color: UserAppTheme.primaryBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          UserAppTheme.heading(size: 16, color: UserAppTheme.textPrimary, weight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  StatusBadge(status: badgeStatus, color: badgeColor),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: UserAppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── SCHEDULED JOB CARD ─────────────────────────────────────────
class _ScheduledJobCard extends StatelessWidget {
  final String title;
  final String location;
  final String datetime;
  final String status;
  final String? workerName;
  final String? workerPhone;
  final int index;

  const _ScheduledJobCard({
    required this.title,
    required this.location,
    required this.datetime,
    required this.status,
    this.workerName,
    this.workerPhone,
    required this.index,
  });

  Future<void> _callWorker() async {
    if (workerPhone == null) return;
    final url = Uri.parse('tel:$workerPhone');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = status == 'accepted' || status == 'matched' || status == 'in_progress' || status == 'confirmed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: JugaadCard(
        index: index,
        borderRadius: UserAppTheme.cardRadius,
        color: UserAppTheme.surface,
        padding: const EdgeInsets.all(18),
        animate: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: time badge + status pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: UserAppTheme.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 12, color: UserAppTheme.primaryBlue),
                      const SizedBox(width: 5),
                      Text(
                        datetime,
                        style: UserAppTheme.label(
                          color: UserAppTheme.primaryBlue,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                    status: isConfirmed
                        ? BadgeStatus.completed
                        : BadgeStatus.pending,
                    color: isConfirmed
                        ? UserAppTheme.successGreen
                        : const Color(0xFFF59E0B)),
              ],
            ),
            const SizedBox(height: 14),
            Text(title,
                style: UserAppTheme.heading(size: 16, color: UserAppTheme.textPrimary, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: UserAppTheme.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: UserAppTheme.body(size: 13, color: UserAppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(
                height: 1,
                thickness: 0.8,
                color: UserAppTheme.divider),
            const SizedBox(height: 14),
            if (!isConfirmed)
              Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 14, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Text(
                    "We're confirming your worker. You'll get an SMS.",
                    style: UserAppTheme.body(
                      size: 13,
                      color: const Color(0xFFF59E0B),
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: UserAppTheme.primaryBlue.withValues(alpha: 0.1),
                    child: Text(
                      workerName?.substring(0, 1).toUpperCase() ?? 'W',
                      style: UserAppTheme.body(
                        color: UserAppTheme.primaryBlue,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      workerName ?? 'Worker Assigned',
                      style: UserAppTheme.body(
                        color: UserAppTheme.textPrimary,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _callWorker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: UserAppTheme.successGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_rounded,
                              size: 14, color: UserAppTheme.successGreen),
                          const SizedBox(width: 4),
                          Text(
                            'Call',
                            style: UserAppTheme.body(
                              size: 12,
                              color: UserAppTheme.successGreen,
                              weight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
