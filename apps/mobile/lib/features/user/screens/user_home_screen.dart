import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/config/services_list.dart';
import '../../../core/providers/services_provider.dart';
import '../../../core/config/supabase_config.dart';
import 'user_notification_settings_screen.dart';
import '../../../core/theme/user_app_theme.dart';
import '../widgets/voice_search_overlay.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/services_grid.dart';
import '../widgets/quick_rebook.dart';
import '../widgets/recent_jobs_list.dart';
import '../widgets/sync_alert_banner.dart';
import 'post_job/post_job_state.dart';

// --- RIVERPOD PROVIDERS ---

// Uses SupabaseService so field names stay consistent
final nearbyWorkersProvider = FutureProvider<Map<String, int>>((ref) async {
  return SupabaseService().fetchNearbyWorkerCounts();
});

final recentJobsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = AuthService().currentUser?.uid;
  if (uid == null) return const Stream.empty();

  // Supabase stream on bookings table
  return SupabaseService().userBookingsStream(
    uid,
    statuses: ['completed', 'cancelled'],
    limit: 3,
  );
});

/// Streams the user's display name from Supabase, falling back to Firebase Auth.
final userNameProvider = StreamProvider<String>((ref) {
  final user = AuthService().currentUser;
  final uid = user?.uid;
  if (uid == null) return Stream.value('');
  return SupabaseService()
      .userStream(uid)
      .map((rows) {
        if (rows.isNotEmpty) {
          final dbName = rows.first['name'] as String? ?? '';
          if (dbName.trim().isNotEmpty) {
            return dbName;
          }
        }
        final firebaseName = user?.displayName;
        if (firebaseName != null && firebaseName.trim().isNotEmpty) {
          return firebaseName;
        }
        final email = user?.email;
        if (email != null && email.contains('@')) {
          return email.split('@').first;
        }
        return '';
      });
});



class ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const ScaleOnTap({super.key, required this.child, required this.onTap});

  @override
  State<ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<ScaleOnTap> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

// --- SCREEN WIDGET ---

class UserHomeScreen extends ConsumerStatefulWidget {
  const UserHomeScreen({super.key});

  @override
  ConsumerState<UserHomeScreen> createState() => _UserHomeScreenState();
}


class _UserHomeScreenState extends ConsumerState<UserHomeScreen> with TickerProviderStateMixin {
  // Bell shake controllers
  late AnimationController _bellShakeController;
  late Animation<double> _bellShakeAnimation;
  int _notificationCount = 3;

  // Branded custom Pull to refresh state
  bool _isBrandedRefreshing = false;
  double _pullOffset = 0.0;

