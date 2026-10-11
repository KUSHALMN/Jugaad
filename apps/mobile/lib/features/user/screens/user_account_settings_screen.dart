import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/theme/app_text_styles.dart';
import 'package:jugaad_mvp/core/services/api_service.dart';

class UserAccountSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> currentData;
  const UserAccountSettingsScreen({super.key, required this.currentData});

  @override
  State<UserAccountSettingsScreen> createState() => _UserAccountSettingsScreenState();
}

class _UserAccountSettingsScreenState extends State<UserAccountSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final name = widget.currentData['display_name'] as String? ?? widget.currentData['name'] as String? ?? '';
    _nameController = TextEditingController(text: name);
    _emailController = TextEditingController(text: widget.currentData['email'] as String? ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty'), backgroundColor: AppColors.danger),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await SupabaseConfig.client.from('users').upsert({
        'id': uid,
        'name': name,
        'email': email,
        'role': 'employer',
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account updated successfully'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating account: $e'), backgroundColor: AppColors.danger),
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

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
            SizedBox(width: 8),
            Text('Delete Account?'),
          ],
        ),
        content: const Text(
          'This action is irreversible. All your profile information, saved addresses, and active bookings will be permanently erased in accordance with Google Play data safety regulations.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete Forever', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await ApiService().deleteAccount();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        context.go('/auth/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = widget.currentData['phone'] as String? ?? 'N/A';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/user/home');
            }
          },
        ),
        title: Text(
          'Account Settings',
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
              'Profile Details',
              style: AppTextStyles.heading3(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep your user profile information updated for accurate booking coordinates.',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            // Name Field
            Text(
              'Full Name',
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary, weight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
              decoration: InputDecoration(
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
                  borderSide: const BorderSide(color: AppColors.kUserPrimary, width: 2.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              ),
            ),
            const SizedBox(height: 20),

            // Email Field
            Text(
              'Email Address',
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary, weight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
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
                  borderSide: const BorderSide(color: AppColors.kUserPrimary, width: 2.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              ),
            ),
            const SizedBox(height: 20),

            // Phone Field (Read-only)
            Text(
              'Phone Number (Linked to Auth)',
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary, weight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              enabled: false,
              controller: TextEditingController(text: phone),
              style: AppTextStyles.bodyLarge(color: AppColors.textSecondary),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.04), width: 1.0),
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
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kUserPrimary,
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
                        'Save Changes',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            const SizedBox(height: 36),
            const Divider(),
            const SizedBox(height: 20),

            // Danger Zone (Google Play Requirement)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Account Deletion & Data Erasure',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Permanently delete your account, contact details, and location telemetry in compliance with DPDP Act & Google Play policies.',
                    style: TextStyle(color: Color(0xFF7F1D1D), fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _deleteAccount,
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
                    label: const Text(
                      'Delete My Account',
                      style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
}
