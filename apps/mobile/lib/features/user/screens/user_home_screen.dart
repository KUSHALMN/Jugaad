import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/device_context_service.dart';
import '../../../core/services/supabase_service.dart';
import 'post_job/post_job_state.dart';
import '../../../core/config/services_list.dart';
import '../../../core/providers/services_provider.dart';
import '../../../core/config/supabase_config.dart';
import 'user_notification_settings_screen.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/user_app_theme.dart';
import '../widgets/voice_search_overlay.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/services_grid.dart';
import '../widgets/quick_rebook.dart';
import '../widgets/recent_jobs_list.dart';
import '../widgets/sync_alert_banner.dart';
import '../../../core/services/platform_config_service.dart';
import '../widgets/home_categories_grid.dart';
import '../widgets/spotlight_carousel.dart';
import '../widgets/jugaad_trust_matrix.dart';
import '../widgets/symptom_discovery_carousel.dart';
import '../widgets/live_activity_island.dart';
import '../widgets/jugaad_stories_tray.dart';
import '../widgets/rate_card_calculator_sheet.dart';
import '../widgets/trusted_technicians_tray.dart';


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

final activeJobStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = AuthService().currentUser?.uid;
  if (uid == null) return const Stream.empty();

  return SupabaseService().userBookingsStream(
    uid,
    statuses: ['requested', 'matched', 'accepted', 'in_progress'],
    limit: 1,
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
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _scale = 0.95);
      },
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

class _InteractiveHomeSearchBar extends ConsumerStatefulWidget {
  const _InteractiveHomeSearchBar();

  @override
  ConsumerState<_InteractiveHomeSearchBar> createState() => _InteractiveHomeSearchBarState();
}

class _InteractiveHomeSearchBarState extends ConsumerState<_InteractiveHomeSearchBar> {
  static const List<String> _englishHints = [
    "Search 'Electrician in 15 mins'...",
    "Search 'AC cleaning & filter repair'...",
    "Search 'Plumber at doorstep'...",
    "Search 'Carpenter & furniture assembly'...",
    "Search 'Appliance wiring & inverter'...",
  ];

  static const List<String> _kannadaHints = [
    "15 ನಿಮಿಷಗಳಲ್ಲಿ 'ಎಲೆಕ್ಟ್ರಿಷಿಯನ್' ಹುಡುಕಿ...",
    "'ಪ್ಲಂಬರ್' ಬಾಗಿಲಿಗೆ ಸೇವೆ...",
    "'ಕಾರ್ಪೆಂಟರ್' & ಪೀಠೋಪಕರಣ ರಿಪೇರಿ...",
    "'ಎಸಿ ಸರ್ವಿಸ್' & ಫಿಲ್ಟರ್ ಸ್ವಚ್ಛತೆ...",
    "'ವಾಟರ್ ಪ್ಯೂರಿಫೈಯರ್' ಸರ್ವಿಸ್...",
  ];

