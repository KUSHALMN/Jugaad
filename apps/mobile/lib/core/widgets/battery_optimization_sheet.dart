import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Vernacular-friendly bottom sheet that guides trade workers to disable
/// OEM battery saver killing the app during en-route tracking.
class BatteryOptimizationSheet extends StatelessWidget {
  final VoidCallback? onSettingsTap;
  final VoidCallback? onDismiss;

  const BatteryOptimizationSheet({
    super.key,
    this.onSettingsTap,
    this.onDismiss,
  });

  static Future<void> show(BuildContext context, {VoidCallback? onSettingsTap}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BatteryOptimizationSheet(
        onSettingsTap: onSettingsTap,
        onDismiss: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.battery_alert_rounded, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keep Location Active',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'ಬ್ಯಾಟರಿ ಉಳಿತಾಯ ಮೋಡ್ ನಿಷ್ಕ್ರಿಯಗೊಳಿಸಿ',
                      style: GoogleFonts.notoSansKannada(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Xiaomi, Vivo, and Oppo phones often stop GPS when the screen is locked. To ensure you receive high-paying nearby jobs and live navigation works while driving:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.5,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 14),
          _buildStep('1', 'Go to Battery / App Settings', 'ಆ್ಯಪ್ ಸೆಟ್ಟಿಂಗ್ಸ್‌ಗೆ ಹೋಗಿ'),
          _buildStep('2', 'Select "No Restrictions" for Jugaad', '"ನಿರ್ಬಂಧಗಳಿಲ್ಲ" ಆಯ್ಕೆಮಾಡಿ'),
          _buildStep('3', 'Enable Autostart for reliable alerts', 'ಆಟೋಸ್ಟಾರ್ಟ್ ಆನ್ ಮಾಡಿ'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss ?? () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Later',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onSettingsTap ?? () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Open Settings',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildStep(String num, String title, String kannada) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: const Color(0xFFEFF6FF),
            child: Text(
              num,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                ),
                Text(
                  kannada,
                  style: GoogleFonts.notoSansKannada(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
