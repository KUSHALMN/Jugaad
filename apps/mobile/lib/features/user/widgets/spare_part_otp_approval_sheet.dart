import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/spare_part_quotation_item.dart';
import '../../../../core/utils/haptic_feedback_utils.dart';

/// In-App 4-Digit OTP Approval Shield for High-Value Spare Parts.
/// Protects homeowners from surprise bills by requiring an explicit 4-digit handshake
/// before any material expense is locked into the final digital invoice.
class SparePartOtpApprovalSheet extends StatefulWidget {
  final SparePartQuotationItem item;
  final VoidCallback onVerified;

  const SparePartOtpApprovalSheet({
    super.key,
    required this.item,
    required this.onVerified,
  });

  static Future<bool?> show(
    BuildContext context, {
    required SparePartQuotationItem item,
    required VoidCallback onVerified,
  }) {
    AppHaptics.mediumImpact();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SparePartOtpApprovalSheet(
        item: item,
        onVerified: onVerified,
      ),
    );
  }

  @override
  State<SparePartOtpApprovalSheet> createState() => _SparePartOtpApprovalSheetState();
}

class _SparePartOtpApprovalSheetState extends State<SparePartOtpApprovalSheet> {
  final List<String> _digits = [];
  final String _expectedOtp = '7429';
  bool _isSuccess = false;

  void _onDigitPress(String d) {
    if (_digits.length >= 4) return;
    AppHaptics.lightImpact();
    setState(() {
      _digits.add(d);
      if (_digits.length == 4) {
        if (_digits.join() == _expectedOtp) {
          _isSuccess = true;
          AppHaptics.heavySuccess();
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) {
              Navigator.of(context).pop(true);
              widget.onVerified();
            }
          });
        } else {
          AppHaptics.warning();
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) {
              setState(() => _digits.clear());
            }
          });
        }
      }
    });
  }

  void _onDelete() {
    if (_digits.isNotEmpty) {
      AppHaptics.lightImpact();
      setState(() => _digits.removeLast());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Security Shield Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
            ),
            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 32),
          ),
          const SizedBox(height: 12),

          Text(
            'Secure Material Escrow Approval',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Authorizing ₹${widget.item.billedPrice.toStringAsFixed(0)} for ${widget.item.itemName}',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF047857),
            ),
          ),
          const SizedBox(height: 8),

          // One-time code instruction
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.key_rounded, size: 16, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Text(
                  'Enter Approval PIN: $_expectedOtp',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4-Pin circles
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final filled = index < _digits.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled
                      ? (_isSuccess ? const Color(0xFF10B981) : const Color(0xFFEA580C))
                      : const Color(0xFFE2E8F0),
                  border: Border.all(
                    color: filled ? Colors.transparent : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Keypad
          Column(
            children: [
              for (var row = 0; row < 3; row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var col = 1; col <= 3; col++)
                        _buildKeyButton((row * 3 + col).toString()),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 72, height: 54),
                  _buildKeyButton('0'),
                  SizedBox(
                    width: 72,
                    height: 54,
                    child: IconButton(
                      onPressed: _onDelete,
                      icon: const Icon(Icons.backspace_outlined, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            '🔒 100% Price Lock Guarantee • No hidden commissions',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyButton(String text) {
    return SizedBox(
      width: 72,
      height: 52,
      child: TextButton(
        onPressed: () => _onDigitPress(text),
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFF8FAFC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}
