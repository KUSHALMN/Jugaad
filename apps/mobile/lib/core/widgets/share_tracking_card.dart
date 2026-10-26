import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// One-tap WhatsApp live tracking share card for household & family safety.
/// Generates a signed link so elderly parents or spouses can track arrival.
class ShareTrackingCard extends StatelessWidget {
  final String jobId;
  final String workerName;
  final String skill;
  final String trackingUrl;

  const ShareTrackingCard({
    super.key,
    required this.jobId,
    required this.workerName,
    required this.skill,
    required this.trackingUrl,
  });

  Future<void> _shareOnWhatsApp(BuildContext context) async {
    final message = Uri.encodeComponent(
      '🛡️ Jugaad Live Safety Tracker:\n'
      'Verified $skill ($workerName) is en route to our home.\n'
      'Track live arrival here: $trackingUrl'
    );
    final whatsappUri = Uri.parse('https://wa.me/?text=$message');
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    } catch (e) {
      debugPrint('WhatsApp share error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share_location_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share Live Ride with Family',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF14532D)),
                ),
                Text(
                  'Send live doorstep tracker via WhatsApp',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF166534)),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _shareOnWhatsApp(context),
            icon: const Icon(Icons.send_rounded, size: 14),
            label: Text(
              'Share',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
