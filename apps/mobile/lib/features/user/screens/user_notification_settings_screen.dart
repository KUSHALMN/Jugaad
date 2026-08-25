import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/theme/app_text_styles.dart';
import 'package:jugaad_mvp/shared/widgets/jugaad_card.dart';

class UserNotificationSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> currentData;
  const UserNotificationSettingsScreen({super.key, required this.currentData});

  @override
  State<UserNotificationSettingsScreen> createState() => _UserNotificationSettingsScreenState();
}

class _UserNotificationSettingsScreenState extends State<UserNotificationSettingsScreen> {
  bool _bookingAlerts = true;
  bool _offerAlerts = true;
  bool _isLoading = false;
  late Map<String, dynamic> _userData;

  @override
  void initState() {
    super.initState();
    _userData = Map<String, dynamic>.from(widget.currentData);
    final prefs = _userData['notification_prefs'] as Map? ?? _userData['notificationPrefs'] as Map? ?? {};
    if (prefs.isEmpty && _userData['id'] != null) {
      _fetchLatestSettings();
    } else {
      _bookingAlerts = prefs['bookingAlerts'] as bool? ?? true;
      _offerAlerts = prefs['offerAlerts'] as bool? ?? true;
    }
  }

  Future<void> _fetchLatestSettings() async {
    setState(() => _isLoading = true);
    try {
      final uid = _userData['id'] as String? ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isNotEmpty) {
        final response = await SupabaseConfig.client
            .from('users')
            .select()
            .eq('id', uid)
            .maybeSingle();
        if (response != null && mounted) {
          setState(() {
            _userData = response;
            final prefs = _userData['notification_prefs'] as Map? ?? _userData['notificationPrefs'] as Map? ?? {};
            _bookingAlerts = prefs['bookingAlerts'] as bool? ?? true;
            _offerAlerts = prefs['offerAlerts'] as bool? ?? true;
          });
        }
      }
    } catch (e) {
      print('[UserNotificationSettingsScreen] Error fetching prefs: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updatePref(String key, bool val) async {
    final originalVal = key == 'bookingAlerts' ? _bookingAlerts : _offerAlerts;

    setState(() {
      if (key == 'bookingAlerts') {
        _bookingAlerts = val;
      } else {
        _offerAlerts = val;
      }
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final currentPrefs = _userData['notification_prefs'] as Map? ?? _userData['notificationPrefs'] as Map? ?? {};
      final updatedPrefs = Map<String, dynamic>.from(currentPrefs);
      updatedPrefs[key] = val;

      await SupabaseConfig.client.from('users').update({
        'notification_prefs': updatedPrefs,
      }).eq('id', uid);

      _userData['notification_prefs'] = updatedPrefs;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved'), backgroundColor: AppColors.success, duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      setState(() {
        if (key == 'bookingAlerts') {
          _bookingAlerts = originalVal;
        } else {
          _offerAlerts = originalVal;
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
              'Choose which alerts you want to receive on your device.',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            JugaadCard(
              borderRadius: 20.0,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  // Booking Alerts
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
                                'Booking Alerts',
                                style: AppTextStyles.bodyLarge(color: AppColors.textPrimary, weight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Get notifications when workers confirm, arrive, or complete your jobs.',
                                style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        CupertinoSwitch(
                          value: _bookingAlerts,
                          activeTrackColor: AppColors.kUserPrimary,
                          onChanged: (val) => _updatePref('bookingAlerts', val),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: AppColors.kBorder.withValues(alpha: 0.4)),
                  // Offer Alerts
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
                                'Offers & Updates',
                                style: AppTextStyles.bodyLarge(color: AppColors.textPrimary, weight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Receive alerts for service discounts, promotions, and new features.',
                                style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        CupertinoSwitch(
                          value: _offerAlerts,
                          activeTrackColor: AppColors.kUserPrimary,
                          onChanged: (val) => _updatePref('offerAlerts', val),
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
