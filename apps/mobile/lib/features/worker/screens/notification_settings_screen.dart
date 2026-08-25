import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/theme/app_text_styles.dart';
import 'package:jugaad_mvp/shared/widgets/jugaad_card.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> currentData;
  const NotificationSettingsScreen({super.key, required this.currentData});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  late bool _jobAlerts;
  late bool _paymentAlerts;

  @override
  void initState() {
    super.initState();
    final prefs = widget.currentData['notificationPrefs'] as Map? ?? {};
    _jobAlerts = prefs['jobAlerts'] as bool? ?? true;
    _paymentAlerts = prefs['paymentAlerts'] as bool? ?? true;
  }

  Future<void> _updatePref(String key, bool val) async {
    final originalVal = key == 'jobAlerts' ? _jobAlerts : _paymentAlerts;
    
    setState(() {
      if (key == 'jobAlerts') {
        _jobAlerts = val;
      } else {
        _paymentAlerts = val;
      }
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      // Supabase: update nested JSON via JSONB merge
      final currentPrefs = widget.currentData['notificationPrefs'] as Map? ?? {};
      final updatedPrefs = Map<String, dynamic>.from(currentPrefs);
      updatedPrefs[key] = val;
      await SupabaseConfig.client.from('workers').update({
        'notification_prefs': updatedPrefs,
      }).eq('id', uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved'), backgroundColor: AppColors.success, duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      setState(() {
        if (key == 'jobAlerts') {
          _jobAlerts = originalVal;
        } else {
          _paymentAlerts = originalVal;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: $e'), backgroundColor: AppColors.danger),
        );
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
          'Notification Settings',
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
              'Alert Preferences',
              style: AppTextStyles.heading3(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how you want to be notified about bookings and payments.',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            JugaadCard(
              borderRadius: 20.0,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  // Job Alerts Toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Job Alerts',
                                style: AppTextStyles.bodyLarge(color: AppColors.textPrimary, weight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Get notified instantly when new jobs match your specialities nearby.',
                                style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        CupertinoSwitch(
                          value: _jobAlerts,
                          activeTrackColor: AppColors.kWorkerPrimary,
                          onChanged: (val) => _updatePref('jobAlerts', val),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: AppColors.kBorder.withValues(alpha: 0.4)),
                  // Payment Alerts Toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Alerts',
                                style: AppTextStyles.bodyLarge(color: AppColors.textPrimary, weight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Get notified when your payouts are successfully processed.',
                                style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        CupertinoSwitch(
                          value: _paymentAlerts,
                          activeTrackColor: AppColors.kWorkerPrimary,
                          onChanged: (val) => _updatePref('paymentAlerts', val),
                        ),
                      ],
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
