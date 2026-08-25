// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;
import 'speech_recognition_base.dart';

class WebSpeechRecognitionService implements SpeechRecognitionService {
  js.JsObject? _recognition;
  bool _isListening = false;
  late Function(String status) _onStatus;
  late Function(String error) _onError;
  late Function(String words, bool isFinal) _onResult;
  // ignore: unused_field
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
      final speechClass = js.context['SpeechRecognition'] ?? js.context['webkitSpeechRecognition'];
      if (speechClass == null) {
        print('[WebSpeech] SpeechRecognition is not supported on this browser.');
        return false;
      }

      _recognition = js.JsObject(speechClass);
      _recognition!['continuous'] = false;
      _recognition!['interimResults'] = true;
      _recognition!['lang'] = 'en-US';

      _recognition!['onstart'] = js.JsFunction.withThis((_, [event]) {
        _isListening = true;
        _onStatus('listening');
      });

      _recognition!['onend'] = js.JsFunction.withThis((_, [event]) {
        _isListening = false;
        _onStatus('notListening');
      });

      _recognition!['onerror'] = js.JsFunction.withThis((_, [event]) {
        _isListening = false;
        String errorMsg = 'unknown error';
        if (event != null) {
          final jsEvent = js.JsObject.fromBrowserObject(event);
          errorMsg = jsEvent['error'] as String? ?? 'unknown error';
        }
        print('[WebSpeech] Recognition error event: $errorMsg');
        _onError(errorMsg);
      });

      _recognition!['onresult'] = js.JsFunction.withThis((_, [event]) {
        if (event == null) return;
        final jsEvent = js.JsObject.fromBrowserObject(event);
        final results = jsEvent['results'];
        if (results == null || results['length'] == 0) return;
        
        final lastResultIndex = results['length'] - 1;
        final result = results[lastResultIndex];
        if (result != null && result['length'] > 0) {
          final alternative = result[0];
          if (alternative != null) {
            final jsAlternative = js.JsObject.fromBrowserObject(alternative);
            final transcript = jsAlternative['transcript'] as String? ?? '';
            final isFinal = result['isFinal'] as bool? ?? false;
            
            _onResult(transcript, isFinal);
          }
        }
      });

      return true;
    } catch (e) {
      print('[WebSpeech] Initialization exception: $e');
      return false;
    }
  }

  @override
  Future<void> start() async {
    if (_recognition != null && !_isListening) {
      try {
        _recognition!.callMethod('start');
      } catch (e) {
        print('[WebSpeech] Start recognition error: $e');
      }
    }
  }

  @override
  Future<void> stop() async {
    if (_recognition != null && _isListening) {
      try {
        _recognition!.callMethod('stop');
      } catch (e) {
        print('[WebSpeech] Stop recognition error: $e');
      }
    }
  }
}

SpeechRecognitionService getSpeechRecognitionService() => WebSpeechRecognitionService();
