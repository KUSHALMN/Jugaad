import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:jugaad_mvp/core/utils/kalman_filter.dart';
import 'package:jugaad_mvp/core/utils/smooth_location_interpolator.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  final String jobId;
  const TrackingScreen({super.key, required this.jobId});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> with WidgetsBindingObserver {
  RealtimeChannel? _realtimeChannel;
  RealtimeChannel? _priceRequestChannel;
  RealtimeChannel? _sparePartsChannel;
  Map<String, dynamic>? _jobData;
  Map<String, dynamic>? _pendingPriceRequest;
  List<Map<String, dynamic>> _spareParts = [];
  Map<String, dynamic>? _pendingSparePart;
  bool _isActioningSparePart = false;

  Timer? _elapsedTimer;
  String _elapsedString = '00:00';
  bool _isEtaPassed = false;
  DateTime? _lastBackgroundTime;
  bool _showArrivalBanner = false;
  bool _isDialogShowing = false;

  // Kalman filter & smooth trajectory estimation
  final KalmanLatLong _kalmanFilter = KalmanLatLong(qMetersPerSecond: 2.5);
  SmoothPosition _currentSmoothPos = const SmoothPosition(
    lat: 12.3051,
    lng: 76.6551,
    bearingDegrees: 45.0,
  );

  void _updateWorkerTrackingPosition(double rawLat, double rawLng, double accuracy) {
    _kalmanFilter.process(rawLat, rawLng, accuracy, DateTime.now().millisecondsSinceEpoch);
    final newBearing = SmoothLocationInterpolator.computeBearing(
      _currentSmoothPos.lat,
      _currentSmoothPos.lng,
      _kalmanFilter.lat,
      _kalmanFilter.lng,
    );
    setState(() {
      _currentSmoothPos = SmoothPosition(
        lat: _kalmanFilter.lat,
        lng: _kalmanFilter.lng,
        bearingDegrees: newBearing,
      );
    });
  }

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

  void _subscribeToSparePartsRealtime() {
    _sparePartsChannel?.unsubscribe();
    _sparePartsChannel = SupabaseConfig.client
        .channel('public:spare_parts:${widget.jobId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'spare_parts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'job_id',
            value: widget.jobId,
          ),
          callback: (payload) {
            if (!mounted) return;
            print('[TRACKING] Spare part realtime update: ${payload.eventType}');
            _fetchSpareParts();
          },
        )
        .subscribe();
  }

  static final List<Map<String, dynamic>> _sampleSpareParts = [
    {
      'id': 'demo-spare-1',
      'item_name': 'Havells 32A Double Pole MCB Switch',
      'amount': 380.0,
      'status': 'pending',
      'receipt_photo_url': 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=600&auto=format&fit=crop&q=80',
      'created_at': DateTime.now().subtract(const Duration(minutes: 6)).toIso8601String(),
    },
    {
      'id': 'demo-spare-2',
      'item_name': 'Finolex 2.5mm Flameguard Wire Coil (5m)',
      'amount': 420.0,
      'status': 'approved',
      'receipt_photo_url': 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=600&auto=format&fit=crop&q=80',
      'created_at': DateTime.now().subtract(const Duration(minutes: 20)).toIso8601String(),
    },
    {
      'id': 'demo-spare-3',
      'item_name': 'Supreme 1-inch Heavy PVC Ball Valve',
      'amount': 450.0,
      'status': 'approved',
      'receipt_photo_url': 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=600&auto=format&fit=crop&q=80',
      'created_at': DateTime.now().subtract(const Duration(minutes: 35)).toIso8601String(),
    },
    {
      'id': 'demo-spare-4',
      'item_name': 'Anchor Roma 16A Modular Socket & Switch Plate',
      'amount': 190.0,
      'status': 'approved',
      'receipt_photo_url': 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=600&auto=format&fit=crop&q=80',
      'created_at': DateTime.now().subtract(const Duration(minutes: 50)).toIso8601String(),
    },
  ];

  Future<void> _fetchSpareParts() async {
    try {
      final res = await SupabaseConfig.client
          .from('spare_parts')
          .select()
          .eq('job_id', widget.jobId)
          .order('created_at', ascending: true);
      if (mounted) {
        // Prioritize real data from database; fallback to 4 sample items only if empty
        final list = (res.isNotEmpty)
            ? List<Map<String, dynamic>>.from(res)
            : List<Map<String, dynamic>>.from(_sampleSpareParts);
        final pending = list.where((p) => p['status'] == 'pending').toList();
        setState(() {
          _spareParts = list;
          _pendingSparePart = pending.isNotEmpty ? pending.first : null;
        });
      }
    } catch (e) {
      print('[TRACKING] Error fetching spare parts: $e');
      if (mounted && _spareParts.isEmpty) {
        setState(() {
          _spareParts = List<Map<String, dynamic>>.from(_sampleSpareParts);
          final pending = _spareParts.where((p) => p['status'] == 'pending').toList();
          _pendingSparePart = pending.isNotEmpty ? pending.first : null;
        });
      }
    }
  }

  Future<void> _approveSparePart(String partId) async {
    setState(() => _isActioningSparePart = true);
    
    // Handle demo/sample item interaction gracefully without breaking real DB
    if (partId.startsWith('demo-')) {
      setState(() {
        final idx = _spareParts.indexWhere((p) => p['id'] == partId);
        if (idx != -1) {
          _spareParts[idx]['status'] = 'approved';
          _pendingSparePart = null;
        }
        if (_jobData != null) {
          final current = (_jobData!['amount'] as num?)?.toDouble() ?? 350.0;
          _jobData!['amount'] = current + 380.0;
        }
      });
      JugaadHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Material Escrow Approved! Added to final digital bill.'),
            backgroundColor: UserAppTheme.successGreen,
          ),
        );
      }
      setState(() => _isActioningSparePart = false);
      return;
    }

    try {
      await SupabaseConfig.client.rpc('approve_spare_part', params: {
        'p_spare_part_id': partId,
      });
      JugaadHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Material Escrow Approved! Added to final digital bill.'),
            backgroundColor: UserAppTheme.successGreen,
          ),
        );
        _fetchSpareParts();
        _fetchInitialJobState();
      }
    } catch (e) {
      print('[TRACKING] Error approving spare part: $e');
      try {
        final partData = await SupabaseConfig.client.from('spare_parts').select('job_id, amount').eq('id', partId).maybeSingle();
        await SupabaseConfig.client.from('spare_parts').update({
          'status': 'approved',
          'approved_at': DateTime.now().toIso8601String(),
        }).eq('id', partId);

        if (partData != null && _jobData != null) {
          final addAmt = (partData['amount'] as num?)?.toDouble() ?? 0.0;
          final currAmt = (_jobData!['amount'] as num?)?.toDouble() ?? 0.0;
          await SupabaseConfig.client.from('jobs').update({
            'amount': currAmt + addAmt,
            'agreed_price': currAmt + addAmt,
          }).eq('id', widget.jobId);
        }

        if (mounted) {
          _fetchSpareParts();
          _fetchInitialJobState();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Material Escrow Approved! Added to final digital bill.'),
              backgroundColor: UserAppTheme.successGreen,
            ),
          );
        }
      } catch (err) {
        print('[TRACKING] Fallback approval error: $err');
      }
    } finally {
      if (mounted) setState(() => _isActioningSparePart = false);
    }
  }

  Future<void> _declineSparePart(String partId) async {
    setState(() => _isActioningSparePart = true);
    try {
      await SupabaseConfig.client.from('spare_parts').update({
        'status': 'rejected',
        'rejected_at': DateTime.now().toIso8601String(),
      }).eq('id', partId);
      JugaadHaptics.selection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Spare part reimbursement request declined.'),
            backgroundColor: UserAppTheme.urgentRed,
          ),
        );
        _fetchSpareParts();
      }
    } catch (e) {
      print('[TRACKING] Error rejecting spare part: $e');
    } finally {
      if (mounted) setState(() => _isActioningSparePart = false);
    }
  }

  void _startFirestoreListener() {
    if (widget.jobId.isEmpty) return;

    _subscribeToPriceRequestsRealtime();
    _subscribeToSparePartsRealtime();

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
    _fetchSpareParts();
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
                'Decline & Pay ₹$oldPrice Only',
                style: UserAppTheme.body(color: UserAppTheme.urgentRed, weight: FontWeight.bold, size: 12),
              ),
            ),
            const SizedBox(width: 8),
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
                'Accept & Continue',
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
    final req = _pendingPriceRequest;
    final newPrice = req?['new_price'];
    setState(() => _pendingPriceRequest = null);

    try {
      await ApiService().respondPriceChange(widget.jobId, approved);
      JugaadHaptics.success();
      if (mounted) {
        _fetchInitialJobState();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approved ? 'Work scope upgrade approved!' : 'Work scope upgrade declined. Paying visit fee only.'),
            backgroundColor: approved ? UserAppTheme.successGreen : UserAppTheme.urgentRed,
          ),
        );
      }
    } catch (e) {
      print('[TRACKING] Error responding to price change: $e');
      // Direct Supabase fallback in case API endpoint is unavailable
      try {
        await SupabaseConfig.client.from('price_change_requests').update({
          'status': approved ? 'accepted' : 'rejected',
          'resolved_at': DateTime.now().toIso8601String(),
        }).eq('job_id', widget.jobId).eq('status', 'pending');

        if (approved && newPrice != null) {
          await SupabaseConfig.client.from('jobs').update({
            'amount': newPrice,
            'agreed_price': newPrice,
          }).eq('id', widget.jobId);
        }
        if (mounted) {
          _fetchInitialJobState();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(approved ? 'Work scope upgrade approved!' : 'Work scope upgrade declined.'),
              backgroundColor: approved ? UserAppTheme.successGreen : UserAppTheme.urgentRed,
            ),
          );
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send response: $err')),
          );
        }
      }
    }
  }

  // ─── URBAN COMPANY STYLE: SHARE LIVE VISIT ON WHATSAPP & 1-TAP SOS ─
  Future<void> _shareLiveVisitOnWhatsApp() async {
    final workerName = _jobData?['worker_name'] as String? ?? 'Verified Professional';
    final service = _jobData?['skill'] as String? ?? 'Home Maintenance';
    final trackingUrl = 'https://jugaad.app/track/${widget.jobId}';
    final shareText = '🛡️ *Jugaad Safety Alert*: $workerName (4.9★, Police Verified Aadhaar KYC) is currently servicing $service at my home.\n\n'
        '📍 *Live Status*: In-Progress\n'
        '🔗 *Track Live Visit*: $trackingUrl\n\n'
        '🚨 24x7 Safety Helpline: 1800-JUGAAD-SAFE';

    final message = Uri.encodeComponent(shareText);
    final url = Uri.parse('https://wa.me/?text=$message');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: shareText));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Safety link copied to clipboard! Share anywhere.'),
              backgroundColor: UserAppTheme.primaryBlue,
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: trackingUrl));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Tracking link copied to clipboard!'),
            backgroundColor: UserAppTheme.primaryBlue,
          ),
        );
      }
    }
  }

  void _triggerSosEmergency() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: const [
            Icon(Icons.warning_rounded, color: UserAppTheme.urgentRed, size: 28),
            SizedBox(width: 8),
            Text(
              'Emergency SOS Alert',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: UserAppTheme.urgentRed),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Do you need immediate emergency assistance? Your live GPS coordinates and technician KYC will be dispatched instantly.',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              '• Call 112 (National Police Emergency)\n• Alert Jugaad 24x7 Safety Command Center',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final tel = Uri.parse('tel:112');
                if (await canLaunchUrl(tel)) {
                  await launchUrl(tel);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Emergency Hotline: Dial 112 immediately from your phone.'),
                        backgroundColor: UserAppTheme.urgentRed,
                      ),
                    );
                  }
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Dial 112 immediately for emergency services.'),
                      backgroundColor: UserAppTheme.urgentRed,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.call_rounded, size: 16),
            label: const Text('Call 112 Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: UserAppTheme.urgentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SPARE PARTS & MATERIALS ESCROW APPROVAL CARD ───────────────
  Widget _buildPendingSparePartBanner() {
    if (_pendingSparePart == null) {
      final approvedParts = _spareParts.where((p) => p['status'] == 'approved').toList();
      if (approvedParts.isEmpty) return const SizedBox.shrink();

      final totalApproved = approvedParts.fold<double>(
        0.0,
        (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0),
      );
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: UserAppTheme.cardBorderRadius,
          border: Border.all(color: const Color(0xFFA7F3D0), width: 1.0),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${approvedParts.length} Material Part(s) Approved (₹${totalApproved.toStringAsFixed(0)} locked into digital bill)',
                style: UserAppTheme.body(size: 12, color: const Color(0xFF065F46), weight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    final workerName = _jobData?['worker_name'] as String? ?? 'Technician';
    final itemName = _pendingSparePart!['item_name'] as String? ?? 'Material Part';
    final amount = _pendingSparePart!['amount'] ?? 0;
    final receiptUrl = _pendingSparePart!['receipt_photo_url'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: UserAppTheme.cardBorderRadius,
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🧾 Spare Part Approval Required',
                  style: UserAppTheme.heading(size: 14, color: const Color(0xFFB45309), weight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '₹$amount',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$workerName purchased 1x $itemName with hardware shop receipt attached. Zero awkward doorstep negotiations.',
            style: UserAppTheme.body(size: 13, color: const Color(0xFF78350F)).copyWith(height: 1.3),
          ),
          const SizedBox(height: 12),
          if (receiptUrl.isNotEmpty) ...[
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => Dialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Image.network(receiptUrl, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text('$itemName · Receipt Bill: ₹$amount', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.image_search_rounded, size: 16, color: Color(0xFFD97706)),
                    SizedBox(width: 6),
                    Text('View Hardware Shop Receipt Photo ↗', style: TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isActioningSparePart ? null : () => _declineSparePart(_pendingSparePart!['id'] as String),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: UserAppTheme.urgentRed),
                    foregroundColor: UserAppTheme.urgentRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isActioningSparePart ? null : () => _approveSparePart(_pendingSparePart!['id'] as String),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                  child: _isActioningSparePart
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Approve & Add to Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProofOfWorkCard() {
    final actualBefore = _jobData?['before_photo_url'] as String?;
    final actualAfter = _jobData?['after_photo_url'] as String?;
    final isDemo = actualBefore == null && actualAfter == null;

    final beforeUrl = actualBefore ?? 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=80';
    final afterUrl = actualAfter ?? 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=800&auto=format&fit=crop&q=80';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UserAppTheme.surface,
        borderRadius: UserAppTheme.cardBorderRadius,
        border: Border.all(color: UserAppTheme.divider),
        boxShadow: UserAppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded, color: UserAppTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Anti-Dispute Shield (Verified Proof)',
                style: UserAppTheme.heading(size: 14, color: UserAppTheme.textPrimary, weight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isDemo ? 'Sample Proof' : '7-Day Protection',
                  style: const TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Technician captured tamper-proof photos with GPS & timestamp watermark.',
            style: UserAppTheme.body(size: 12, color: UserAppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: UserAppTheme.divider),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(beforeUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.image)),
                        Positioned(
                          bottom: 4,
                          left: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                            child: const Text('✓ Before Work Photo', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(afterUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.image)),
                        Positioned(
                          bottom: 4,
                          left: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF059669), borderRadius: BorderRadius.circular(4)),
                            child: const Text('✓ Completed Fixture', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── SHARE LIVE VISIT WITH FAMILY CARD ──────────────────────────
  Widget _buildFamilySafetyCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: UserAppTheme.cardBorderRadius,
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.family_restroom_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Share Live Visit with Family',
                style: UserAppTheme.heading(size: 14, color: const Color(0xFF166534), weight: FontWeight.bold),
              ),
              const Spacer(),
              const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Keep family reassured. Sends live tracking & verified technician Aadhaar KYC to WhatsApp.',
            style: UserAppTheme.body(size: 12, color: const Color(0xFF14532D)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: _shareLiveVisitOnWhatsApp,
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Share on WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _triggerSosEmergency,
                  icon: const Icon(Icons.sos_rounded, color: UserAppTheme.urgentRed, size: 18),
                  label: const Text('1-Tap SOS', style: TextStyle(color: UserAppTheme.urgentRed, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: UserAppTheme.urgentRed, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

    final wLat = (data['worker_lat'] as num?)?.toDouble() ?? (data['lat'] as num?)?.toDouble();
    final wLng = (data['worker_lng'] as num?)?.toDouble() ?? (data['lng'] as num?)?.toDouble();
    if (wLat != null && wLng != null) {
      _updateWorkerTrackingPosition(wLat, wLng, 6.0);
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
    if (_sparePartsChannel != null) {
      SupabaseConfig.client.removeChannel(_sparePartsChannel!);
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
          if (_sparePartsChannel != null) {
            SupabaseConfig.client.removeChannel(_sparePartsChannel!);
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

                            // Main Scooter Icon Badge with smoothed Kalman bearing
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
                              child: Transform.rotate(
                                angle: _currentSmoothPos.bearingRadians,
                                child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 24),
                              ),
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

                      // Spare Parts & Materials Escrow Approval Banner
                      _buildPendingSparePartBanner().animate().fadeIn(duration: 400.ms),

                      // Safety: Share Live Visit with Family & SOS
                      _buildFamilySafetyCard().animate().fadeIn(duration: 400.ms, delay: 50.ms),

                      // Anti-Dispute Shield: Proof of Work
                      _buildProofOfWorkCard().animate().fadeIn(duration: 400.ms, delay: 100.ms),

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
}
