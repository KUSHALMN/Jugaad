import 'package:url_launcher/url_launcher.dart';

/// Service dedicated to Jugaad Suraksha Trust & Safety workflows.
class SurakshaService {
  static final SurakshaService _instance = SurakshaService._internal();
  factory SurakshaService() => _instance;
  SurakshaService._internal();

  /// Formats the live trip sharing message for WhatsApp.
  String buildWhatsAppLiveShareMessage({
    required String workerName,
    required String serviceName,
    required String jobId,
  }) {
    final workerId = 'JGD-${(jobId.hashCode.abs() % 9000 + 1000)}';
    final shareUrl = 'https://jugaad.app/track/$jobId';

    return '🛡️ *Jugaad Suraksha Live Status*\n\n'
        '$workerName ($serviceName, ID: $workerId) is currently servicing my home.\n'
        '• Live GPS Tracking: $shareUrl\n'
        '• KYC Aadhaar Verified & Police Cleared\n'
        '• Insured under Jugaad Safety Guarantee.';
  }

  /// Launches the WhatsApp intent with pre-filled message.
  Future<bool> launchWhatsAppLiveTrip({
    required String workerName,
    required String serviceName,
    required String jobId,
  }) async {
    final message = buildWhatsAppLiveShareMessage(
      workerName: workerName,
      serviceName: serviceName,
      jobId: jobId,
    );

    final encoded = Uri.encodeComponent(message);
    final waUri = Uri.parse('https://wa.me/?text=$encoded');

    if (await canLaunchUrl(waUri)) {
      return await launchUrl(waUri, mode: LaunchMode.externalApplication);
    } else {
      return await launchUrl(waUri);
    }
  }

  /// Triggers a phone call to the emergency services hotline.
  Future<bool> dialEmergencyHotline(String number) async {
    final telUri = Uri.parse('tel:$number');
    if (await canLaunchUrl(telUri)) {
      return await launchUrl(telUri);
    }
    return false;
  }
}
