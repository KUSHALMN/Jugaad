import 'package:flutter/material.dart';
import 'theme.dart';
import 'components.dart';

class WorkerEarningsScreen extends StatelessWidget {
  const WorkerEarningsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final Color workerPrimary = const Color(0xFF0F6E56);
    final Color workerLightFill = const Color(0xFFE1F5EE);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: const CustomAppBar(
        title: 'Earnings',
        showBack: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16.0),
                    
                    // BALANCE CARD
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: workerLightFill, // green tint bg
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL BALANCE',
                            style: TextStyle(
                              fontSize: 9.0,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: colors.neutralPrimary,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            '₹2,450',
                            style: TextStyle(
                              fontSize: 28.0,
                              fontWeight: FontWeight.w700,
                              color: workerPrimary, // bold green
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          Row(
                            children: [
                              Text(
                                '₹600 pending',
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w600,
                                  color: colors.warningPrimary, // amber
                                ),
                              ),
                              const SizedBox(width: 12.0),
                              Text(
                                '·',
                                style: TextStyle(fontSize: 12.0, color: colors.neutralPrimary),
                              ),
                              const SizedBox(width: 12.0),
                              Text(
                                '₹1,850 paid out',
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w500,
                                  color: colors.neutralPrimary, // secondary
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24.0),
                          
                          // CTA Request Payout
                          SizedBox(
                            width: double.infinity,
                            height: 38.0,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: workerPrimary,
                                side: BorderSide(color: workerPrimary, width: 1.0),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                              ),
                              onPressed: () {},
                              child: const Text('Request payout →', style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32.0),
                    
                    // RECENT JOBS
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RECENT JOBS',
                            style: TextStyle(
                              fontSize: 11.0,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            'See all',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: colors.primary, // Standard blue link
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Job Rows
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          _buildJobRow('Laptop repair', 'Today, 2:30 PM', '₹450', 'pending', colors, workerPrimary),
                          const Divider(height: 24.0),
                          _buildJobRow('Phone repair', 'Yesterday', '₹600', 'pending', colors, workerPrimary),
                          const Divider(height: 24.0),
                          _buildJobRow('Laptop repair', '12 May', '₹350', 'paid', colors, workerPrimary),
                          const Divider(height: 24.0),
                          _buildJobRow('AC service', '10 May', '₹1,050', 'paid', colors, workerPrimary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32.0),
                    
                    // PAYOUT INFO CARD
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24.0),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: colors.neutralFill.withValues(alpha: 0.4), // neutral tint
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: colors.neutralBorder, width: 0.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16.0, color: colors.neutralPrimary),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Text(
                              'Payouts process every Monday via UPI to your registered number.',
                              style: TextStyle(
                                fontSize: 11.0,
                                color: colors.neutralPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 2, // Earnings is active
        onTap: (index) {},
        mode: 'worker',
      ),
    );
  }

  Widget _buildJobRow(String service, String date, String amount, String status, AppColors colors, Color workerPrimary) {
    bool isPending = status == 'pending';
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              service,
              style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: colors.textPrimary),
            ),
            const SizedBox(height: 4.0),
            Text(
              date,
              style: TextStyle(fontSize: 12.0, color: colors.neutralPrimary),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
            const SizedBox(height: 6.0),
            // Custom simplified pill for Earnings
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: isPending ? colors.warningFill : colors.neutralFill,
                borderRadius: BorderRadius.circular(100.0),
              ),
              child: Text(
                isPending ? 'Pending' : 'Paid',
                style: TextStyle(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w600,
                  color: isPending ? colors.warningPrimary : colors.neutralPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
