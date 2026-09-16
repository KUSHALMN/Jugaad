import 'dart:async';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jugaad_mvp/core/services/api_service.dart';
import 'package:jugaad_mvp/core/services/auth_service.dart';
import 'package:jugaad_mvp/core/theme/worker_app_theme.dart';
import 'package:jugaad_mvp/core/utils/jugaad_haptics.dart';
import 'package:jugaad_mvp/shared/widgets/jugaad_card.dart';
import 'package:jugaad_mvp/shared/widgets/jugaad_button.dart';

class ActiveJobScreen extends StatefulWidget {
  final String jobId;

  const ActiveJobScreen({super.key, required this.jobId});

  @override
  State<ActiveJobScreen> createState() => _ActiveJobScreenState();
}

class _ActiveJobScreenState extends State<ActiveJobScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  RealtimeChannel? _realtimeChannel;
  RealtimeChannel? _priceRequestChannel;
  Map<String, dynamic>? _jobData;
  Map<String, dynamic>? _pendingPriceRequest;

  Timer? _elapsedTimer;
  Timer? _tickerTimer;
  String _elapsedString = '00:00:00';
  bool _isActioning = false;
  DateTime? _lastBackgroundTime;
  Timer? _loadingTimeout;

  late AnimationController _progressController;
  late AnimationController _pulseController;
  late AnimationController _earningsController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this, duration: 1000.ms)..forward();
    _pulseController = AnimationController(vsync: this, duration: 1200.ms)..repeat(reverse: true);
    _earningsController = AnimationController(vsync: this, duration: 800.ms)..forward();
    
    _earningsController.addStatusListener((s) {
      if (s == AnimationStatus.completed) JugaadHaptics.success();
    });

    WidgetsBinding.instance.addObserver(this);
    _startRealtimeListener();

    // Failsafe: if still loading after 10s, force empty state
    _loadingTimeout = Timer(const Duration(seconds: 10), () {
      if (mounted && _jobData == null) {
        print('[ACTIVE_JOB] Loading timeout reached — forcing empty state');
        setState(() {
          _jobData = {};
        });
      }
    });
  }

  void _subscribeToJobRealtime(String jobId) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = SupabaseConfig.client
        .channel('public:jobs')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: jobId,
          ),
          callback: (payload) {
            if (!mounted) return;
            print('[ACTIVE_JOB] Supabase realtime event: ${payload.eventType}');
            final data = payload.newRecord;
            if (data.isEmpty) return;
            
            _onJobDataUpdate(data);
          },
        )
        .subscribe();
  }

  void _subscribeToPriceRequestsRealtime(String jobId) {
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
            value: jobId,
          ),
          callback: (payload) {
            if (!mounted) return;
            print('[ACTIVE_JOB] Price change request realtime event: ${payload.eventType}');
            final data = payload.newRecord;
            if (data.isEmpty) {
              setState(() => _pendingPriceRequest = null);
              return;
            }
            final status = data['status'] as String?;
            if (status == 'pending') {
              setState(() => _pendingPriceRequest = data);
            } else {
              setState(() => _pendingPriceRequest = null);
            }
          },
        )
        .subscribe();
  }

  void _startRealtimeListener() {
    if (widget.jobId.isNotEmpty) {
      _subscribeToJobRealtime(widget.jobId);
      _subscribeToPriceRequestsRealtime(widget.jobId);
    }
    _fetchInitialJobState();
  }

  Future<void> _fetchPendingPriceRequest(String jobId) async {
    try {
      final reqs = await SupabaseConfig.client
          .from('price_change_requests')
          .select()
          .eq('job_id', jobId)
          .eq('status', 'pending')
          .maybeSingle();
      if (mounted) {
        setState(() {
          _pendingPriceRequest = reqs;
        });
      }
    } catch (e) {
      print('[ACTIVE_JOB] Error fetching pending price request: $e');
    }
  }

  Future<void> _fetchInitialJobState() async {
    try {
      String targetJobId = widget.jobId;
      if (targetJobId.isEmpty) {
        final uid = AuthService().currentUser?.uid;
        if (uid != null) {
          final activeJobs = await SupabaseConfig.client
              .from('jobs')
              .select()
              .eq('worker_id', uid)
              .inFilter('status', ['accepted', 'in_progress'])
              .order('created_at', ascending: false)
              .limit(1);
          if (activeJobs.isNotEmpty) {
            targetJobId = activeJobs.first['id'] as String;
          }
        }
      }

      if (targetJobId.isEmpty) {
        if (mounted) {
          setState(() {
            _jobData = {}; // Empty map represents no active jobs
          });
        }
        return;
      }

      final doc = await SupabaseConfig.client
          .from('jobs')
          .select()
          .eq('id', targetJobId)
          .maybeSingle();
      if (doc != null && mounted) {
        _onJobDataUpdate(doc);
        _subscribeToJobRealtime(targetJobId);
        _subscribeToPriceRequestsRealtime(targetJobId);
        _fetchPendingPriceRequest(targetJobId);
      } else {
        if (mounted) {
          setState(() {
            _jobData = {};
          });
        }
      }
    } catch (e) {
      print('[ACTIVE_JOB] Error fetching initial job state: $e');
      if (mounted) {
        setState(() {
          _jobData = {};
        });
      }
    }
  }

  void _onJobDataUpdate(Map<String, dynamic> data) {
    _loadingTimeout?.cancel();
    setState(() => _jobData = data);

    final status = data['status'] as String? ?? 'accepted';
    final workerAck = data['worker_ack'] as bool? ?? false;

    if (status == 'accepted' || (status == 'in_progress' && !workerAck)) {
      _progressController.animateTo(0.25);
    } else if (status == 'in_progress' && workerAck) {
      _progressController.animateTo(0.7);
    } else if (status == 'completed') {
      _progressController.animateTo(1.0);
    }

    _updateTicker();

    if (data['payment_status'] == 'released') {
      _handlePaymentReceived();
    }
  }

  void _updateTicker() {
    final status = _jobData?['status'] as String?;
    final preArrivalCheckedAtStr = _jobData?['pre_arrival_checked_at'] as String?;
    final onTheWayConfirmedAtStr = _jobData?['on_the_way_confirmed_at'] as String?;
    final isPreArrivalPending = preArrivalCheckedAtStr != null && onTheWayConfirmedAtStr == null;

    final needsTicker = status == 'in_progress' || (status == 'accepted' && isPreArrivalPending);
    if (needsTicker) {
      if (_tickerTimer == null || !_tickerTimer!.isActive) {
        _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() {
            // Update _elapsedString
            final startedAt = _jobData?['started_at'];
            if (startedAt is String) {
              final startTime = DateTime.tryParse(startedAt)?.toLocal() ?? DateTime.now();
              final duration = DateTime.now().difference(startTime);
              final hours = duration.inHours.toString().padLeft(2, '0');
              final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
              final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
              _elapsedString = '$hours:$minutes:$seconds';
            }
          });
        });
      }
    } else {
      _tickerTimer?.cancel();
      _tickerTimer = null;
    }
  }

  Future<void> _callCustomer() async {
    final phone = _jobData?['customer_phone'] as String? ?? _jobData?['employer_phone'] as String? ?? '';
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer phone number not available')),
        );
      }
      return;
    }
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }


  Future<void> _confirmOnTheWay() async {
    setState(() => _isActioning = true);
    try {
      await ApiService().confirmOnTheWay(widget.jobId);
      JugaadHaptics.success();
    } catch (e) {
      print('[ACTIVE_JOB] Confirm on the way failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not confirm status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Future<void> _markArrived() async {
    setState(() => _isActioning = true);
    try {
      await ApiService().ackJob(widget.jobId);
    } catch (e) {
      print('[ACTIVE_JOB] Ack failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not mark arrived: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  void _showCompletionSheet() {
    final amount = _jobData?['amount'] ?? 350;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      backgroundColor: WorkerAppTheme.background,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: WorkerAppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: WorkerAppTheme.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: WorkerAppTheme.primaryGreen, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              'Ready to mark this done?',
              style: WorkerAppTheme.heading(color: WorkerAppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll earn ₹$amount for this job.',
              style: WorkerAppTheme.display(
                size: 24,
                color: WorkerAppTheme.primaryGreen,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Customer will confirm on their end.',
              style: WorkerAppTheme.body(color: WorkerAppTheme.textSecondary, size: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            JugaadButton(
              text: 'Confirm Completion',
              onPressed: () {
                Navigator.pop(ctx);
                _markCompleted();
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Not yet',
                style: WorkerAppTheme.body(
                  color: WorkerAppTheme.textSecondary,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markCompleted() async {
    setState(() => _isActioning = true);
    try {
      await ApiService().completeJob(widget.jobId, confirmer: 'worker');
    } catch (e) {
      print('[ACTIVE_JOB] Complete failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not complete job: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  void _handlePaymentReceived() {
    final amount = _jobData?['amount'] ?? 350;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              '₹$amount added to your earnings!',
              style: WorkerAppTheme.body(
                color: Colors.white,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
        backgroundColor: WorkerAppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    if (mounted) context.go('/worker/home');
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    _progressController.dispose();
    _pulseController.dispose();
    _earningsController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (_realtimeChannel != null) {
      SupabaseConfig.client.removeChannel(_realtimeChannel!);
    }
    if (_priceRequestChannel != null) {
      SupabaseConfig.client.removeChannel(_priceRequestChannel!);
    }
    _elapsedTimer?.cancel();
    _tickerTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _lastBackgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_lastBackgroundTime != null) {
        if (DateTime.now()
                .difference(_lastBackgroundTime!)
                .inMinutes >=
            10) {
          if (_realtimeChannel != null) {
            SupabaseConfig.client.removeChannel(_realtimeChannel!);
          }
          _startRealtimeListener();
        }
      }
    }
  }

  String _formatCountdown(int seconds) {
    if (seconds <= 0) return '00:00';
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showPriceChangeDialog() {
    final currentPrice = _jobData?['agreed_price'] ?? _jobData?['amount'] ?? 0.0;
    final priceController = TextEditingController();
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: WorkerAppTheme.surface,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: WorkerAppTheme.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Propose Price Change',
                  style: WorkerAppTheme.heading(size: 20, color: WorkerAppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current agreed price is ₹$currentPrice. Propose a new price if the work scope has changed.',
                  style: WorkerAppTheme.body(color: WorkerAppTheme.textSecondary, size: 13),
                ),
                const SizedBox(height: 20),
                Text(
                  'New Price (₹)',
                  style: WorkerAppTheme.label(color: WorkerAppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: WorkerAppTheme.body(size: 16),
                  decoration: InputDecoration(
                    hintText: 'e.g. 500',
                    filled: true,
                    fillColor: WorkerAppTheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a price';
                    }
                    final p = double.tryParse(val);
                    if (p == null || p <= 0) {
                      return 'Please enter a valid positive price';
                    }
                    if (p == currentPrice) {
                      return 'New price must be different from current price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Reason for Change',
                  style: WorkerAppTheme.label(color: WorkerAppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: reasonController,
                  maxLines: 3,
                  style: WorkerAppTheme.body(size: 14),
                  decoration: InputDecoration(
                    hintText: 'Explain why the price changed (e.g. extra work needed)...',
                    filled: true,
                    fillColor: WorkerAppTheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please provide a reason';
                    }
                    if (val.trim().length < 5) {
                      return 'Please enter a more descriptive reason';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: WorkerAppTheme.label(color: WorkerAppTheme.textSecondary, size: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: JugaadButton(
                        text: 'Submit Proposal',
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            final newPrice = double.parse(priceController.text);
                            final reason = reasonController.text.trim();
                            Navigator.pop(context);
                            _submitPriceChange(newPrice, reason);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitPriceChange(double newPrice, String reason) async {
    setState(() => _isActioning = true);
    try {
      await ApiService().requestPriceChange(widget.jobId, newPrice, reason);
      JugaadHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Price change proposal sent to customer'),
            backgroundColor: WorkerAppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      print('[ACTIVE_JOB] Propose price failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to propose price change: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Widget _buildPriceCard() {
    final agreedPrice = _jobData?['agreed_price'] ?? _jobData?['amount'] ?? 0.0;
    final isPending = _pendingPriceRequest != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WorkerAppTheme.surface,
        borderRadius: WorkerAppTheme.cardBorderRadius,
        boxShadow: WorkerAppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.currency_rupee, color: WorkerAppTheme.earningGold, size: 20),
              const SizedBox(width: 8),
              Text(
                'Job Pricing & Earnings',
                style: WorkerAppTheme.body(weight: FontWeight.w700, color: WorkerAppTheme.textPrimary),
              ),
              const Spacer(),
              Text(
                '₹$agreedPrice',
                style: WorkerAppTheme.display(size: 20, color: WorkerAppTheme.textPrimary),
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: WorkerAppTheme.earningGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: WorkerAppTheme.earningGold.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: WorkerAppTheme.earningGold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pending Approval: ₹${_pendingPriceRequest!['new_price']}',
                        style: WorkerAppTheme.label(color: WorkerAppTheme.earningGold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reason: ${_pendingPriceRequest!['reason']}',
                    style: WorkerAppTheme.body(size: 12, color: WorkerAppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showPriceChangeDialog,
                icon: const Icon(Icons.edit_road_rounded, color: WorkerAppTheme.earningGold, size: 16),
                label: Text(
                  'Request Price Change',
                  style: WorkerAppTheme.label(color: WorkerAppTheme.earningGold, size: 13),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: WorkerAppTheme.earningGold, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, _) {
        final val = _progressController.value;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStep(0, 'Arrived', val >= 0.25, val > 0.5),
              _buildConnector(val, 0.25, 0.7),
              _buildStep(1, 'Started', val >= 0.7, val > 0.8),
              _buildConnector(val, 0.7, 1.0),
              _buildStep(2, 'Done', val >= 1.0, val >= 1.0),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStep(int index, String label, bool isActive, bool isCompleted) {
    return Column(
      children: [
        AnimatedContainer(
          duration: 300.ms,
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? WorkerAppTheme.primaryGreen
                : isActive
                    ? WorkerAppTheme.primaryGreen
                    : Colors.transparent,
            border: Border.all(
              color: isActive ? WorkerAppTheme.primaryGreen : Colors.grey.shade400,
              width: 2,
            ),
            boxShadow: isActive && !isCompleted
                ? [
                    BoxShadow(
                      color: WorkerAppTheme.primaryGreen.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
          child: isCompleted
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : isActive
                  ? const Center(
                      child: Icon(Icons.circle, color: Colors.white, size: 10),
                    )
                  : null,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: WorkerAppTheme.label(
            size: 11,
            color: isCompleted || isActive
                ? WorkerAppTheme.primaryGreen
                : WorkerAppTheme.textSecondary,
          ).copyWith(
            fontWeight: isCompleted || isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(double progress, double start, double end) {
    final fillRatio = ((progress - start) / (end - start)).clamp(0.0, 1.0);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(top: 15),
        height: 3,
        alignment: Alignment.centerLeft,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(height: 3, color: Colors.grey.shade300),
            FractionallySizedBox(
              widthFactor: fillRatio,
              child: Container(
                height: 3,
                color: WorkerAppTheme.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    final customerName = _jobData?['customer_name'] as String? ?? 'Customer';
    final initials = customerName.isNotEmpty ? customerName.substring(0, 1).toUpperCase() : 'C';
    final addressText = _jobData?['address'] as String? ?? 'No address provided';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WorkerAppTheme.surface,
        borderRadius: WorkerAppTheme.cardBorderRadius,
        boxShadow: WorkerAppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: WorkerAppTheme.heading(
                    size: 20,
                    color: WorkerAppTheme.trustBlue,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: WorkerAppTheme.heading(size: 16, color: WorkerAppTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: _callCustomer,
                      child: Text(
                        _jobData?['customer_phone'] as String? ?? '9876543210',
                        style: WorkerAppTheme.body(
                          size: 13,
                          color: WorkerAppTheme.trustBlue,
                        ).copyWith(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: WorkerAppTheme.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  addressText,
                  style: WorkerAppTheme.body(
                    size: 13,
                    color: WorkerAppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _callCustomer,
                  icon: const Icon(Icons.phone_rounded, color: WorkerAppTheme.primaryGreen, size: 16),
                  label: Text(
                    'Call',
                    style: WorkerAppTheme.label(color: WorkerAppTheme.primaryGreen, size: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: WorkerAppTheme.primaryGreen, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.go('/worker/chat?job_id=${widget.jobId}');
                  },
                  icon: const Icon(Icons.chat_bubble_rounded, color: WorkerAppTheme.trustBlue, size: 16),
                  label: Text(
                    'Chat',
                    style: WorkerAppTheme.label(color: WorkerAppTheme.trustBlue, size: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: WorkerAppTheme.trustBlue, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJobTimerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WorkerAppTheme.surface,
        borderRadius: WorkerAppTheme.cardBorderRadius,
        boxShadow: WorkerAppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.timer_rounded, color: WorkerAppTheme.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Job timer: Active',
                style: WorkerAppTheme.body(weight: FontWeight.w700, color: WorkerAppTheme.textPrimary),
              ),
              const Spacer(),
              Text(
                _elapsedString,
                style: WorkerAppTheme.display(size: 20, color: WorkerAppTheme.primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_progressController.value * 0.7).clamp(0.1, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(WorkerAppTheme.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_jobData == null) {
      return Scaffold(
        backgroundColor: WorkerAppTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: WorkerAppTheme.primaryGreen),
              const SizedBox(height: 16),
              Text(
                'Loading job details...',
                style: WorkerAppTheme.body(color: WorkerAppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_jobData!.isEmpty) {
      return Scaffold(
        backgroundColor: WorkerAppTheme.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: WorkerAppTheme.primaryGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in_rounded,
                    color: WorkerAppTheme.primaryGreen,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Active Jobs',
                  style: WorkerAppTheme.heading(size: 20, color: WorkerAppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'You don\'t have any job in progress right now. Go online on the home tab to start receiving requests.',
                  textAlign: TextAlign.center,
                  style: WorkerAppTheme.body(color: WorkerAppTheme.textSecondary, size: 14),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 200,
                  child: JugaadButton(
                    text: 'Go to Home',
                    onPressed: () {
                      context.go('/worker/home');
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final status = _jobData!['status'] as String? ?? 'accepted';
    final workerAck = _jobData!['worker_ack'] as bool? ?? false;

    if (status == 'accepted' ||
        (status == 'in_progress' && !workerAck)) {
      return _buildEnRouteState();
    } else if (status == 'in_progress' && workerAck) {
      return _buildWorkingState();
    } else if (status == 'completed') {
      return _buildWrapUpState();
    }

    return Scaffold(
        backgroundColor: WorkerAppTheme.background,
        body: Center(
            child: Text('Unknown state',
                style: WorkerAppTheme.body(color: WorkerAppTheme.textSecondary))));
  }

  // ─── STATE 1: EN ROUTE ──────────────────────────────────────
  Widget _buildEnRouteState() {
    final jobLocation = _jobData?['location'];
    double? userLat;
    double? userLng;
    if (jobLocation is String) {
      if (jobLocation.contains('POINT')) {
        final match = RegExp(r'POINT\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)').firstMatch(jobLocation);
        if (match != null && match.groupCount == 2) {
          userLng = double.tryParse(match.group(1)!);
          userLat = double.tryParse(match.group(2)!);
        }
      }
    } else if (jobLocation is Map) {
      final coords = jobLocation['coordinates'];
      if (coords is List && coords.length >= 2) {
        userLng = double.tryParse(coords[0].toString());
        userLat = double.tryParse(coords[1].toString());
      }
    }

    final detailsCard = JugaadCard(
      animate: false,
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JOB DETAILS',
            style: WorkerAppTheme.label(color: WorkerAppTheme.textSecondary, size: 11),
          ),
          const SizedBox(height: 10),
          Text(
            _jobData!['service'] as String? ?? 'Service',
            style: WorkerAppTheme.heading(size: 16, color: WorkerAppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            _jobData!['description'] as String? ?? 'No description provided.',
            style: WorkerAppTheme.body(
              color: WorkerAppTheme.textSecondary,
              size: 13,
            ).copyWith(fontStyle: FontStyle.italic, height: 1.5),
            maxLines: 3,
          ),
        ],
      ),
    );

    final preArrivalCheckedAtStr = _jobData!['pre_arrival_checked_at'] as String?;
    final onTheWayConfirmedAtStr = _jobData!['on_the_way_confirmed_at'] as String?;
    final isPreArrivalPending = preArrivalCheckedAtStr != null && onTheWayConfirmedAtStr == null;

    int remainingSeconds = 0;
    if (isPreArrivalPending) {
      final checkedAt = DateTime.tryParse(preArrivalCheckedAtStr)?.toLocal();
      if (checkedAt != null) {
        final deadline = checkedAt.add(const Duration(minutes: 5));
        remainingSeconds = deadline.difference(DateTime.now()).inSeconds;
      }
    }

    Widget? preArrivalAlertCard;
    if (isPreArrivalPending && remainingSeconds > -30) {
      final countdownStr = _formatCountdown(remainingSeconds);
      preArrivalAlertCard = AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: WorkerAppTheme.urgentRed.withValues(alpha: 0.1),
              borderRadius: WorkerAppTheme.cardBorderRadius,
              border: Border.all(
                color: WorkerAppTheme.urgentRed.withValues(alpha: 0.3 + (_pulseController.value * 0.5)),
                width: 2,
              ),
            ),
            child: child,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: WorkerAppTheme.urgentRed, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Pre-Arrival Check Required!',
                  style: WorkerAppTheme.heading(size: 15, color: WorkerAppTheme.urgentRed),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: WorkerAppTheme.urgentRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    countdownStr,
                    style: WorkerAppTheme.label(color: Colors.white, weight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Please confirm that you are on the way immediately. Failure to confirm will result in automatic reassignment of this job and a penalty strike on your account.",
              style: WorkerAppTheme.body(size: 12, color: WorkerAppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: WorkerAppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: WorkerAppTheme.textPrimary),
          onPressed: () => context.go('/worker/home'),
        ),
        title: Text('Active Job',
            style: WorkerAppTheme.heading(color: WorkerAppTheme.textPrimary, size: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: WorkerAppTheme.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'En Route',
                  style: WorkerAppTheme.label(color: WorkerAppTheme.primaryGreen, size: 11),
                ),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  preArrivalAlertCard ?? const SizedBox.shrink(),
                  // Mock map
                  MockMiniMap(
                    height: 180,
                    userLat: userLat,
                    userLng: userLng,
                  ),
                  const SizedBox(height: 20),
                  // Customer Card
                  _buildCustomerCard().animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 20),
                  // Job details card
                  (detailsCard as Widget).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: isPreArrivalPending
                ? JugaadButton(
                    text: "Confirm I'm On My Way",
                    onPressed: _confirmOnTheWay,
                    isLoading: _isActioning,
                  )
                : SlideToConfirm(
                    label: 'Slide to mark arrived →',
                    onConfirm: _markArrived,
                    isLoading: _isActioning,
                  ),
          ),
        ],
      ),
    );
  }

  // ─── STATE 2: WORKING ────────────────────────────────────────
  Widget _buildWorkingState() {
    return Scaffold(
      backgroundColor: WorkerAppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: WorkerAppTheme.textPrimary),
          onPressed: () => context.go('/worker/home'),
        ),
        title: Text('Active Job',
            style: WorkerAppTheme.heading(color: WorkerAppTheme.textPrimary, size: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: WorkerAppTheme.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'In Progress',
                  style: WorkerAppTheme.label(color: WorkerAppTheme.primaryGreen, size: 11),
                ),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildJobTimerCard().animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 20),
                  _buildPriceCard().animate().fadeIn(duration: 400.ms, delay: 50.ms),
                  const SizedBox(height: 20),
                  _buildCustomerCard().animate().fadeIn(duration: 400.ms, delay: 100.ms),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SlideToConfirm(
              label: 'Slide to mark completed →',
              onConfirm: _showCompletionSheet,
              isLoading: _isActioning,
            ),
          ),
        ],
      ),
    );
  }

  // ─── STATE 3: WRAP-UP ─────────────────────────────────────────
  Widget _buildWrapUpState() {
    final amount = _jobData!['amount'] as int? ?? 350;

    return Scaffold(
      backgroundColor: WorkerAppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: WorkerAppTheme.primaryGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emoji_events_rounded,
                            color: WorkerAppTheme.primaryGreen, size: 50),
                      )
                          .animate()
                          .scale(
                              begin: const Offset(0.5, 0.5),
                              end: const Offset(1.0, 1.0),
                              curve: Curves.easeOutBack,
                              duration: 600.ms)
                          .fadeIn(duration: 400.ms),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: WorkerAppTheme.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          'Job Marked Complete! 🎉',
                          style: WorkerAppTheme.heading(color: WorkerAppTheme.primaryGreen, size: 16),
                        ),
                      ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                      const SizedBox(height: 16),
                      Text(
                        'Waiting for customer payment...',
                        style: WorkerAppTheme.body(color: WorkerAppTheme.textSecondary),
                      ).animate().fadeIn(delay: 500.ms, duration: 350.ms),
                      const SizedBox(height: 24),
                      // Animated earnings counter
                      AnimatedBuilder(
                        animation: _earningsController,
                        builder: (context, _) {
                          final displayAmount = (amount * _earningsController.value);
                          return Column(
                            children: [
                              Text(
                                "You'll earn",
                                style: WorkerAppTheme.label(color: WorkerAppTheme.textSecondary, size: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${displayAmount.toStringAsFixed(0)}',
                                style: WorkerAppTheme.display(
                                  size: 44,
                                  color: WorkerAppTheme.primaryGreen,
                                ),
                              ),
                            ],
                          );
                        },
                      ).animate().fadeIn(delay: 600.ms, duration: 500.ms),
                      const SizedBox(height: 48),
                      const CircularProgressIndicator(
                        color: WorkerAppTheme.primaryGreen,
                        strokeWidth: 3,
                      ).animate().fadeIn(delay: 800.ms, duration: 350.ms),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CUSTOM SLIDE TO CONFIRM WIDGET ────────────────────────────
class SlideToConfirm extends StatefulWidget {
  final String label;
  final VoidCallback onConfirm;
  final bool isLoading;

  const SlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirm,
    this.isLoading = false,
  });

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  double _dragProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double trackWidth = constraints.maxWidth;
        final double thumbSize = 50.0;
        final double maxDragDistance = trackWidth - thumbSize - 6.0;

        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: widget.isLoading
                ? WorkerAppTheme.primaryGreen.withValues(alpha: 0.6)
                : WorkerAppTheme.primaryGreen,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: WorkerAppTheme.primaryGreen.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Center(
                child: Opacity(
                  opacity: (1.0 - _dragProgress).clamp(0.2, 1.0),
                  child: Text(
                    widget.isLoading ? 'Processing...' : widget.label,
                    style: WorkerAppTheme.heading(
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 3.0 + (_dragProgress * maxDragDistance),
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (widget.isLoading) return;
                    setState(() {
                      _dragProgress += details.primaryDelta! / maxDragDistance;
                      _dragProgress = _dragProgress.clamp(0.0, 1.0);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (widget.isLoading) return;
                    if (_dragProgress >= 0.85) {
                      HapticFeedback.lightImpact();
                      widget.onConfirm();
                      setState(() {
                        _dragProgress = 1.0;
                      });
                    } else {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _dragProgress = 0.0;
                      });
                    }
                  },
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: WorkerAppTheme.primaryGreen,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_forward_rounded,
                              color: WorkerAppTheme.primaryGreen,
                              size: 24,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── MOCK MINI MAP WIDGET WITH VECTOR PAINTING ──────────────────
class MockMiniMap extends StatelessWidget {
  final double height;
  final double radius;
  final double? userLat;
  final double? userLng;

  const MockMiniMap({
    super.key,
    this.height = 180.0,
    this.radius = 12.0,
    this.userLat,
    this.userLng,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: WorkerAppTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: MapVectorPainter(),
              ),
            ),
            const Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MapPulseRing(),
                  Icon(
                    Icons.location_on_rounded,
                    color: WorkerAppTheme.urgentRed,
                    size: 36,
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: () async {
                  if (userLat != null && userLng != null) {
                    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$userLat,$userLng');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User location not available')),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.navigation_rounded,
                        color: WorkerAppTheme.primaryGreen,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Navigate →',
                        style: WorkerAppTheme.label(
                          color: WorkerAppTheme.primaryGreen,
                          size: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MapPulseRing extends StatefulWidget {
  const MapPulseRing({super.key});

  @override
  State<MapPulseRing> createState() => _MapPulseRingState();
}

class _MapPulseRingState extends State<MapPulseRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 50 * _pulseController.value,
          height: 50 * _pulseController.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: WorkerAppTheme.urgentRed.withValues(alpha: 1.0 - _pulseController.value),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

class MapVectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.5), paint);
    canvas.drawLine(Offset(size.width * 0.4, 0), Offset(size.width * 0.6, size.height), paint);
    canvas.drawLine(Offset(0, size.height * 0.8), Offset(size.width, size.height * 0.7), paint);

    final greenPaint = Paint()
      ..color = const Color(0xFFC8E6C9)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12, 12, size.width * 0.25, size.height * 0.25),
        const Radius.circular(8),
      ),
      greenPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.7, size.height * 0.6, size.width * 0.2, size.height * 0.35),
        const Radius.circular(8),
      ),
      greenPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
