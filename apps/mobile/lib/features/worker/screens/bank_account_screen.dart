import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/theme/app_text_styles.dart';

class BankAccountScreen extends StatefulWidget {
  final Map<String, dynamic> currentData;
  const BankAccountScreen({super.key, required this.currentData});

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  late TextEditingController _accountNumberController;
  late TextEditingController _ifscController;
  late TextEditingController _holderNameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final bank = widget.currentData['bankAccount'] as Map? ?? {};
    _accountNumberController = TextEditingController(text: bank['accountNumber'] as String? ?? '');
    _ifscController = TextEditingController(text: bank['ifsc'] as String? ?? '');
    _holderNameController = TextEditingController(text: bank['holderName'] as String? ?? '');
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _ifscController.dispose();
    _holderNameController.dispose();
    super.dispose();
  }

  Future<void> _saveBankAccount() async {
    final accNo = _accountNumberController.text.trim();
    final ifsc = _ifscController.text.trim().toUpperCase();
    final holder = _holderNameController.text.trim();

    if (accNo.isEmpty || ifsc.isEmpty || holder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required'), backgroundColor: AppColors.danger),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      // Supabase: update bank account and payout settings as JSONB
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
          const SnackBar(content: Text('Bank account saved successfully'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving bank account: $e'), backgroundColor: AppColors.danger),
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
          'Bank Account',
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
              'Bank Details',
              style: AppTextStyles.heading3(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Linked bank account for weekly manual or automated payout processing.',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            // Holder Name Field
            Text(
              'Account Holder Name',
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary, weight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _holderNameController,
              style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'As shown in passbook',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08), width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: const BorderSide(color: AppColors.kWorkerPrimary, width: 2.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              ),
            ),
            const SizedBox(height: 20),

            // Account Number Field
            Text(
              'Account Number',
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary, weight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _accountNumberController,
              style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter bank account number',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08), width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: const BorderSide(color: AppColors.kWorkerPrimary, width: 2.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              ),
            ),
            const SizedBox(height: 20),

            // IFSC Code Field
            Text(
              'IFSC Code',
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary, weight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ifscController,
              style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'e.g. SBIN0001234',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08), width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: const BorderSide(color: AppColors.kWorkerPrimary, width: 2.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              ),
            ),
            const SizedBox(height: 40),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveBankAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kWorkerPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Save Bank Details',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
