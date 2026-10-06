import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:shimmer/shimmer.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/theme/app_text_styles.dart';
import 'package:jugaad_mvp/shared/widgets/jugaad_card.dart';
import 'package:jugaad_mvp/shared/widgets/status_badge.dart';

class BookingsHistoryScreen extends StatelessWidget {
  const BookingsHistoryScreen({super.key});

  // BUG FIX
  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFF1F5F9),
      highlightColor: Colors.white,
      child: Column(
        children: List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE2E8F0),
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
                        const SizedBox(height: 6),
                        Container(
                          width: 100,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 60,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 72,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is String) {
      final date = DateTime.tryParse(timestamp)?.toLocal();
      if (date == null) return 'N/A';
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
    return 'N/A';
  }

  BadgeStatus _getBadgeStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return BadgeStatus.pending;
      case 'confirmed':
      case 'active':
      case 'searching':
        return BadgeStatus.active;
      case 'in_progress':
        return BadgeStatus.inProgress;
      case 'completed':
        return BadgeStatus.completed;
      case 'cancelled':
        return BadgeStatus.cancelled;
      case 'assigned':
        return BadgeStatus.assigned;
      default:
        return BadgeStatus.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/user/home');
            }
          },
        ),
        title: Text(
          'Booking History',
          style: AppTextStyles.heading3(color: AppColors.textPrimary),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SupabaseConfig.client
            .from('jobs')
            .stream(primaryKey: ['id'])
            .eq('employer_id', uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading booking history: ${snapshot.error}',
                style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            // BUG FIX
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildSkeleton(),
            );
          }

          final docs = snapshot.data ?? [];
          final sortedDocs = List<Map<String, dynamic>>.from(docs)
            ..sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

          if (sortedDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_outline_rounded, color: AppColors.textSecondary.withValues(alpha: 0.3), size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'No bookings found',
                    style: AppTextStyles.bodyLarge(color: AppColors.textSecondary, weight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            itemCount: sortedDocs.length,
            itemBuilder: (context, index) {
              final b = sortedDocs[index];
              final service = b['skill_required'] as String? ?? 'Service';
              final status = b['status'] as String? ?? 'pending';
              final dateStr = _formatDate(b['scheduled_at']);
              final amount = (b['amount'] as num? ?? 0.0).toDouble();

              return Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                child: JugaadCard(
                  borderRadius: 16.0,
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service,
                              style: AppTextStyles.bodyLarge(color: AppColors.textPrimary, weight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Scheduled: $dateStr',
                              style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₹${amount.toStringAsFixed(0)}',
                              style: AppTextStyles.bodyMedium(color: AppColors.kUserPrimary, weight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      StatusBadge(
                        status: _getBadgeStatus(status),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
