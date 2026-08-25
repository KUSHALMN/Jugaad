import 'speech_recognition_stub.dart'
    if (dart.library.html) 'speech_recognition_web.dart'
    if (dart.library.io) 'speech_recognition_mobile.dart';

abstract class SpeechRecognitionService {
  factory SpeechRecognitionService() => getSpeechRecognitionService();

  Future<bool> initialize({
    required Function(String status) onStatus,
    required Function(String error) onError,
    required Function(String words, bool isFinal) onResult,
    required Function(double level) onSoundLevelChange,
  });

  Future<void> start();
  Future<void> stop();
  bool get isListening;
}