  static const List<String> _hindiHints = [
    "15 मिनट में 'इलेक्ट्रीशियन' खोजें...",
    "'प्लंबर' घर बैठे बुलाएं...",
    "'बढ़ई' और फर्नीचर रिपेयर...",
    "'एसी सर्विस' और कूलिंग चेक...",
    "'आरओ वाटर' फ़िल्टर सर्विस...",
  ];

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    DeviceContextService.instance.initialize();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _controller.text.isEmpty) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % 5;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitSearch() {
    HapticFeedback.lightImpact();
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      DeviceContextService.instance.recordSearch(query);
      context.push('/user/worker-search?service=${Uri.encodeComponent(query)}');
    } else {
      context.push('/user/worker-search');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final hints = lang == AppLanguage.kannada
        ? _kannadaHints
        : (lang == AppLanguage.hindi ? _hindiHints : _englishHints);
    final hint = hints[_currentIndex % hints.length];

    return Container(
      height: 52.0,
      padding: const EdgeInsets.symmetric(horizontal: 14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _submitSearch,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.search_rounded,
                color: Color(0xFF1D4ED8),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submitSearch(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () {
                _controller.clear();
                setState(() {});
              },
            ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              showDialog(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.2),
                builder: (context) => const VoiceSearchOverlay(),
              );
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.mic_rounded,
                color: Color(0xFFEA580C),
                size: 17,
              ),
            ),
          ),
        ],
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
  final ValueNotifier<double> _pullOffsetNotifier = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    DeviceContextService.instance.initialize().then((_) {
      if (mounted && !DeviceContextService.instance.hasSeenPrivacyConsent) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showPrivacyConsentSheet();
        });
      }
    });

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

  void _showPrivacyConsentSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.cookie_outlined,
                    color: Color(0xFF16A34A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Privacy & Preferences',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Jugaad uses first-party session storage to remember your language, recent searches, battery-saver mode, and offline booking drafts.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: const Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      DeviceContextService.instance.setPrivacyConsent('essential_only');
                      Navigator.pop(sheetCtx);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Essential Only'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      DeviceContextService.instance.setPrivacyConsent('accepted_all');
                      Navigator.pop(sheetCtx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Accept All'),
                  ),
                ),
              ],
            ),
          ],
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
                        Expanded(
                          child: Text(
                            'Notifications',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
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
    _pullOffsetNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    final countsAsync = ref.watch(nearbyWorkersProvider);
    final userNameAsync = ref.watch(userNameProvider);
    final servicesAsync = ref.watch(servicesProvider);
    final recentAsync = ref.watch(recentJobsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: true,
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scroll) {
            if (scroll is ScrollUpdateNotification) {
              if (scroll.metrics.pixels < 0) {
                final newOffset = scroll.metrics.pixels.abs();
                if ((newOffset - _pullOffsetNotifier.value).abs() > 3.0) {
                  _pullOffsetNotifier.value = newOffset;
                }
              } else if (_pullOffsetNotifier.value != 0.0) {
                _pullOffsetNotifier.value = 0.0;
              }
            }
            if (scroll is ScrollEndNotification) {
              if (_pullOffsetNotifier.value > 75.0 && !_isBrandedRefreshing) {
                _triggerBrandedRefresh();
              }
              if (_pullOffsetNotifier.value != 0.0) {
                _pullOffsetNotifier.value = 0.0;
              }
            }
            return false;
          },
          child: Stack(
            fit: StackFit.expand,
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

                  // --- LIVE ADMIN SURGE & PLATFORM NOTICES BANNER ---
                  SliverToBoxAdapter(
                    child: AnimatedBuilder(
                      animation: PlatformConfigService(),
                      builder: (context, _) {
                        final cfg = PlatformConfigService();
                        if (cfg.maintenanceMode) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 10.0),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.build_circle_rounded, color: Color(0xFFDC2626), size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Platform Upgrades: Scheduled maintenance in progress by Admin Ops.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF991B1B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        if (!cfg.isSurgeActive) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 10.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x08F59E0B),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'High Demand Surge Active in Mysuru ⚡',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF92400E),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Live Admin pricing: +₹${cfg.surgeFee.toInt()} hazard guarantee enabled.',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // --- BATTERY-AWARE EXPRESS MODE / LIGHTWEIGHT NETWORK BANNER
                  SliverToBoxAdapter(
                    child: ListenableBuilder(
                      listenable: DeviceContextService.instance,
                      builder: (context, _) {
                        final ctx = DeviceContextService.instance;
                        if (!ctx.isLowBattery && !ctx.isSlowOrMeteredNetwork) {
                          return const SizedBox.shrink();
                        }
                        final isBattery = ctx.isLowBattery;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 12.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isBattery
                                  ? const Color(0xFFFFFBEB)
                                  : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isBattery
                                    ? const Color(0xFFFDE68A)
                                    : const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isBattery
                                      ? Icons.battery_alert_rounded
                                      : Icons.network_check_rounded,
                                  color: isBattery
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF2563EB),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isBattery
                                            ? 'Battery Express Mode (${ctx.batteryLevel}%)'
                                            : 'Lightweight Mode • Mobile Network',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        isBattery
                                            ? 'Heavy media paused • 1-Tap Express Booking ready'
                                            : 'Video preloads paused to keep booking fast',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isBattery) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.mediumImpact();
                                      context.push('/user/book?urgency=emergency');
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF16A34A),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '1-Tap Book',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // --- OFFLINE BOOKING DRAFT RESUME BANNER
                  SliverToBoxAdapter(
                    child: ListenableBuilder(
                      listenable: DeviceContextService.instance,
                      builder: (context, _) {
                        final ctx = DeviceContextService.instance;
                        if (!ctx.hasOfflineBookingDraft || ctx.isOffline) {
                          return const SizedBox.shrink();
                        }
                        final draft = ctx.offlineBookingDraft!;
                        final skill = (draft['skill'] ?? 'Service').toString();
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 12.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cloud_done_rounded, color: Color(0xFF16A34A), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Back online! Resume saved $skill booking draft',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF14532D),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    ref.read(postJobProvider.notifier).setSkill(skill);
                                    ctx.clearOfflineBookingDraft();
                                    context.push('/user/post-job/step3');
                                  },
                                  child: const Text(
                                    'Resume',
                                    style: TextStyle(
                                      color: Color(0xFF15803D),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // --- SEARCH BAR (Top Placement - Interactive Hero Search)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 16.0),
                      child: _InteractiveHomeSearchBar(),
                    ),
                  ),

                  // --- JUGAAD STORIES (30s Video Diagnosis Tray)
                  const SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 12.0),
                        child: JugaadStoriesTray(),
                      ),
                    ),
                  ),

                  // --- MANE TECHNICIAN (1-Tap Trusted Rebooking Tray)
                  const SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 16.0),
                        child: TrustedTechniciansTray(),
                      ),
                    ),
                  ),

                  // --- RATE CARD & COST ESTIMATOR TRANSPARENCY BAR
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          RateCardCalculatorSheet.show(context);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.calculate_rounded, color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Rate Card & Cost Calculator',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF1E3A8A),
                                      ),
                                    ),
                                    Text(
                                      'Calculate exact repair cost before booking • Zero surprises',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10.5,
                                        color: const Color(0xFF3B82F6),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF2563EB), size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12.0)),

                  // --- SYMPTOM-FIRST DISCOVERY CAROUSEL (Urban Company Problem Selector)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: SymptomDiscoveryCarousel(
                        onSymptomTap: (symptom) {
                          HapticFeedback.lightImpact();
                          context.push('/user/worker-search?skill=${symptom.skillTarget}');
                        },
                      ),
                    ),
                  ),

                  // --- CATEGORIES GRID (7 Essential Services)
                  const SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: HomeCategoriesGrid(),
                    ),
                  ),


                  const SliverToBoxAdapter(child: SizedBox(height: 20.0)),

                  // --- SPOTLIGHT CAROUSEL (Apple Minimalist Banners)
                  const SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: SpotlightCarousel(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24.0)),

                  // --- MOST BOOKED SERVICES TITLE
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1D4ED8),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Most Booked Services',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.4,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
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
                              children: [
                                Text(
                                  "View All",
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
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14.0)),

                  // --- MOST BOOKED SERVICES CARDS
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

                  const SliverToBoxAdapter(child: SizedBox(height: 24.0)),

                  // --- JUGAAD TRUST MATRIX
                  const SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: JugaadTrustMatrix(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 20.0)),

                  // --- QUICK REBOOK SECTION (Supabase Live Stream)
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
                          fontWeight: FontWeight.w700,
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
                  const SliverToBoxAdapter(child: SizedBox(height: 48)),
                ],
              ),

              // --- PULL REFRESH SPINNER
              ValueListenableBuilder<double>(
                valueListenable: _pullOffsetNotifier,
                builder: (context, pullOffset, _) {
                  if (!_isBrandedRefreshing && pullOffset <= 5.0) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
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
                  );
                },
              ),

              // --- FLOATING SYNC STATUS ALERT
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SyncAlertBanner(),
              ),

              // --- FLOATING LIVE ACTIVITY ISLAND (When an active booking is in progress)
              Consumer(
                builder: (context, ref, _) {
                  final activeSnap = ref.watch(activeJobStreamProvider);
                  final activeBookings = activeSnap.value ?? [];
                  if (activeBookings.isEmpty) return const SizedBox.shrink();

                  final booking = activeBookings.first;
                  final jobId = booking['id'] as String? ?? '';
                  final status = booking['status'] as String? ?? 'in_progress';
                  final skill = booking['skill_required'] ?? booking['title'] ?? 'Service';
                  final workerName = booking['worker_name'] ?? 'Verified Partner';
                  final startPin = booking['start_pin'] as String? ?? '4821';

                  String statusText = 'Partner Matched';
                  if (status == 'in_progress') statusText = 'In Progress';
                  if (status == 'accepted') statusText = 'En Route';

                  return Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: LiveActivityIsland(
                      workerName: workerName,
                      skill: skill,
                      startPin: startPin,
                      status: statusText,
                      etaText: '12-15 mins',
                      distanceText: '1.4 km away',
                      onCardTap: () {
                        HapticFeedback.mediumImpact();
                        context.push('/user/track?jobId=$jobId');
                      },
                      onCallTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/user/track?jobId=$jobId');
                      },
                      onChatTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/chat/$jobId');
                      },
                      onShareTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/user/track?jobId=$jobId');
                      },
                    ),
                  );
                },
              ),

            ],
          ),
        ),
      ),
      floatingActionButton: _buildBolKeBookKaroFab(),
    );
  }

  Widget _buildBolKeBookKaroFab() {
    final tr = ref.watch(translationsProvider);
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        showDialog(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.3),
          builder: (context) => const VoiceSearchOverlay(),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEA580C), Color(0xFFC2410C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFFDBA74), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEA580C).withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_rounded, color: Color(0xFFEA580C), size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.voiceBookingTitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  tr.voiceTapToSpeak,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
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
