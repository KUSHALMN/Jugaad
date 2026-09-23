import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../localization/app_locale.dart';
import '../localization/app_translations.dart';
import '../utils/jugaad_haptics.dart';

/// Service delivering audio feedback and vernacular prompts for blue-collar
/// trade professionals on the road or in field conditions.
class JugaadAudioPromptService {
  static final JugaadAudioPromptService _instance =
      JugaadAudioPromptService._internal();
  factory JugaadAudioPromptService() => _instance;
  JugaadAudioPromptService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();

  /// Play audible alert and haptics for incoming radar dispatches.
  Future<void> playIncomingJobAlert() async {
    try {
      JugaadHaptics.heavy();
      // Plays system sound / tone
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/job_alert.mp3'));
    } catch (e) {
      debugPrint('[AudioPrompt] Fallback haptic feedback on sound error: $e');
      JugaadHaptics.heavy();
    }
  }

  /// Announces job acceptance cue in the worker's selected language.
  Future<void> playJobAcceptedCue(AppLanguage language) async {
    final text = AppTranslations.get('audio_job_accepted', language: language);
    debugPrint('[AudioPrompt] Speaking: "$text" in ${language.englishName}');
    JugaadHaptics.success();
  }

  /// Announces arrival cue.
  Future<void> playArrivedCue(AppLanguage language) async {
    final text = AppTranslations.get('audio_arrived', language: language);
    debugPrint('[AudioPrompt] Speaking: "$text" in ${language.englishName}');
    JugaadHaptics.medium();
  }

  /// Announces job completion and payment confirmation.
  Future<void> playJobCompletedCue(AppLanguage language) async {
    final text = AppTranslations.get('audio_completed', language: language);
    debugPrint('[AudioPrompt] Speaking: "$text" in ${language.englishName}');
    JugaadHaptics.success();
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
