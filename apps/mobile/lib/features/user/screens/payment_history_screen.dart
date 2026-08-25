import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:shimmer/shimmer.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/theme/app_text_styles.dart';
import 'package:jugaad_mvp/shared/widgets/jugaad_card.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  // BUG FIX
  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: [
          // Total spent card skeleton
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          const SizedBox(height: 24),
          // Transactions list skeleton
          ...List.generate(3, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          )),
        ],
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Payment History',
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
                'Error loading payment history: ${snapshot.error}',
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
          final paidDocs = docs.where((b) => b['payment_status'] == 'released').toList();
          
          // Compute client side sum of paid bookings
          double totalSpent = 0.0;
          for (final doc in paidDocs) {
            totalSpent += (doc['amount'] as num? ?? 0.0).toDouble();
          }

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            children: [
              // Total Spent Header
              JugaadCard(
                borderRadius: 24.0,
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      'TOTAL SPENT',
                      style: AppTextStyles.bodySmall(color: AppColors.textSecondary, weight: FontWeight.bold).copyWith(letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${totalSpent.toStringAsFixed(0)}',
                      style: AppTextStyles.heading1(color: AppColors.kUserPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Across ${paidDocs.length} completed transactions',
                      style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Transactions',
                style: AppTextStyles.heading3(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              
              if (paidDocs.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 48.0),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.payment_outlined, color: AppColors.textSecondary.withValues(alpha: 0.3), size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'No paid payments found',
                        style: AppTextStyles.bodyLarge(color: AppColors.textSecondary, weight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: paidDocs.length,
                  itemBuilder: (context, index) {
                    final data = paidDocs[index];
                    final service = data['skill_required'] as String? ?? 'Service';
                    final amount = (data['amount'] as num? ?? 0.0).toDouble();
                    final dateStr = _formatDate(data['scheduled_at']);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      child: JugaadCard(
                        borderRadius: 16.0,
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10.0),
                              decoration: BoxDecoration(
                                color: AppColors.kUserPrimary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.receipt_long_rounded, color: AppColors.kUserPrimary, size: 20),
                            ),
                            const SizedBox(width: 16),
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
                                    dateStr,
                                    style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${amount.toStringAsFixed(0)}',
                                  style: AppTextStyles.bodyLarge(color: AppColors.textPrimary, weight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'PAID',
                                    style: AppTextStyles.bodySmall(color: AppColors.success, weight: FontWeight.bold).copyWith(fontSize: 9),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
