import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:jugaad_mvp/core/services/api_service.dart';
import 'package:jugaad_mvp/core/services/auth_service.dart';
import 'package:jugaad_mvp/core/theme/user_app_theme.dart';
import 'package:jugaad_mvp/core/utils/jugaad_haptics.dart';

class PaymentScreen extends StatefulWidget {
  final String jobId;
  final double amount;
  
  const PaymentScreen({super.key, required this.jobId, required this.amount});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with TickerProviderStateMixin {
  late Razorpay _razorpay;
  bool _isProcessing = false;
  String _paymentMethod = 'upi';
  bool _paymentFailed = false;
  bool _paymentSuccessful = false;

  late AnimationController _successController;
  late AnimationController _shimmerController;
  late AnimationController _countUpController;

  @override
  void initState() {
    super.initState();
    
    _successController = AnimationController(vsync: this, duration: 1200.ms);
    _shimmerController = AnimationController(vsync: this, duration: 2000.ms)..repeat();
    _countUpController = AnimationController(vsync: this, duration: 800.ms)..forward();

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _successController.dispose();
    _shimmerController.dispose();
    _countUpController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    print('[PAYMENT] Razorpay result: SUCCESS - ${response.paymentId}');

    // Verify payment server-side before showing success
    try {
      await ApiService().verifyPayment(
        orderId: response.orderId ?? '',
        paymentId: response.paymentId ?? '',
        signature: response.signature ?? '',
      );
      print('[PAYMENT] Server verification passed');
    } catch (e) {
      print('[PAYMENT] Server verification failed: $e');
      setState(() {
        _isProcessing = false;
        _paymentFailed = true;
      });
      return;
    }

    setState(() {
      _isProcessing = false;
      _paymentFailed = false;
      _paymentSuccessful = true;
    });

    _successController.forward();
    JugaadHaptics.success();
    await Future.delayed(300.ms);
    JugaadHaptics.success();
    await Future.delayed(150.ms);
    JugaadHaptics.success();

    await Future.delayed(1500.ms); // Wait for lottie before navigation
    if (mounted) {
      context.go('/user/completion?job_id=${widget.jobId}&worker_name=Ravi%20Kumar&duration=45');
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('[PAYMENT] Razorpay result: ERROR - ${response.code} - ${response.message}');
    setState(() {
      _isProcessing = false;
      _paymentFailed = true;
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('[PAYMENT] Razorpay result: WALLET - ${response.walletName}');
  }

  Future<void> _startPayment() async {
    setState(() {
      _isProcessing = true;
      _paymentFailed = false;
    });

    const razorpayKey = String.fromEnvironment('RAZORPAY_KEY_ID');
    if (razorpayKey.isEmpty) {
      print('[PAYMENT] Missing RAZORPAY_KEY_ID dart-define. Checkout blocked.');
      setState(() {
        _isProcessing = false;
        _paymentFailed = true;
      });
      return;
    }

    try {
      final order = await ApiService().createRazorpayOrder(widget.jobId);
      final orderId = order['id'] as String?;
      if (orderId == null || orderId.isEmpty) {
        throw Exception('Backend returned empty order_id');
      }
      print('[PAYMENT] Razorpay order created: $orderId');

      final options = {
        'key': razorpayKey,
        'order_id': orderId,
        'amount': order['amount'],
        'name': 'Jugaad Services',
        'description': 'Payment for job ${widget.jobId}',
        'prefill': {
          'contact': AuthService().currentUser?.phoneNumber ?? '',
          'email': AuthService().currentUser?.email ?? 'support@jugaad.app'
        }
      };

      _razorpay.open(options);
    } catch (e) {
      print('[PAYMENT] Error launching razorpay: $e');
      setState(() {
        _isProcessing = false;
        _paymentFailed = true;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    const platformFee = 18.0;
    final serviceFee = widget.amount;
    final displayTotal = serviceFee + platformFee;

    return Scaffold(
      backgroundColor: UserAppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Payment Details',
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
              // Escrow Shield Banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      UserAppTheme.successGreen.withValues(alpha: 0.08),
                      UserAppTheme.successGreen.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: UserAppTheme.successGreen.withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: UserAppTheme.successGreen.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: UserAppTheme.successGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Secure Escrow Payment',
                            style: UserAppTheme.body(
                              size: 13,
                              weight: FontWeight.bold,
                              color: UserAppTheme.successGreen,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Funds are held securely and only released to the partner after you confirm completion.",
                            style: UserAppTheme.body(
                              size: 11,
                              color: UserAppTheme.textSecondary,
                            ).copyWith(height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0, curve: Curves.easeOutCubic),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_paymentFailed) _buildPaymentFailedState(),

                      // Total Amount Card
                      Center(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                          decoration: BoxDecoration(
                            color: UserAppTheme.surface,
                            borderRadius: UserAppTheme.cardBorderRadius,
                            border: Border.all(
                              color: _paymentSuccessful
                                  ? UserAppTheme.successGreen.withValues(alpha: 0.3)
                                  : UserAppTheme.divider,
                              width: 1,
                            ),
                            boxShadow: _paymentSuccessful
                                ? [
                                    BoxShadow(
                                      color: UserAppTheme.successGreen.withValues(alpha: 0.1),
                                      blurRadius: 30,
                                      spreadRadius: 4,
                                    )
                                  ]
                                : UserAppTheme.cardShadow,
                          ),
                          child: Column(
                            children: [
                              Text(
                                'TOTAL PAYABLE',
                                style: UserAppTheme.label(
                                  size: 11,
                                  weight: FontWeight.w800,
                                  color: UserAppTheme.textSecondary,
                                ).copyWith(letterSpacing: 1.5),
                              ),
                              const SizedBox(height: 8),
                              AnimatedBuilder(
                                animation: _countUpController,
                                builder: (context, _) {
                                  final displayAmt = displayTotal * _countUpController.value;
                                  return Text(
                                    '₹${displayAmt.toStringAsFixed(2)}',
                                    style: UserAppTheme.display(
                                      size: 38,
                                      weight: FontWeight.w800,
                                      color: _paymentSuccessful
                                          ? UserAppTheme.successGreen
                                          : UserAppTheme.textPrimary,
                                    ).copyWith(letterSpacing: -0.5),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutCubic),
                      
                      const SizedBox(height: 20),

                      // Price breakdown
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
                            _buildPriceRow('Service charge', '₹${serviceFee.toStringAsFixed(2)}', emoji: '🛠️'),
                            const SizedBox(height: 14),
                            _buildPriceRow('Platform fee', '₹${platformFee.toStringAsFixed(2)}', emoji: '📱'),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(color: UserAppTheme.divider, height: 1, thickness: 1),
                            ),
                            _buildPriceRow('Total Payable', '₹${displayTotal.toStringAsFixed(2)}', isTotal: true, emoji: '🧾'),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 28),

                      // Payment methods header
                      Text(
                        'Select Payment Method',
                        style: UserAppTheme.heading(
                          size: 15,
                          weight: FontWeight.bold,
                          color: UserAppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),

                      _buildPaymentMethodTile('UPI', Icons.account_balance_rounded, 'upi'),
                      if (_paymentMethod == 'upi') _buildUpiAppsRow(),
                      const SizedBox(height: 12),
                      _buildPaymentMethodTile('Credit/Debit Card', Icons.credit_card_rounded, 'card'),
                      const SizedBox(height: 12),
                      _buildPaymentMethodTile('Net Banking / Wallet', Icons.account_balance_wallet_rounded, 'wallet'),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom CTA
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: UserAppTheme.background,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _paymentSuccessful
                        ? Container(
                            key: const ValueKey('success'),
                            height: UserAppTheme.buttonHeight,
                            decoration: BoxDecoration(
                              gradient: UserAppTheme.successGradient,
                              borderRadius: UserAppTheme.buttonBorderRadius,
                              boxShadow: [
                                BoxShadow(
                                  color: UserAppTheme.successGreen.withValues(alpha: 0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Payment Done!',
                                  style: UserAppTheme.body(
                                    color: Colors.white,
                                    weight: FontWeight.bold,
                                    size: 15,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            height: UserAppTheme.buttonHeight,
                            decoration: BoxDecoration(
                              gradient: _isProcessing ? null : UserAppTheme.primaryGradient,
                              color: _isProcessing ? UserAppTheme.divider : null,
                              borderRadius: UserAppTheme.buttonBorderRadius,
                              boxShadow: _isProcessing
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: UserAppTheme.primaryBlue.withValues(alpha: 0.2),
                                        blurRadius: 15,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                            ),
                            child: ElevatedButton(
                              key: const ValueKey('pay_btn'),
                              onPressed: _isProcessing ? null : _startPayment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                minimumSize: Size.fromHeight(UserAppTheme.buttonHeight),
                                shape: RoundedRectangleBorder(borderRadius: UserAppTheme.buttonBorderRadius),
                              ),
                              child: _isProcessing
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Pay ₹${displayTotal.toStringAsFixed(2)} Securely',
                                          style: UserAppTheme.body(
                                            color: Colors.white,
                                            weight: FontWeight.bold,
                                            size: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_rounded, color: UserAppTheme.textSecondary.withValues(alpha: 0.6), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Secured by Razorpay • PCI-DSS Compliant',
                        style: UserAppTheme.label(
                          size: 11,
                          color: UserAppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (_paymentSuccessful)
            Container(
              color: UserAppTheme.textPrimary.withValues(alpha: 0.8), // Darken background slightly
              child: Center(
                child: RepaintBoundary(
                  child: SizedBox(
                    width: 250,
                    height: 250,
                    child: Lottie.asset(
                      'assets/lottie/payment_success.json',
                      repeat: false,
                      frameRate: const FrameRate(60),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentFailedState() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: UserAppTheme.urgentRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UserAppTheme.urgentRed.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: UserAppTheme.urgentRed, size: 20),
              const SizedBox(width: 8),
              Text(
                'Payment Unsuccessful',
                style: UserAppTheme.body(
                  size: 14,
                  weight: FontWeight.bold,
                  color: UserAppTheme.urgentRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The transaction was declined by your bank or PSP app. Please try again.',
            style: UserAppTheme.body(
              size: 13,
              color: UserAppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _startPayment,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: UserAppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Try Again',
                      style: UserAppTheme.body(
                        color: Colors.white,
                        weight: FontWeight.bold,
                        size: 13,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _paymentFailed = false);
                  },
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: UserAppTheme.primaryBlue, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Change Method',
                      style: UserAppTheme.body(
                        color: UserAppTheme.primaryBlue,
                        weight: FontWeight.bold,
                        size: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7), // Amber 100
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: Color(0xFFD97706), size: 14),
                const SizedBox(width: 6),
                Text(
                  'Your booking slot is held for 5 minutes.',
                  style: UserAppTheme.label(
                    size: 11,
                    color: const Color(0xFFB45309), // Amber 700
                    weight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().shake(duration: 400.ms);
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false, String? emoji}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (emoji != null) ...[
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: UserAppTheme.body(
                size: isTotal ? 15 : 14,
                weight: isTotal ? FontWeight.bold : FontWeight.w500,
                color: isTotal ? UserAppTheme.textPrimary : UserAppTheme.textSecondary,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: UserAppTheme.body(
            size: isTotal ? 16 : 14,
            weight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isTotal ? UserAppTheme.primaryBlue : UserAppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile(String title, IconData icon, String value) {
    final isSelected = _paymentMethod == value;
    return GestureDetector(
      onTap: () {
        JugaadHaptics.light();
        setState(() => _paymentMethod = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? UserAppTheme.primaryBlue.withValues(alpha: 0.04) : UserAppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? UserAppTheme.primaryBlue : UserAppTheme.divider,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: UserAppTheme.primaryBlue.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? UserAppTheme.primaryBlue.withValues(alpha: 0.1)
                    : UserAppTheme.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? UserAppTheme.primaryBlue : UserAppTheme.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: UserAppTheme.body(
                  size: 14,
                  weight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? UserAppTheme.primaryBlue : UserAppTheme.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: UserAppTheme.primaryBlue, size: 22)
            else
              Icon(Icons.radio_button_off_rounded, color: UserAppTheme.textSecondary.withValues(alpha: 0.5), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildUpiAppsRow() {
    final List<Map<String, dynamic>> upiApps = [
      {'name': 'Google Pay', 'logo': 'G', 'color': const Color(0xFFEA4335)},
      {'name': 'PhonePe', 'logo': 'P', 'color': const Color(0xFF5F259F)},
      {'name': 'Paytm', 'logo': 'P', 'color': const Color(0xFF00B9F5)},
      {'name': 'Other UPI', 'logo': 'U', 'color': UserAppTheme.textSecondary},
    ];

    return Container(
      margin: const EdgeInsets.only(top: 12, left: 8, right: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UserAppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UserAppTheme.divider, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pay via UPI App',
            style: UserAppTheme.label(
              size: 11,
              weight: FontWeight.bold,
              color: UserAppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: upiApps.map((app) {
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    JugaadHaptics.light();
                    _startPayment();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: UserAppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: UserAppTheme.divider, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: app['color'].withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            app['logo'],
                            style: TextStyle(
                              color: app['color'],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          app['name'],
                          style: UserAppTheme.label(
                            size: 10,
                            color: UserAppTheme.textPrimary,
                            weight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}
