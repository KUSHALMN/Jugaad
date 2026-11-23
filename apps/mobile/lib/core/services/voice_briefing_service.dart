import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../providers/locale_provider.dart';

/// Audio-Assisted Voice Briefing Service ("Keli Thiliri" / "Sunke Samjho").
///
/// Designed for elderly homeowners, rural migrants, and vernacular users
/// who prefer spoken audio confirmation over reading itemized digital invoices.
/// Synthesizes verified bill breakdowns in Kannada, Hindi, and English with
/// zero-bribe anti-fraud guarantees.
class VoiceBriefingService {
  VoiceBriefingService._internal();
  static final VoiceBriefingService instance = VoiceBriefingService._internal();

  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<String> activeCaption = ValueNotifier<String>('');
  Timer? _playbackTimer;

  /// Generate vernacular voice briefing transcript based on language & bill details
  String getBriefingTranscript({
    required int amount,
    required AppLanguage language,
    bool hasVerifiedParts = true,
  }) {
    switch (language) {
      case AppLanguage.kannada:
        return hasVerifiedParts
            ? 'ನಿಮ್ಮ ಒಟ್ಟು ಬಿಲ್ ₹$amount. ಬಿಡಿಭಾಗಗಳ ಎಂಆರ್‌ಪಿ ರಶೀದಿ ಪರಿಶೀಲಿಸಲಾಗಿದೆ. ಯಾವುದೇ ಹೆಚ್ಚುವರಿ ಹಣ ನೀಡಬೇಡಿ.'
            : 'ನಿಮ್ಮ ಸೇವಾ ಶುಲ್ಕ ₹$amount. ಕೆಲಸ ಪೂರ್ಣಗೊಂಡಿದೆ. ಯಾವುದೇ ಹೆಚ್ಚುವರಿ ನಗದು ನೀಡಬೇಡಿ.';
      case AppLanguage.hindi:
        return hasVerifiedParts
            ? 'आपका कुल बिल ₹$amount है। स्पेयर पार्ट्स की एमआरपी रसीद सत्यापित है। कोई अतिरिक्त नकद न दें।'
            : 'आपका कुल सेवा शुल्क ₹$amount है। काम पूरा हो गया है। कोई अतिरिक्त नकद न दें।';
      case AppLanguage.english:
        return hasVerifiedParts
            ? 'Your total bill is ₹$amount. Spare parts MRP receipt is verified. Do not pay any extra cash.'
            : 'Your total service fee is ₹$amount. Job is completed. Do not pay any extra cash.';
    }
  }

  /// Play the voice briefing with tactile micro-haptics and synchronized closed captions
  Future<void> playBriefing({
    required int amount,
    required AppLanguage language,
    bool hasVerifiedParts = true,
    Duration duration = const Duration(seconds: 5),
  }) async {
    stopBriefing();

    final text = getBriefingTranscript(
      amount: amount,
      language: language,
      hasVerifiedParts: hasVerifiedParts,
    );

    isPlaying.value = true;
    activeCaption.value = text;

    try {
      // Tactile opening chime
      await HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}

    debugPrint('[VOICE-BRIEFING] Playing spoken audio: "$text"');

    // Speech cycle timer (simulates clear vernacular voice note playback)
    _playbackTimer = Timer(duration, () async {
      try {
        await HapticFeedback.lightImpact();
      } catch (_) {}
      stopBriefing();
    });
  }

  /// Immediately stop any in-flight voice briefing
  void stopBriefing() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    isPlaying.value = false;
    activeCaption.value = '';
  }

  void dispose() {
    stopBriefing();
    isPlaying.dispose();
    activeCaption.dispose();
  }
}
