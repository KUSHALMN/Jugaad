import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_mvp/core/services/suraksha_service.dart';
import 'package:jugaad_mvp/core/constants/jugaad_strings.dart';

void main() {
  group('SurakshaService & JugaadStrings Tests', () {
    final service = SurakshaService();

    test('buildWhatsAppLiveShareMessage correctly formats worker and job details', () {
      final msg = service.buildWhatsAppLiveShareMessage(
        workerName: 'Ramesh Kumar',
        serviceName: 'Plumber',
        jobId: 'job_4821',
      );

      expect(msg, contains('Ramesh Kumar'));
      expect(msg, contains('Plumber'));
      expect(msg, contains('https://jugaad.app/track/job_4821'));
      expect(msg, contains('KYC Aadhaar Verified'));
    });

    test('JugaadStrings contains valid vernacular constants', () {
      expect(JugaadStrings.voiceBookingTitle, isNotEmpty);
      expect(JugaadStrings.voiceBookingSubtitleKannada, contains('ಧ್ವನಿ'));
      expect(JugaadStrings.surakshaTitle, contains('Suraksha Shield'));
      expect(JugaadStrings.warrantyActiveTitle, contains('30-Day'));
      expect(JugaadStrings.workerGate, contains('Gate'));
      expect(JugaadStrings.customerDoorbell, contains('Doorbell'));
    });
  });
}
