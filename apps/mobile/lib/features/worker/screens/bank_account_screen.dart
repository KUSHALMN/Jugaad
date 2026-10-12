import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/theme/worker_app_theme.dart';

class BankAccountScreen extends StatefulWidget {
  final Map<String, dynamic> currentData;
  const BankAccountScreen({super.key, required this.currentData});

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  late TextEditingController _accountNumberController;
  late TextEditingController _confirmAccountNumberController;
  late TextEditingController _ifscController;
  late TextEditingController _holderNameController;
  bool _isLoading = false;
  bool _obscureAccount = false;

  @override
  void initState() {
    super.initState();
    final bank = widget.currentData['bankAccount'] as Map? ?? {};
    final existingAcc = bank['accountNumber'] as String? ?? '';
    _accountNumberController = TextEditingController(text: existingAcc);
    _confirmAccountNumberController = TextEditingController(text: existingAcc);
    _ifscController = TextEditingController(text: bank['ifsc'] as String? ?? '');
    _holderNameController = TextEditingController(text: bank['holderName'] as String? ?? '');

    _ifscController.addListener(() {
      if (mounted) setState(() {});
    });
    _accountNumberController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _confirmAccountNumberController.dispose();
    _ifscController.dispose();
    _holderNameController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _detectedBank {
    final ifsc = _ifscController.text.trim().toUpperCase();
    if (ifsc.length < 4) return null;
    final prefix = ifsc.substring(0, 4);

    if (prefix == 'SBIN') {
      return {'name': 'State Bank of India', 'color': const Color(0xFF1E40AF)};
    } else if (prefix == 'HDFC') {
      return {'name': 'HDFC Bank', 'color': const Color(0xFF0F172A)};
    } else if (prefix == 'ICIC') {
      return {'name': 'ICICI Bank', 'color': const Color(0xFFEA580C)};
    } else if (prefix == 'UTIB' || prefix == 'AXIS') {
      return {'name': 'Axis Bank', 'color': const Color(0xFF9D174D)};
    } else if (prefix == 'PUNB') {
      return {'name': 'Punjab National Bank', 'color': const Color(0xFFB45309)};
    } else if (prefix == 'KKBK') {
      return {'name': 'Kotak Mahindra Bank', 'color': const Color(0xFFDC2626)};
    } else if (prefix == 'BARB') {
      return {'name': 'Bank of Baroda', 'color': const Color(0xFFEA580C)};
    } else if (prefix == 'CNRB') {
      return {'name': 'Canara Bank', 'color': const Color(0xFF0284C7)};
    }
    return {'name': 'Recognized Scheduled Bank', 'color': const Color(0xFF0D7844)};
  }

  Future<void> _saveBankAccount() async {
    HapticFeedback.mediumImpact();
    final accNo = _accountNumberController.text.trim();
    final confirmAccNo = _confirmAccountNumberController.text.trim();
    final ifsc = _ifscController.text.trim().toUpperCase();
    final holder = _holderNameController.text.trim();

    if (accNo.isEmpty || ifsc.isEmpty || holder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all banking fields'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (accNo != confirmAccNo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account numbers do not match'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (ifsc.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('IFSC code must be exactly 11 characters (e.g. SBIN0001234)'),
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
      final currentBank = widget.currentData['bankAccount'] as Map? ?? {};
      final updatedBank = Map<String, dynamic>.from(currentBank);
      updatedBank['accountNumber'] = accNo;
      updatedBank['ifsc'] = ifsc;
      updatedBank['holderName'] = holder;

      final currentPayout = widget.currentData['payoutSettings'] as Map? ?? {};
      final updatedPayout = Map<String, dynamic>.from(currentPayout);
      updatedPayout['bankAccountLinked'] = true;

      await SupabaseConfig.client.from('workers').update({
        'bank_account': updatedBank,
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
                    'Bank account successfully verified & saved',
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
            content: Text('Error saving bank account: $e'),
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
    final bank = widget.currentData['bankAccount'] as Map? ?? {};
    final existingAcc = bank['accountNumber'] as String? ?? '';
    final hasExistingBank = existingAcc.isNotEmpty;
    final detected = _detectedBank;

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
          'Bank Account Details',
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
            // FinTech Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.25),
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
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: hasExistingBank ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hasExistingBank ? 'SETTLEMENT ACCOUNT LINKED' : 'UNLINKED ACCOUNT',
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
                      const Icon(Icons.account_balance_rounded, color: Colors.white70, size: 22),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    hasExistingBank
                        ? '•••• •••• ${existingAcc.length >= 4 ? existingAcc.substring(existingAcc.length - 4) : existingAcc}'
                        : 'Link Savings or Current Account',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Direct IMPS & NEFT bank deposit for weekly automated payouts.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Account Holder Name Field
            _buildFieldLabel('Account Holder Name', 'Must match name printed on bank passbook / cheque'),
            const SizedBox(height: 8),
            _buildInputField(
              controller: _holderNameController,
              hint: 'e.g. Ramesh Kumar',
              icon: Icons.person_rounded,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 20),

            // Account Number Field
            _buildFieldLabel('Bank Account Number', 'Enter your full savings or current account number'),
            const SizedBox(height: 8),
            _buildInputField(
              controller: _accountNumberController,
              hint: 'Enter account number',
              icon: Icons.numbers_rounded,
              keyboardType: TextInputType.number,
              obscureText: _obscureAccount,
              suffix: IconButton(
                icon: Icon(
                  _obscureAccount ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: const Color(0xFF94A3B8),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureAccount = !_obscureAccount),
              ),
            ),
            const SizedBox(height: 20),

            // Confirm Account Number Field
            _buildFieldLabel('Re-enter Account Number', 'Verify digits to avoid settlement failure'),
            const SizedBox(height: 8),
            _buildInputField(
              controller: _confirmAccountNumberController,
              hint: 'Re-enter account number',
              icon: Icons.lock_outline_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            // IFSC Code Field
            _buildFieldLabel('IFSC Code', '11-character code printed on cheque or passbook'),
            const SizedBox(height: 8),
            _buildInputField(
              controller: _ifscController,
              hint: 'e.g. SBIN0001234',
              icon: Icons.domain_rounded,
              textCapitalization: TextCapitalization.characters,
            ),

            // Dynamic Bank Badge
            if (detected != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: (detected['color'] as Color).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (detected['color'] as Color).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_rounded, color: detected['color'] as Color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Verified Bank: ${detected['name']}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: detected['color'] as Color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),

            // Security & Passbook Match Tip
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
                  const Icon(Icons.shield_rounded, color: Color(0xFF0D7844), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Automated Penny-Drop Verification',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'A ₹1 test deposit will be initiated by the banking switch to verify active status. Payouts are credited directly via RBI-authorized IMPS channels.',
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

            // Save Action Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveBankAccount,
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
                            'Save & Verify Bank Account',
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

  Widget _buildFieldLabel(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
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
            child: Icon(icon, color: const Color(0xFF0D7844), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              obscureText: obscureText,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          ...?suffix == null ? null : [suffix],
        ],
      ),
    );
  }
}
