import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/theme/worker_app_theme.dart';

class PayoutSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> currentData;
  const PayoutSettingsScreen({super.key, required this.currentData});

  @override
  State<PayoutSettingsScreen> createState() => _PayoutSettingsScreenState();
}

class _PayoutSettingsScreenState extends State<PayoutSettingsScreen> {
  late TextEditingController _upiController;
  bool _isLoading = false;

  static const List<String> _popularHandles = [
    '@okaxis',
    '@ybl',
    '@paytm',
    '@okhdfcbank',
    '@ibl',
  ];

  @override
  void initState() {
    super.initState();
    final payoutSettings = widget.currentData['payoutSettings'] as Map? ?? {};
    _upiController = TextEditingController(text: payoutSettings['upiId'] as String? ?? '');
    _upiController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  bool get _isValidUpi {
    final text = _upiController.text.trim();
    if (!text.contains('@')) return false;
    final parts = text.split('@');
    return parts.length == 2 && parts[0].length >= 3 && parts[1].length >= 2;
  }

  void _applyHandle(String handle) {
    HapticFeedback.lightImpact();
    final text = _upiController.text.trim();
    if (text.isEmpty) {
      _upiController.text = handle;
      _upiController.selection = TextSelection.collapsed(offset: 0);
      return;
    }

    if (text.contains('@')) {
      final username = text.split('@')[0];
      _upiController.text = '$username$handle';
    } else {
      _upiController.text = '$text$handle';
    }
    _upiController.selection = TextSelection.collapsed(offset: _upiController.text.length);
  }

  Future<void> _savePayoutSettings() async {
    HapticFeedback.mediumImpact();
    final upiId = _upiController.text.trim();

    if (upiId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('UPI ID cannot be empty'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_isValidUpi) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid UPI address (e.g. 9876543210@upi)'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final currentPayout = widget.currentData['payoutSettings'] as Map? ?? {};
      final updatedPayout = Map<String, dynamic>.from(currentPayout);
      updatedPayout['upiId'] = upiId;
      await SupabaseConfig.client.from('workers').update({
        'payout_settings': updatedPayout,
      }).eq('id', uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Instant UPI Payout linked to $upiId',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingUpi = widget.currentData['payoutSettings']?['upiId'] as String?;
    final hasExistingUpi = existingUpi != null && existingUpi.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/worker/profile');
            }
          },
        ),
        title: Text(
          'Instant Payout Setup',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF0D7844)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D7844).withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: hasExistingUpi ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hasExistingUpi ? 'ACTIVE PAYOUT LINK' : 'ACTION REQUIRED',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.bolt_rounded, color: Color(0xFFFBBF24), size: 24),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hasExistingUpi ? existingUpi : 'Direct UPI Cashout',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Instant 24x7 settlements directly to your bank account with ₹0 platform withdrawal fee.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Form Title
            Text(
              'Enter UPI ID / VPA',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Link your Google Pay, PhonePe, Paytm, or BHIM Virtual Payment Address.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 14),

            // UPI Input Box with Live Status Icon
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isValidUpi
                      ? const Color(0xFF059669)
                      : (_upiController.text.isNotEmpty
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFE2E8F0)),
                  width: _isValidUpi ? 2 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded,
                        color: Color(0xFF0D7844), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _upiController,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'e.g. 9876543210@upi',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_upiController.text.isNotEmpty)
                    Icon(
                      _isValidUpi ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      color: _isValidUpi ? const Color(0xFF059669) : const Color(0xFFF59E0B),
                      size: 20,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Live Validation Helper Pill
            if (_upiController.text.isNotEmpty)
              Row(
                children: [
                  Icon(
                    _isValidUpi ? Icons.shield_rounded : Icons.warning_amber_rounded,
                    size: 14,
                    color: _isValidUpi ? const Color(0xFF059669) : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isValidUpi
                        ? 'Valid UPI address format ready for instant settlements'
                        : 'Please enter a valid handle (must include @bank)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isValidUpi ? const Color(0xFF059669) : const Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),

            // Quick App Handle Chips
            Text(
              'Quick Handles',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _popularHandles.map((handle) {
                final isSelected = _upiController.text.endsWith(handle);
                return InkWell(
                  onTap: () => _applyHandle(handle),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF0D7844) : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      handle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? const Color(0xFF0D7844) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Trust & Security Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_user_rounded, color: Color(0xFF0D7844), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '100% Secure NPCI & RBI Direct Settlement',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your UPI address is encrypted with 256-bit banking protocols. Jugaad never stores your UPI PIN or banking passwords.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Save Action CTA
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _savePayoutSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: WorkerAppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  shadowColor: WorkerAppTheme.primaryGreen.withValues(alpha: 0.35),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Save & Link UPI Address',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
