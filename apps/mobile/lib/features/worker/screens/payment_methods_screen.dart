import 'package:flutter/material.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/theme/app_text_styles.dart';
import 'package:jugaad_mvp/shared/widgets/jugaad_card.dart';

class PaymentMethodsScreen extends StatelessWidget {
  final Map<String, dynamic> currentData;
  const PaymentMethodsScreen({super.key, required this.currentData});

  @override
  Widget build(BuildContext context) {
    final payoutSettings = currentData['payoutSettings'] as Map? ?? {};
    final upiId = payoutSettings['upiId'] as String? ?? '';
    final bankLinked = payoutSettings['bankAccountLinked'] as bool? ?? false;

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
          'Payment Methods',
          style: AppTextStyles.heading3(color: AppColors.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payout Accounts',
              style: AppTextStyles.heading3(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'These methods are used to transfer your earnings from your withdrawable balance.',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            // UPI Account Card
            JugaadCard(
              borderRadius: 20.0,
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: AppColors.kWorkerPrimary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flash_on_rounded, color: AppColors.kWorkerPrimary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UPI ID Transfer',
                          style: AppTextStyles.bodyLarge(color: AppColors.textPrimary, weight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          upiId.isNotEmpty ? upiId : 'Not linked yet',
                          style: AppTextStyles.bodyMedium(
                            color: upiId.isNotEmpty ? AppColors.textPrimary : AppColors.textSecondary,
                            weight: upiId.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: upiId.isNotEmpty
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.textSecondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      upiId.isNotEmpty ? 'Linked' : 'Optional',
                      style: AppTextStyles.bodySmall(
                        color: upiId.isNotEmpty ? AppColors.success : AppColors.textSecondary,
                        weight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bank Account Card
            JugaadCard(
              borderRadius: 20.0,
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_rounded, color: AppColors.warning, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bank Account',
                          style: AppTextStyles.bodyLarge(color: AppColors.textPrimary, weight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bankLinked ? 'Direct Bank Transfer Linked' : 'Not linked yet',
                          style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bankLinked
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.textSecondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      bankLinked ? 'Active' : 'Optional',
                      style: AppTextStyles.bodySmall(
                        color: bankLinked ? AppColors.success : AppColors.textSecondary,
                        weight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            Text(
              'Need to change accounts?',
              style: AppTextStyles.bodyLarge(color: AppColors.textPrimary, weight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Go to Payout Settings or Bank Account from the main menu to edit these details.',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
