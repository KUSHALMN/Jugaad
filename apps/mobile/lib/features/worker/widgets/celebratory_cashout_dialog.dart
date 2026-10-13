import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Celebratory FinTech UPI Cashout Dialog.
/// Replicates the Paytm/PhonePe Soundbox excitement with celebratory confetti,
/// instant balance countdown, and NPCI verified trust badge.
class CelebratoryCashoutDialog extends StatefulWidget {
  final double payoutAmount;
  final String upiVpa;
  final VoidCallback onDismiss;

  const CelebratoryCashoutDialog({
    super.key,
    required this.payoutAmount,
    required this.upiVpa,
    required this.onDismiss,
  });

  static Future<void> show({
    required BuildContext context,
    required double payoutAmount,
    required String upiVpa,
    required VoidCallback onDismiss,
  }) {
    HapticFeedback.heavyImpact();
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CelebratoryCashoutDialog(
        payoutAmount: payoutAmount,
        upiVpa: upiVpa,
        onDismiss: () {
          Navigator.pop(ctx);
          onDismiss();
        },
      ),
    );
  }

  @override
  State<CelebratoryCashoutDialog> createState() => _CelebratoryCashoutDialogState();
}

class _CelebratoryCashoutDialogState extends State<CelebratoryCashoutDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFF10B981), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x6610B981),
                blurRadius: 36,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Soundbox Speaker Icon with Pulse
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x4410B981),
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'UPI CASHOUT SUCCESSFUL!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF34D399),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '₹${widget.payoutAmount.toInt()}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'ಪಾವತಿ ಯಶಸ್ವಿಯಾಗಿದೆ (Transferred via IMPS/UPI)',
                style: GoogleFonts.notoSansKannada(
                  fontSize: 11,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 20),

              // UPI VPA & NPCI Trust Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_rounded, color: Color(0xFF60A5FA), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.upiVpa.isNotEmpty ? widget.upiVpa : 'Direct Bank Deposit',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Instant Settlement • Zero Fee',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: const Color(0xFF6EE7B7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 26),

              // Dismiss / Great Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Awesome, Got It!',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
