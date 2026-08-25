import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'speech_recognition_base.dart';

class MobileSpeechRecognitionService implements SpeechRecognitionService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;
  
  late Function(String status) _onStatus;
  late Function(String error) _onError;
  late Function(String words, bool isFinal) _onResult;
  late Function(double level) _onSoundLevelChange;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> initialize({
    required Function(String status) onStatus,
    required Function(String error) onError,
    required Function(String words, bool isFinal) onResult,
    required Function(double level) onSoundLevelChange,
  }) async {
    _onStatus = onStatus;
    _onError = onError;
    _onResult = onResult;
    _onSoundLevelChange = onSoundLevelChange;

    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            _isListening = false;
          } else if (val == 'listening') {
            _isListening = true;
          }
          _onStatus(val);
        },
        onError: (val) {
          _isListening = false;
          _onError(val.errorMsg);
        },
      );
      return _speechEnabled;
    } catch (e) {
      print('[MobileSpeech] Initialization exception: $e');
      return false;
    }
  }

  @override
  Future<void> start() async {
    if (!_speechEnabled) return;
    _isListening = true;
    try {
      await _speech.listen(
        onResult: (val) {
          _onResult(val.recognizedWords, val.finalResult);
        },
        onSoundLevelChange: (level) {
          _onSoundLevelChange(level);
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 8),
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('[MobileSpeech] Listen exception: $e');
    }
  }

  @override
  Future<void> stop() async {
    await _speech.stop();
    _isListening = false;
  }
}

SpeechRecognitionService getSpeechRecognitionService() => MobileSpeechRecognitionService();
