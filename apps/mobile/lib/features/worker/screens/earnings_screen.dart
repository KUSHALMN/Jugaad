import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:jugaad_mvp/core/services/auth_service.dart';
import 'package:jugaad_mvp/core/services/supabase_service.dart';
import 'package:jugaad_mvp/core/theme/worker_app_theme.dart';
import 'package:jugaad_mvp/shared/widgets/empty_state.dart';
import 'package:jugaad_mvp/shared/widgets/shimmer_card.dart';
import 'package:jugaad_mvp/shared/widgets/status_badge.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  double _withdrawableBalance = 0;
  double _pendingPayoutTotal = 0;
  String? _upiId;

  final _fs = SupabaseService();

  void _requestPayout() {
    if (_withdrawableBalance <= 0) return;
    if (_upiId == null || _upiId!.isEmpty) {
      _showUpiDialog();
    } else {
      _processPayoutRequest(_upiId!);
    }
  }

  void _showUpiDialog() {
    final controller = TextEditingController(text: _upiId ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add UPI ID',
            style: WorkerAppTheme.heading(color: WorkerAppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We need your UPI ID to transfer earnings.',
              style: WorkerAppTheme.body(color: WorkerAppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: WorkerAppTheme.body(color: WorkerAppTheme.textPrimary, size: 15),
              decoration: InputDecoration(
                hintText: 'yourname@upi',
                hintStyle:
                    WorkerAppTheme.body(color: WorkerAppTheme.textSecondary, size: 14),
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined,
                    color: WorkerAppTheme.primaryGreen),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: WorkerAppTheme.body(
                    color: WorkerAppTheme.textSecondary,
                    weight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              final upi = controller.text.trim();
              if (upi.isNotEmpty) {
                final uid = AuthService().currentUser?.uid;
                if (uid != null) {
                  await _fs.saveWorkerUpi(uid, upi);
                  setState(() => _upiId = upi);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _processPayoutRequest(upi);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: WorkerAppTheme.primaryGreen,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Save & Request',
                style: WorkerAppTheme.body(
                    color: Colors.white, weight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayoutRequest(String upiId) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;

    try {
      await _fs.requestPayout(
        uid: uid,
        amount: _withdrawableBalance,
        upiId: upiId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Payout requested! Processed every Monday via UPI.',
                    style: WorkerAppTheme.body(
                        color: Colors.white, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            backgroundColor: WorkerAppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payout request failed: $e'),
            backgroundColor: WorkerAppTheme.urgentRed,
          ),
        );
      }
    }
  }

  String getFormattedDate() {
    final now = DateTime.now();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}";
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        backgroundColor: WorkerAppTheme.background,
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          heading: 'Not logged in',
          subtitle: 'Please log in to view your earnings.',
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _fs.workerStream(uid),
      builder: (context, workerSnap) {
        int jobsToday = 4;
        int trustScore = 95;

        if (workerSnap.hasData && workerSnap.data!.isNotEmpty) {
          final data = workerSnap.data!.first;
          _withdrawableBalance =
              (data['withdrawable_balance'] as num? ?? 0).toDouble();
          _upiId = data['upi_id'] as String?;
          jobsToday = (data['jobs_today'] as num? ?? 4).toInt();
          trustScore = (data['trust_score'] as num? ?? 95).toInt();
        }

        final Color trustColor = trustScore >= 90
            ? WorkerAppTheme.primaryGreen
            : trustScore >= 70
                ? WorkerAppTheme.earningGold
                : WorkerAppTheme.urgentRed;

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _fs.pendingPayoutsStream(uid),
          builder: (context, payoutSnap) {
            if (payoutSnap.hasData) {
              _pendingPayoutTotal =
                  SupabaseService.sumPendingPayouts(payoutSnap.data!);
            }

            return Scaffold(
              backgroundColor: WorkerAppTheme.background,
              body: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ─────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Earnings',
                              style: WorkerAppTheme.display(
                                size: 28,
                                color: WorkerAppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              getFormattedDate(),
                              style: WorkerAppTheme.body(
                                size: 14,
                                color: WorkerAppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 300.ms),

                      // ── Balance Card / Today's Earning Hero ────────
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: WorkerAppTheme.deepGreenGradient,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: WorkerAppTheme.cardShadow,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "TODAY'S EARNINGS",
                                      style: WorkerAppTheme.label(
                                        size: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    if (_pendingPayoutTotal > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '₹${_pendingPayoutTotal.toStringAsFixed(0)} pending',
                                          style: WorkerAppTheme.label(
                                            color: Colors.white,
                                            size: 10,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                CountUpText(
                                  value: _withdrawableBalance,
                                  style: WorkerAppTheme.display(
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Arc Chart
                                Center(
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        width: 160,
                                        height: 90,
                                        child: CustomPaint(
                                          painter: WeeklyTargetArcPainter(
                                            current: _withdrawableBalance,
                                            target: 2500,
                                          ),
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Padding(
                                              padding: const EdgeInsets.only(bottom: 8.0),
                                              child: Text(
                                                '₹${_withdrawableBalance.toInt()} / ₹2500',
                                                style: WorkerAppTheme.heading(
                                                  size: 15,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Weekly target',
                                        style: WorkerAppTheme.label(
                                          size: 12,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

                      // ── Stats Row ──────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            // Card 1: Jobs Today
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: WorkerAppTheme.surface,
                                  borderRadius: WorkerAppTheme.cardBorderRadius,
                                  boxShadow: WorkerAppTheme.cardShadow,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Icon(Icons.work_outline_rounded, color: WorkerAppTheme.primaryGreen, size: 24),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '$jobsToday',
                                      style: WorkerAppTheme.display(size: 36, color: WorkerAppTheme.primaryGreen),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Jobs today',
                                      style: WorkerAppTheme.label(color: WorkerAppTheme.textSecondary, size: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Card 2: Trust Score
                            Expanded(
                              child: Container(
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
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CustomPaint(
                                            painter: TrustScorePainter(
                                              score: trustScore,
                                              color: trustColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '$trustScore%',
                                      style: WorkerAppTheme.display(size: 36, color: trustColor),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Trust score',
                                      style: WorkerAppTheme.label(color: WorkerAppTheme.textSecondary, size: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
                      const SizedBox(height: 20),

                      // ── Streak Bonus Badge ─────────────────────────
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: StreakBonusBadge(),
                      ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                      const SizedBox(height: 28),

                      // ── Recent Jobs Section ────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          "TODAY'S JOBS",
                          style: WorkerAppTheme.label(
                              color: WorkerAppTheme.textPrimary, size: 13),
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 250.ms),
                      const SizedBox(height: 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildJobsList(uid),
                      ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _withdrawableBalance >= 200 ? _requestPayout : null,
                        child: Shimmer.fromColors(
                          baseColor: const Color(0xFF1D4ED8),
                          highlightColor: const Color(0xFF60A5FA),
                          period: const Duration(seconds: 3),
                          child: Opacity(
                            opacity: _withdrawableBalance >= 200 ? 1.0 : 0.5,
                            child: Container(
                              height: 56,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: WorkerAppTheme.payoutGradient,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                            child: Text(
                              'Request Payout →',
                              style: WorkerAppTheme.heading(color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Minimum ₹200 · UPI instant transfer',
                        style: WorkerAppTheme.label(color: WorkerAppTheme.textSecondary, size: 11),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildJobsList(String uid) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _fs.workerBookingsStream(
        uid,
        statuses: ['completed'],
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.error_outline_rounded,
            heading: 'Failed to load',
            subtitle: 'Could not fetch recent job history.',
            iconColor: WorkerAppTheme.urgentRed,
            iconBackground: WorkerAppTheme.urgentRed.withValues(alpha: 0.1),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ShimmerList(itemCount: 3);
        }

        final rows = snapshot.data ?? [];

        if (rows.isEmpty) {
          return EmptyState(
            icon: Icons.emoji_events_rounded,
            heading: 'No completed jobs yet',
            subtitle:
                'Complete jobs to start earning. Your history will appear here.',
            iconColor: WorkerAppTheme.primaryGreen,
            iconBackground: WorkerAppTheme.primaryGreen.withValues(alpha: 0.1),
          );
        }

        return Column(
          children: rows.asMap().entries.map((entry) {
            final data = entry.value;
            final paymentStatus =
                data['paymentStatus'] as String? ?? 'pending';
            final isPaid = paymentStatus == 'paid';

            final userName = data['userName'] as String? ?? 'Customer';
            final service = data['service'] as String? ?? 'Service';
            final amount = (data['amount'] as num? ?? 0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: WorkerAppTheme.surface,
                  borderRadius: WorkerAppTheme.cardBorderRadius,
                  boxShadow: WorkerAppTheme.cardShadow,
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? WorkerAppTheme.primaryGreen.withValues(alpha: 0.1)
                            : WorkerAppTheme.earningGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.build_rounded,
                        color: isPaid ? WorkerAppTheme.primaryGreen : WorkerAppTheme.earningGold,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service,
                            style: WorkerAppTheme.heading(
                                size: 14, color: WorkerAppTheme.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userName,
                            style: WorkerAppTheme.body(
                                size: 12, color: WorkerAppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹$amount',
                          style: WorkerAppTheme.heading(
                            size: 16,
                            color: WorkerAppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StatusBadge(
                          status: isPaid
                              ? BadgeStatus.completed
                              : BadgeStatus.pending,
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─── COUNT UP TEXT WIDGET ──────────────────────────────────────
class CountUpText extends StatefulWidget {
  final double value;
  final TextStyle style;

  const CountUpText({
    super.key,
    required this.value,
    required this.style,
  });

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(begin: oldWidget.value, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '₹${_animation.value.toStringAsFixed(0)}',
          style: widget.style,
        );
      },
    );
  }
}

// ─── WEEKLY TARGET ARC PAINTER ──────────────────────────────────
class WeeklyTargetArcPainter extends CustomPainter {
  final double current;
  final double target;

  WeeklyTargetArcPainter({required this.current, required this.target});

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 10.0;
    final double radius = (size.width - strokeWidth) / 2;
    final Offset center = Offset(size.width / 2, size.height);

    final Paint bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint activePaint = Paint()
      ..color = const Color(0xFFF59E0B) // Earning Gold
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159,
      3.14159,
      false,
      bgPaint,
    );

    final double pct = (target > 0 ? (current / target) : 0.0).clamp(0.0, 1.0);
    if (pct > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        3.14159,
        3.14159 * pct,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WeeklyTargetArcPainter oldDelegate) {
    return oldDelegate.current != current || oldDelegate.target != target;
  }
}

// ─── TRUST SCORE PAINTER ────────────────────────────────────────
class TrustScorePainter extends CustomPainter {
  final int score;
  final Color color;

  TrustScorePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 4.0;
    final double radius = (size.width - strokeWidth) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final Paint bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Paint activePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final double sweepAngle = (score / 100.0) * 2 * 3.14159;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant TrustScorePainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.color != color;
  }
}

// ─── STREAK BONUS BADGE WIDGET ──────────────────────────────────
class StreakBonusBadge extends StatefulWidget {
  const StreakBonusBadge({super.key});

  @override
  State<StreakBonusBadge> createState() => _StreakBonusBadgeState();
}

class _StreakBonusBadgeState extends State<StreakBonusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.2).animate(
              CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
            ),
            child: const Text(
              '🔥',
              style: TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '3-day streak! Keep going',
                  style: WorkerAppTheme.heading(color: Colors.white, size: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Complete 1 more job for bonus',
                  style: WorkerAppTheme.label(color: Colors.grey.shade400, size: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '₹50 bonus',
              style: WorkerAppTheme.label(color: Colors.white, size: 11),
            ),
          ),
        ],
      ),
    );
  }
}
