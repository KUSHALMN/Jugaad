import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jugaad_mvp/features/user/screens/user_home_screen.dart';
import 'package:jugaad_mvp/core/theme/user_app_theme.dart';
import 'package:jugaad_mvp/core/utils/jugaad_haptics.dart';
import 'package:jugaad_mvp/core/services/api_service.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  final String jobId;
  const TrackingScreen({super.key, required this.jobId});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> with WidgetsBindingObserver {
  RealtimeChannel? _realtimeChannel;
  RealtimeChannel? _priceRequestChannel;
  Map<String, dynamic>? _jobData;
  Map<String, dynamic>? _pendingPriceRequest;
  Timer? _elapsedTimer;
  String _elapsedString = '00:00';
  bool _isEtaPassed = false;
  DateTime? _lastBackgroundTime;
  bool _showArrivalBanner = false;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startFirestoreListener();
  }

  void _subscribeToPriceRequestsRealtime() {
    _priceRequestChannel?.unsubscribe();
    _priceRequestChannel = SupabaseConfig.client
        .channel('public:price_change_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'price_change_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'job_id',
            value: widget.jobId,
          ),
          callback: (payload) {
            if (!mounted) return;
            print('[TRACKING] Price change request realtime event: ${payload.eventType}');
            final data = payload.newRecord;
            if (data.isEmpty) {
              setState(() => _pendingPriceRequest = null);
              return;
            }
            final status = data['status'] as String?;
            if (status == 'pending') {
              setState(() => _pendingPriceRequest = data);
              _showPriceChangeAlertOverlay();
            } else {
              setState(() => _pendingPriceRequest = null);
            }
          },
        )
        .subscribe();
  }

  void _startFirestoreListener() {
    if (widget.jobId.isEmpty) return;

    _subscribeToPriceRequestsRealtime();

    _realtimeChannel = SupabaseConfig.client
        .channel('public:jobs')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.jobId,
          ),
          callback: (payload) {
            if (!mounted) return;
            print('[TRACKING] Supabase realtime event: ${payload.eventType}');
            final data = payload.newRecord;
            if (data.isEmpty) return;
            
            _onJobDataUpdate(data);
          },
        )
        .subscribe();

    _fetchInitialJobState();
  }

  Future<void> _fetchPendingPriceRequest() async {
    try {
      final reqs = await SupabaseConfig.client
          .from('price_change_requests')
          .select()
          .eq('job_id', widget.jobId)
          .eq('status', 'pending')
          .maybeSingle();
      if (mounted) {
        setState(() {
          _pendingPriceRequest = reqs;
        });
        if (reqs != null) {
          _showPriceChangeAlertOverlay();
        }
      }
    } catch (e) {
      print('[TRACKING] Error fetching pending price request: $e');
    }
  }

  Future<void> _fetchInitialJobState() async {
    try {
      final doc = await SupabaseConfig.client
          .from('jobs')
          .select()
          .eq('id', widget.jobId)
          .maybeSingle();
      if (doc != null && mounted) {
        _onJobDataUpdate(doc);
        _fetchPendingPriceRequest();
      }
    } catch (e) {
      print('[TRACKING] Error fetching initial job state: $e');
    }
  }

  void _showPriceChangeAlertOverlay() {
    if (_isDialogShowing || _pendingPriceRequest == null) return;
    _isDialogShowing = true;

    final req = _pendingPriceRequest!;
    final oldPrice = req['old_price'];
    final newPrice = req['new_price'];
    final reason = req['reason'] ?? 'No reason provided';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: UserAppTheme.surface,
          title: Row(
            children: [
              const Icon(Icons.monetization_on_rounded, color: UserAppTheme.primaryBlue, size: 24),
              const SizedBox(width: 8),
              Text(
                'Price Change Request',
                style: UserAppTheme.heading(weight: FontWeight.bold, size: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The worker has proposed a price adjustment for this job.',
                style: UserAppTheme.body(size: 13, color: UserAppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: UserAppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Original', style: UserAppTheme.label(size: 11, color: UserAppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          '₹$oldPrice',
                          style: UserAppTheme.heading(size: 18, color: UserAppTheme.textPrimary, weight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: UserAppTheme.textSecondary, size: 20),
                    Column(
                      children: [
                        Text('Proposed', style: UserAppTheme.label(size: 11, color: UserAppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          '₹$newPrice',
                          style: UserAppTheme.heading(size: 18, color: UserAppTheme.primaryBlue, weight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Reason Proposed:',
                style: UserAppTheme.label(size: 11, color: UserAppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                reason,
                style: UserAppTheme.body(size: 13, color: UserAppTheme.textSecondary).copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _respondToPriceChange(false);
              },
              child: Text(
                'Reject',
                style: UserAppTheme.body(color: UserAppTheme.urgentRed, weight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _respondToPriceChange(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: UserAppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
              ),
              child: Text(
                'Approve',
                style: UserAppTheme.body(color: Colors.white, weight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  Future<void> _respondToPriceChange(bool approved) async {
    try {
      await ApiService().respondPriceChange(widget.jobId, approved);
      JugaadHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approved ? 'Price change request approved!' : 'Price change request rejected.'),
            backgroundColor: approved ? UserAppTheme.successGreen : UserAppTheme.urgentRed,
          ),
        );
      }
    } catch (e) {
      print('[TRACKING] Error responding to price change: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send response: $e')),
        );
      }
    }
  }

  void _onJobDataUpdate(Map<String, dynamic> data) {
    if (data['worker_ack'] == true && data['status'] == 'in_progress' && _jobData != null && _jobData!['status'] != 'in_progress') {
      // Just arrived & started work!
      setState(() {
        _showArrivalBanner = true;
      });
      JugaadHaptics.success();
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _showArrivalBanner = false;
          });
        }
      });
    }

    setState(() {
      _jobData = data;
    });

    if (data['worker_ack'] == true && data['status'] == 'in_progress') {
      _startElapsedTimer(data['started_at']);
    }
    
    // Navigate to payment if job is completed
    if (data['status'] == 'completed') {
      ref.invalidate(recentJobsProvider);
      ref.invalidate(nearbyWorkersProvider);
      final amount = data['payment_amount'] ?? data['amount'] ?? 350;
      context.go('/user/payment?job_id=${widget.jobId}&amount=$amount');
    } else if (data['status'] == 'cancelled') {
      ref.invalidate(recentJobsProvider);
      ref.invalidate(nearbyWorkersProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Job was cancelled.',
            style: UserAppTheme.body(color: Colors.white, weight: FontWeight.bold),
          ),
          backgroundColor: UserAppTheme.urgentRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.go('/user/home');
    }
  }

  void _startElapsedTimer(dynamic startedAt) {
    if (_elapsedTimer != null && _elapsedTimer!.isActive) return;
    
    DateTime startTime = DateTime.now();
    if (startedAt is String) {
      startTime = DateTime.tryParse(startedAt)?.toLocal() ?? DateTime.now();
    }
    
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final duration = DateTime.now().difference(startTime);
      final minutes = duration.inMinutes.toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      setState(() {
        _elapsedString = '$minutes:$seconds';
      });
    });
  }

  Future<void> _callWorker() async {
    final phone = _jobData?['worker_phone'] as String? ?? '';
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Worker phone number not available')),
        );
      }
      return;
    }
    final url = Uri.parse('tel:$phone');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not launch dialer',
              style: UserAppTheme.body(color: Colors.white),
            ),
            backgroundColor: UserAppTheme.urgentRed,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_realtimeChannel != null) {
      SupabaseConfig.client.removeChannel(_realtimeChannel!);
    }
    if (_priceRequestChannel != null) {
      SupabaseConfig.client.removeChannel(_priceRequestChannel!);
    }
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _lastBackgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_lastBackgroundTime != null) {
        if (DateTime.now().difference(_lastBackgroundTime!).inMinutes >= 10) {
          print('[TRACKING] App resumed after > 10 min. Force refreshing Supabase listener.');
          if (_realtimeChannel != null) {
            SupabaseConfig.client.removeChannel(_realtimeChannel!);
          }
          if (_priceRequestChannel != null) {
            SupabaseConfig.client.removeChannel(_priceRequestChannel!);
          }
          _startFirestoreListener();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_jobData == null) {
      return const Scaffold(
        backgroundColor: UserAppTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: UserAppTheme.primaryBlue),
        ),
      );
    }

    final isWorking = _jobData!['worker_ack'] == true && _jobData!['status'] == 'in_progress';
    final eta = _jobData!['worker_eta'] ?? 15;
    final workerName = _jobData!['worker_name'] ?? 'Ravi Kumar';

    return Scaffold(
      backgroundColor: UserAppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Track Booking',
          style: UserAppTheme.heading(size: 16, weight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: UserAppTheme.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Mock Map Area with beautiful gradients & animations
              Container(
                height: 240,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFEFF6FF),
                      Color(0xFFF8FAFF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(color: UserAppTheme.divider, width: 1.5),
                  boxShadow: UserAppTheme.cardShadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22.0),
                  child: Stack(
                    children: [
                      // Grid map noise/texture overlay
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: CachedNetworkImageProvider('https://www.transparenttextures.com/patterns/grid-noise.png'),
                              repeat: ImageRepeat.repeat,
                              opacity: 0.08,
                            ),
                          ),
                        ),
                      ),

                      // Animated radial rings (pulsating radar) around User
                      Positioned(
                        bottom: 50,
                        right: 90,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: UserAppTheme.primaryBlue.withValues(alpha: 0.08),
                          ),
                        ).animate(onPlay: (controller) => controller.repeat())
                            .scale(begin: const Offset(0.5, 0.5), end: const Offset(2.0, 2.0), duration: 2.seconds, curve: Curves.easeOut)
                            .fadeOut(duration: 2.seconds),
                      ),

                      // Pulsating ring around Worker (Map Background Radar)
                      Positioned(
                        top: isWorking ? 130 : 70,
                        left: isWorking ? 210 : 90,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: UserAppTheme.successGreen.withValues(alpha: 0.1),
                          ),
                        ).animate(onPlay: (controller) => controller.repeat())
                            .scale(begin: const Offset(0.6, 0.6), end: const Offset(1.8, 1.8), duration: 2.5.seconds, curve: Curves.easeOut)
                            .fadeOut(duration: 2.5.seconds),
                      ),

                      // Live badge
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: UserAppTheme.urgentRed,
                                  shape: BoxShape.circle,
                                ),
                              ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                                  .scale(begin: const Offset(1, 1), end: const Offset(1.3, 1.3), duration: 600.ms),
                              const SizedBox(width: 6),
                              Text(
                                'LIVE TRACK',
                                style: UserAppTheme.label(
                                  size: 10,
                                  color: UserAppTheme.urgentRed,
                                  weight: FontWeight.w900,
                                ).copyWith(letterSpacing: 0.8),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // User home pin
                      const Positioned(
                        bottom: 70,
                        right: 110,
                        child: Icon(Icons.home_filled, color: UserAppTheme.primaryBlue, size: 36),
                      ),
                      
                      // Worker car/scooter pin (smooth transition)
                      AnimatedPositioned(
                        duration: const Duration(seconds: 2),
                        curve: Curves.easeInOutCubic,
                        top: isWorking ? 140 : 80,
                        left: isWorking ? 220 : 100,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // Concentric primary pulse wave 1
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: UserAppTheme.primaryBlue.withValues(alpha: 0.12),
                              ),
                            )
                            .animate(onPlay: (controller) => controller.repeat())
                            .scale(begin: const Offset(0.5, 0.5), end: const Offset(2.0, 2.0), duration: 2.seconds, curve: Curves.easeOut)
                            .fadeOut(duration: 2.seconds),
                            
                            // Concentric primary pulse wave 2
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: UserAppTheme.primaryBlue.withValues(alpha: 0.08),
                              ),
                            )
                            .animate(onPlay: (controller) => controller.repeat())
                            .scale(begin: const Offset(0.5, 0.5), end: const Offset(2.0, 2.0), duration: 2.seconds, delay: 1.seconds, curve: Curves.easeOut)
                            .fadeOut(duration: 2.seconds),

                            // Main Scooter Icon Badge
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: UserAppTheme.successGreen,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  )
                                ],
                              ),
                              child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 24),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status pill or Cancelled Banner
                      if (_jobData!['status'] == 'cancelled' && _jobData!['canceller'] == 'worker')
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7), // Amber 100
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
                            boxShadow: UserAppTheme.cardShadow,
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$workerName had to cancel.',
                                textAlign: TextAlign.center,
                                style: UserAppTheme.heading(
                                  size: 15,
                                  color: const Color(0xFFD97706),
                                  weight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Finding you another helper immediately...',
                                textAlign: TextAlign.center,
                                style: UserAppTheme.body(
                                  size: 13,
                                  color: UserAppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const CircularProgressIndicator(color: Color(0xFFD97706), strokeWidth: 3),
                              const SizedBox(height: 18),
                              GestureDetector(
                                onTap: () => context.go('/user/home'),
                                child: Text(
                                  'Cancel job instead',
                                  style: UserAppTheme.label(
                                    size: 12,
                                    color: UserAppTheme.textSecondary,
                                    weight: FontWeight.bold,
                                  ).copyWith(decoration: TextDecoration.underline),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 400.ms)
                      else
                        Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation.drive(Tween<double>(begin: 0.82, end: 1.0).chain(CurveTween(curve: Curves.elasticOut))),
                                child: child,
                              );
                            },
                            child: Container(
                              key: ValueKey<String>('eta_${eta}_$isWorking'),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: isWorking ? UserAppTheme.successGreen.withValues(alpha: 0.08) : UserAppTheme.primaryBlue.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: isWorking ? UserAppTheme.successGreen : UserAppTheme.primaryBlue,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isWorking ? UserAppTheme.successGreen : UserAppTheme.primaryBlue,
                                      shape: BoxShape.circle,
                                    ),
                                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                                      .scale(begin: const Offset(1, 1), end: const Offset(1.3, 1.3), duration: 600.ms),
                                  const SizedBox(width: 8),
                                  Text(
                                    isWorking ? 'WORKING NOW' : 'ON THE WAY · ~$eta MINS',
                                    style: UserAppTheme.body(
                                      size: 13,
                                      color: isWorking ? UserAppTheme.successGreen : UserAppTheme.primaryBlue,
                                      weight: FontWeight.w900,
                                    ).copyWith(letterSpacing: 0.8),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(duration: 400.ms),
                      const SizedBox(height: 20),
                      
                      // Elapsed timer card
                      if (isWorking)
                        Container(
                          padding: const EdgeInsets.all(18),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: UserAppTheme.surface,
                            borderRadius: UserAppTheme.cardBorderRadius,
                            border: Border.all(color: UserAppTheme.divider, width: 1.0),
                            boxShadow: UserAppTheme.cardShadow,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.timer_outlined, color: UserAppTheme.primaryBlue, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                'Work in progress · $_elapsedString elapsed',
                                style: UserAppTheme.heading(
                                  size: 14,
                                  weight: FontWeight.bold,
                                  color: UserAppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 400.ms),

                      // Worker Profile Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: UserAppTheme.surface,
                          borderRadius: UserAppTheme.cardBorderRadius,
                          border: Border.all(color: UserAppTheme.divider, width: 1.0),
                          boxShadow: UserAppTheme.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: UserAppTheme.primaryBlue.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: UserAppTheme.primaryBlue.withValues(alpha: 0.2), width: 1.5),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    workerName.substring(0, 1).toUpperCase(),
                                    style: UserAppTheme.heading(
                                      size: 20,
                                      weight: FontWeight.bold,
                                      color: UserAppTheme.primaryBlue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        workerName,
                                        style: UserAppTheme.heading(
                                          size: 16,
                                          color: UserAppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            '4.9 (120 jobs done)',
                                            style: UserAppTheme.label(
                                              size: 12,
                                              color: UserAppTheme.textSecondary,
                                              weight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Divider(color: UserAppTheme.divider, height: 1),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _callWorker,
                                    icon: const Icon(Icons.phone_rounded, size: 18),
                                    label: const Text('Call Provider'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: UserAppTheme.primaryBlue,
                                      side: const BorderSide(color: UserAppTheme.primaryBlue, width: 1.5),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      textStyle: UserAppTheme.body(weight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => context.push('/user/chat/${widget.jobId}'),
                                    icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                                    label: const Text('Chat Now'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: UserAppTheme.primaryBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      textStyle: UserAppTheme.body(weight: FontWeight.bold),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 150.ms),
                      
                      // Worker no-show prompt
                      if (_jobData!['status'] == 'assigned' && _isEtaPassed && _jobData!['worker_ack'] != true)
                        Container(
                          margin: const EdgeInsets.only(top: 24),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7), // Amber 100
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Has the provider arrived yet?',
                                style: UserAppTheme.heading(
                                  size: 14,
                                  color: const Color(0xFFB45309),
                                  weight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        showModalBottomSheet(
                                          context: context,
                                          backgroundColor: UserAppTheme.background,
                                          shape: const RoundedRectangleBorder(
                                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                          ),
                                          builder: (context) => Padding(
                                            padding: const EdgeInsets.all(24.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Report Arrival Issue',
                                                  style: UserAppTheme.heading(
                                                    size: 16,
                                                    weight: FontWeight.bold,
                                                    color: UserAppTheme.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'If the provider is taking too long or not responding, you can take action below:',
                                                  style: UserAppTheme.body(color: UserAppTheme.textSecondary),
                                                ),
                                                const SizedBox(height: 20),
                                                ListTile(
                                                  leading: const Icon(Icons.phone_rounded, color: UserAppTheme.primaryBlue),
                                                  title: Text(
                                                    '1. Call provider',
                                                    style: UserAppTheme.body(weight: FontWeight.bold),
                                                  ),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    _callWorker();
                                                  },
                                                ),
                                                const Divider(color: UserAppTheme.divider),
                                                ListTile(
                                                  leading: const Icon(Icons.autorenew_rounded, color: UserAppTheme.urgentRed),
                                                  title: Text(
                                                    '2. Request replacement',
                                                    style: UserAppTheme.body(color: UserAppTheme.urgentRed, weight: FontWeight.bold),
                                                  ),
                                                  onTap: () {
                                                    print('[ERROR] Worker no show. Flagging admin and finding replacement.');
                                                    Navigator.pop(context);
                                                    context.go('/user/home');
                                                  },
                                                ),
                                                const SizedBox(height: 12),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: UserAppTheme.urgentRed, width: 1.5),
                                        foregroundColor: UserAppTheme.urgentRed,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('No, report issue'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => setState(() => _isEtaPassed = false),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: UserAppTheme.successGreen,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text("Yes, they're here"),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 400.ms),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          if (_showArrivalBanner)
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: UserAppTheme.successGreen,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: UserAppTheme.successGreen.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Worker has arrived! 🎉',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .slideY(begin: -1.5, end: 0, duration: 400.ms, curve: Curves.easeOutBack)
              .fadeOut(delay: 3200.ms, duration: 450.ms),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtimeChannel?.unsubscribe();
    _priceRequestChannel?.unsubscribe();
    _elapsedTimer?.cancel();
    super.dispose();
  }
}
