import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jugaad_mvp/core/services/device_context_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DeviceContextService.instance.clearTrustedContact();
    DeviceContextService.instance.setBatteryForTesting(100, BatteryState.full);
    DeviceContextService.instance.setNetworkForTesting(
      isSlowOrMetered: false,
      isOffline: false,
    );
  });

  group('DeviceContextService', () {
    test('triggers Low-Battery Express Mode below 15% when discharging', () {
      final svc = DeviceContextService.instance;
      svc.setBatteryForTesting(12, BatteryState.discharging);

      expect(svc.isLowBattery, isTrue);
      expect(svc.shouldPauseHeavyMedia, isTrue);
      expect(svc.gpsPollingInterval, const Duration(seconds: 30));

      svc.setBatteryForTesting(12, BatteryState.charging);
      expect(svc.isLowBattery, isFalse);
      expect(svc.gpsPollingInterval, const Duration(seconds: 8));
    });

    test('pauses heavy media on slow/metered network', () {
      final svc = DeviceContextService.instance;
      svc.setNetworkForTesting(isSlowOrMetered: true, isOffline: false);

      expect(svc.isSlowOrMeteredNetwork, isTrue);
      expect(svc.shouldPauseHeavyMedia, isTrue);
    });

    test('ranks services using recent searches, last booked skill, and city', () async {
      final svc = DeviceContextService.instance;
      await svc.recordSearch('plumber');
      await svc.recordBookedSkill('ac_service');

      expect(svc.scoreSkill('ac_service'), greaterThan(svc.scoreSkill('carpenter')));
      expect(svc.scoreSkill('plumber'), greaterThan(svc.scoreSkill('carpenter')));
      expect(
        svc.scoreSkill('electrician', city: 'Mysuru'),
        greaterThan(svc.scoreSkill('carpenter', city: 'Mysuru')),
      );
    });

    test('persists and clears optional Trusted Emergency Contact', () async {
      final svc = DeviceContextService.instance;
      expect(svc.hasTrustedContact, isFalse);

      await svc.saveTrustedContact(name: 'Mom', phone: '+919876543210');
      expect(svc.hasTrustedContact, isTrue);
      expect(svc.trustedContactName, 'Mom');
      expect(svc.trustedContactPhone, '+919876543210');

      await svc.clearTrustedContact();
      expect(svc.hasTrustedContact, isFalse);
    });

    test('persists privacy consent and offline booking draft queue', () async {
      final svc = DeviceContextService.instance;
      await svc.setPrivacyConsent('accepted_all');
      expect(svc.hasSeenPrivacyConsent, isTrue);
      expect(svc.consentStatus, 'accepted_all');
      expect(svc.cookieProfile['consent_status'], 'accepted_all');

      await svc.saveOfflineBookingDraft({
        'skill': 'electrician',
        'description': 'MCB tripping',
      });
      expect(svc.hasOfflineBookingDraft, isTrue);

      await svc.clearOfflineBookingDraft();
      expect(svc.hasOfflineBookingDraft, isFalse);
    });
  });
}