  @override
  void initState() {
    super.initState();

    // Bell shake anim: 15 degrees shake left-right 3 times
    _bellShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _bellShakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bellShakeController, curve: Curves.easeInOut),
    );

    // Initial bell shake on mount after delay
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        _bellShakeController.forward(from: 0.0);
      }
    });
  }

  void _onNotificationTap() {
    HapticFeedback.selectionClick();
    _bellShakeController.forward(from: 0.0);
    setState(() {
      _notificationCount = 0; // Badge count scales down / fades
    });
    _showNotificationsBottomSheet();
  }

  void _openNotificationSettings() {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserNotificationSettingsScreen(
          currentData: {'id': uid},
        ),
      ),
    );
  }

  void _showNotificationsBottomSheet() {
    final uid = AuthService().currentUser?.uid;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Notifications',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                if (uid != null) {
                                  try {
                                    await SupabaseConfig.client
                                        .from('notifications')
                                        .delete()
                                        .eq('user_id', uid);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Notifications cleared'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    print('[UserHomeScreen] Clear notifications error: $e');
                                  }
                                }
                              },
                              child: Text(
                                'Clear all',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF1A56DB),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _openNotificationSettings();
                              },
                              icon: const Icon(
                                Icons.settings_outlined,
                                color: Color(0xFF64748B),
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Expanded(
                    child: uid == null
                        ? _buildEmptyNotifications()
                        : StreamBuilder<List<Map<String, dynamic>>>(
                            stream: SupabaseService().notificationsStream(uid),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(UserAppTheme.primaryBlue),
                                  ),
                                );
                              }
                              final list = snapshot.data ?? [];
                              if (list.isEmpty) {
                                return _buildEmptyNotifications();
                              }

                              return ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                                itemCount: list.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = list[index];
                                  final type = item['type'] as String? ?? 'general';
                                  final title = item['title'] as String? ?? 'Notification';
                                  final body = item['body'] as String? ?? '';
                                  final createdAtStr = item['created_at'] as String?;
                                  final isNew = !(item['sent'] as bool? ?? false);

                                  return _buildNotificationCard(
                                    icon: _getNotificationIcon(type),
                                    iconColor: _getNotificationColor(type),
                                    iconBgColor: _getNotificationBgColor(type),
                                    title: title,
                                    body: body,
                                    time: _formatNotificationTime(createdAtStr),
                                    isNew: isNew,
                                  );
                                },
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

  Widget _buildEmptyNotifications() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              color: Color(0xFF94A3B8),
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'We will notify you when something important happens.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'booking_completed':
      case 'job_completed':
        return Icons.check_circle_rounded;
      case 'booking_cancelled':
      case 'job_cancelled':
        return Icons.cancel_rounded;
      case 'special_offer':
        return Icons.local_offer_rounded;
      case 'dispatch':
      case 'new_request':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'booking_completed':
      case 'job_completed':
        return const Color(0xFF16A34A);
      case 'booking_cancelled':
      case 'job_cancelled':
        return const Color(0xFFEF4444);
      case 'special_offer':
        return const Color(0xFF1A56DB);
      default:
        return const Color(0xFFD97706);
    }
  }

  Color _getNotificationBgColor(String type) {
    switch (type.toLowerCase()) {
      case 'booking_completed':
      case 'job_completed':
        return const Color(0xFFDCFCE7);
      case 'booking_cancelled':
      case 'job_cancelled':
        return const Color(0xFFFEE2E2);
      case 'special_offer':
        return const Color(0xFFEFF6FF);
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  String _formatNotificationTime(String? createdAtStr) {
    if (createdAtStr == null) return '';
    try {
      final dateTime = DateTime.parse(createdAtStr).toLocal();
      final diff = DateTime.now().difference(dateTime);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  Widget _buildNotificationCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String body,
    required String time,
    required bool isNew,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isNew ? const Color(0xFFEFF6FF) : const Color(0xFFE2E8F0),
          width: isNew ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (isNew)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1A56DB),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  time,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerBrandedRefresh() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isBrandedRefreshing = true;
    });

    ref.invalidate(nearbyWorkersProvider);
    ref.invalidate(recentJobsProvider);
    ref.invalidate(userNameProvider);
    ref.invalidate(servicesProvider);

    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() {
        _isBrandedRefreshing = false;
      });
    }
  }

  @override
  void dispose() {
    _bellShakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    final countsAsync = ref.watch(nearbyWorkersProvider);
    final userNameAsync = ref.watch(userNameProvider);
    final servicesAsync = ref.watch(servicesProvider);
    final recentAsync = ref.watch(recentJobsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scroll) {
            if (scroll is ScrollUpdateNotification) {
              if (scroll.metrics.pixels < 0) {
                setState(() {
                  _pullOffset = scroll.metrics.pixels.abs();
                });
              } else {
                setState(() {
                  _pullOffset = 0.0;
                });
              }
            }
            if (scroll is ScrollEndNotification) {
              if (_pullOffset > 75.0 && !_isBrandedRefreshing) {
                _triggerBrandedRefresh();
              }
              setState(() {
                _pullOffset = 0.0;
              });
            }
            return false;
          },
          child: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      height: _isBrandedRefreshing ? 64.0 : 0.0,
                    ),
                  ),

                  // --- HEADER (RepaintBoundary for isolated rasterization)
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: DashboardHeader(
                        name: userNameAsync.value ?? (AuthService().currentUser?.displayName?.split(' ').first ?? 'User'),
                        notificationCount: _notificationCount,
                        bellShakeAnimation: _bellShakeAnimation,
                        onNotificationTap: _onNotificationTap,
                      ),
                    ),
                  ),

                  // --- EMERGENCY LANDING CTA (Primary Action) — Clean Minimal Light Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 16.0),
                      // ── Light premium card ──
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24.0),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0x0A000000),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.02),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFFF1F5F9),
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Red accent top strip
                              Container(
                                height: 3,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFFCA5A5)],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Live badge
                                    Row(
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFEF4444),
                                            shape: BoxShape.circle,
                                          ),
                                        )
                                        .animate(onPlay: (c) => c.repeat(reverse: true))
                                        .scaleXY(begin: 0.7, end: 1.3, duration: 700.ms),
                                        const SizedBox(width: 7),
                                        Text(
                                          'Emergency dispatch active',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: const Color(0xFFEF4444),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Need help now?',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                        height: 1.1,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Get a verified local worker in 30 minutes.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    // CTA Button
                                    ScaleOnTap(
                                      onTap: () {
                                        HapticFeedback.heavyImpact();
                                        ref.read(postJobProvider.notifier).reset();
                                        ref.read(postJobProvider.notifier).setEmergency(true);
                                        context.push('/user/post-job/step1');
                                      },
                                      child: Container(
                                        width: double.infinity,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        alignment: Alignment.center,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.flash_on_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Get Emergency Help',
                                              style: GoogleFonts.plusJakartaSans(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    // Stats row inside card
                                    Row(
                                      children: [
                                        _StatPill(label: '30 min', sublabel: 'Avg arrival'),
                                        const SizedBox(width: 10),
                                        _StatPill(label: '500+', sublabel: 'Workers'),
                                        const SizedBox(width: 10),
                                        _StatPill(label: '4.8★', sublabel: 'Rated'),
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
                  ),

                  // --- TRUST INDICATORS STRIP (minimal)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 20.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _TrustChip(
                              icon: Icons.verified_rounded,
                              color: const Color(0xFF16A34A),
                              label: 'Verified Workers',
                            ),
                            const SizedBox(width: 8),
                            _TrustChip(
                              icon: Icons.timer_rounded,
                              color: const Color(0xFFDC2626),
                              label: '30-Min Response',
                            ),
                            const SizedBox(width: 8),
                            _TrustChip(
                              icon: Icons.my_location_rounded,
                              color: const Color(0xFF2563EB),
                              label: 'Live Tracking',
                            ),
                            const SizedBox(width: 8),
                            _TrustChip(
                              icon: Icons.shield_rounded,
                              color: const Color(0xFFEA580C),
                              label: 'Insured Jobs',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 4)),

                  // --- SEARCH BAR
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: GestureDetector(
                        onTap: () => context.push('/user/worker-search'),
                        child: Container(
                          height: 52.0,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30.0),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000), // Shadow: rgba(0,0,0,0.08)
                                blurRadius: 20,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF1A56DB),
                                size: 24,
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Text(
                                  "Search emergency electrician, plumber...",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    barrierColor: Colors.black.withValues(alpha: 0.15),
                                    builder: (context) => const VoiceSearchOverlay(),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                  child: Icon(
                                    Icons.mic_rounded,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 28.0)),

                  // --- CATEGORY GRID TITLE
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFDC2626),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Emergency Services',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
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
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  "All Services",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF1A56DB),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Color(0xFF1A56DB),
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14.0)),

                  // --- CATEGORY GRID
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    sliver: SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: ServicesGrid(
                          servicesList: servicesAsync.value ?? kAllServices,
                          counts: countsAsync.value ?? const {},
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20.0)),

                  // --- QUICK REBOOK SECTION (NEW)
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: recentAsync.when(
                        data: (bookings) => QuickRebook(bookings: bookings),
                        loading: () => const SizedBox.shrink(),
                        error: (err, stack) => const SizedBox.shrink(),
                      ),
                    ),
                  ),

                  // --- RECENT BOOKINGS TITLE
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Text(
                        'Recent Bookings',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),

                  // --- RECENT BOOKINGS CONTENT
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: RepaintBoundary(
                        child: RecentJobsList(recentAsync: recentAsync),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),

              // --- PULL REFRESH SPINNER
              if (_isBrandedRefreshing || _pullOffset > 5.0)
                Positioned(
                  top: 16.0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10.0,
                            offset: Offset(0, 3.0),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: UserAppTheme.primaryBlue,
                        size: 26.0,
                      )
                      .animate(onPlay: (c) {
                        if (_isBrandedRefreshing) c.repeat();
                      })
                      .rotate(
                        begin: 0.0,
                        end: 1.0,
                        duration: 1000.ms,
                      ),
                    ),
                  ),
                ),

              // --- FLOATING SYNC STATUS ALERT
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SyncAlertBanner(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact trust indicator pill chip for the home screen
class _TrustChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _TrustChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact stat pill for inside the light CTA card
class _StatPill extends StatelessWidget {
  final String label;
  final String sublabel;

  const _StatPill({required this.label, required this.sublabel});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
