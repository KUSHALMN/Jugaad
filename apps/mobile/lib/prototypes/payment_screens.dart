import 'package:flutter/material.dart';
import 'theme.dart';
import 'components.dart';

// ==========================================
// 1. PAYMENT SCREEN
// ==========================================

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Scaffold(
      backgroundColor: colors.background,
      appBar: const CustomAppBar(
        title: 'Payment',
        showBack: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16.0),
                      
                      // Simple Trust Row
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, size: 14.0, color: colors.neutralPrimary),
                            const SizedBox(width: 6.0),
                            Text(
                              "You'll only be charged after the job is done",
                              style: TextStyle(
                                fontSize: 12.0,
                                color: colors.neutralPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32.0),
                      
                      // Price Breakdown
                      const Text('Bill details', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16.0),
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: colors.neutralFill.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: colors.neutralBorder, width: 0.5),
                        ),
                        child: Column(
                          children: [
                            _buildPriceRow('Service fee', '₹380', colors),
                            const SizedBox(height: 12.0),
                            _buildPriceRow('Platform fee', '₹38', colors),
                            const SizedBox(height: 16.0),
                            const Divider(height: 1.0),
                            const SizedBox(height: 16.0),
                            _buildPriceRow('Total', '₹418', colors, isBold: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32.0),
                      
                      // Payment Methods
                      const Text('Pay using', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16.0),
                      _buildPaymentMethodTile('UPI (Google Pay, PhonePe)', Icons.qr_code_scanner, true, colors),
                      const SizedBox(height: 12.0),
                      _buildPaymentMethodTile('Credit / Debit Card', Icons.credit_card, false, colors),
                      const SizedBox(height: 12.0),
                      _buildPaymentMethodTile('Wallets', Icons.account_balance_wallet, false, colors),
                      const SizedBox(height: 32.0),
                    ],
                  ),
                ),
              ),
            ),
            
            // Bottom Action Area
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.neutralBorder, width: 0.5)),
              ),
              child: Column(
                children: [
                  PrimaryButton(
                    text: 'Pay ₹418 securely',
                    onPressed: () {
                      // Navigate to completion screen
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const JobCompletionScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    'Powered by Razorpay',
                    style: TextStyle(
                      fontSize: 11.0,
                      color: colors.neutralPrimary.withValues(alpha: 0.6), // tertiary feeling
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, AppColors colors, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            color: isBold ? Colors.black : colors.neutralPrimary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile(String title, IconData icon, bool isSelected, AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isSelected ? colors.lightFill : Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: isSelected ? colors.primary : colors.neutralBorder,
          width: isSelected ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: isSelected ? colors.primary : colors.neutralPrimary, size: 20.0),
          const SizedBox(width: 16.0),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14.0,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? colors.primary : Colors.black,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.radio_button_checked, color: colors.primary, size: 20.0)
          else
            Icon(Icons.radio_button_unchecked, color: colors.neutralBorder, size: 20.0),
        ],
      ),
    );
  }
}

// ==========================================
// 2. COMPLETION SCREEN
// ==========================================

class JobCompletionScreen extends StatefulWidget {
  const JobCompletionScreen({Key? key}) : super(key: key);

  @override
  State<JobCompletionScreen> createState() => _JobCompletionScreenState();
}

class _JobCompletionScreenState extends State<JobCompletionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _scaleAnimation;
  int _selectedRating = 0;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
    );
    
    _checkController.forward();
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Scaffold(
      backgroundColor: colors.background,
      // No app bar, no nav bar
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 64.0),
                
                // Animated Checkmark Circle
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 64.0, // using 64 to give the 40dp icon breathing room
                    height: 64.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.successPrimary, // Green
                    ),
                    child: Icon(Icons.check, color: colors.surface, size: 40.0),
                  ),
                ),
                const SizedBox(height: 24.0),
                
                Text(
                  'Job done!',
                  style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w700, color: colors.textPrimary),
                ),
                const SizedBox(height: 8.0),
                
                Text(
                  'Rajan Kumar · Laptop repair · 33 mins',
                  style: TextStyle(fontSize: 13.0, color: colors.neutralPrimary),
                ),
                const SizedBox(height: 4.0),
                
                // IMPORTANT Speed Signal
                Text(
                  'Worker arrived in 14 minutes',
                  style: TextStyle(
                    fontSize: 12.0, 
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF0F6E56), // success primary
                  ),
                ),
                
                const SizedBox(height: 48.0),
                
                // Rating Component
                const Text('Rate your experience', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < _selectedRating ? Icons.star : Icons.star_border,
                        size: 36.0,
                        color: const Color(0xFFE5A023), // Gold
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedRating = index + 1;
                        });
                      },
                    );
                  }),
                ),
                
                const SizedBox(height: 24.0),
                
                // Optional Review
                const CustomTextInput(
                  hintText: 'Write a review (optional)...',
                  isMultiline: true,
                ),
                
                const SizedBox(height: 48.0),
                
                // CTAs
                PrimaryButton(
                  text: 'Submit',
                  onPressed: _selectedRating > 0 ? () {
                    // Submit review and go home
                  } : null,
                ),
                const SizedBox(height: 16.0),
                SecondaryButton(
                  text: 'Book again',
                  onPressed: () {},
                ),
                const SizedBox(height: 32.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
