import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/speech/speech_recognition_base.dart';
import '../../../../core/services/search_history_service.dart';
import '../../../../core/utils/category_utils.dart';

class VoiceSearchOverlay extends StatefulWidget {
  const VoiceSearchOverlay({super.key});

  @override
  State<VoiceSearchOverlay> createState() => _VoiceSearchOverlayState();
}

class _VoiceSearchOverlayState extends State<VoiceSearchOverlay> {
  final SpeechRecognitionService _speech = SpeechRecognitionService();
  bool _isListening = false;
  String _speechText = 'Listening... Speak now';
  bool _speechEnabled = false;
  double _soundLevel = 0.0;
  
  String _latestWords = '';
  bool _hasProcessed = false;
  
  List<String> _history = [];
  Map<String, String>? _detectedBooking;

  // Suggested search terms with bilingual vernacular support
  final List<String> _suggestions = [
    'Electrician / इलेक्ट्रीशियन',
    'Plumber / प्लंबर',
    'Fan Repair / पंखा रिपेयर',
    'AC Cooling / एसी सर्विस',
    'Laptop Repair / लैपटॉप',
    'Stove Gas / चूल्हा रिपेयर',
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await SearchHistoryService.instance.getHistory();
    if (mounted) {
      setState(() {
        _history = history;
      });
    }
  }

  Future<void> _initSpeech() async {
    try {
      final hasSpeech = await _speech.initialize(
        onStatus: (val) {
          print('[VoiceSearch] Status update: $val');
          if (val == 'done' || val == 'notListening') {
            if (mounted) {
              setState(() {
                _isListening = false;
              });
              
              // Fallback: If not listening and we have recognized words but haven't processed yet, process now!
              if (!_hasProcessed && _latestWords.trim().isNotEmpty) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted && !_isListening && !_hasProcessed) {
                    _processSpeechResult(_latestWords);
                  }
                });
              }
            }
          }
        },
        onError: (val) {
          print('[VoiceSearch] Error update: $val');
          if (mounted) {
            String friendlyMsg = 'Voice not recognized. Please try again.';
            if (val == 'not-allowed') {
              friendlyMsg = 'Microphone permission blocked. Please allow microphone access in your browser settings and try again.';
            } else if (val == 'no-speech') {
              friendlyMsg = 'No speech detected. Please speak clearly into the microphone.';
            } else if (val == 'network') {
              friendlyMsg = 'Network error. Speech recognition requires internet connection.';
            } else if (val == 'aborted') {
              friendlyMsg = 'Speech search was stopped.';
            } else if (val == 'audio-capture') {
              friendlyMsg = 'No microphone detected. Please check your system audio settings.';
            }
            setState(() {
              _isListening = false;
              _speechText = friendlyMsg;
            });
          }
        },
        onResult: (words, isFinal) {
          if (mounted) {
            setState(() {
              _latestWords = words;
              _speechText = words;
            });
            if (isFinal) {
              _processSpeechResult(words);
            }
          }
        },
        onSoundLevelChange: (level) {
          if (mounted) {
            setState(() {
              _soundLevel = level;
            });
          }
        },
      );
      
      if (mounted) {
        setState(() {
          _speechEnabled = hasSpeech;
        });
        if (hasSpeech) {
          _startListening();
        } else {
          setState(() {
            _speechText = 'Speech search is unavailable. Tap a suggestion below:';
          });
        }
      }
    } catch (e) {
      print('[VoiceSearch] Speech initialization exception: $e');
      if (mounted) {
        setState(() {
          _speechEnabled = false;
          _speechText = 'Speech search is unavailable. Tap a suggestion below:';
        });
      }
    }
  }

  void _startListening() async {
    if (!_speechEnabled) return;
    
    HapticFeedback.mediumImpact();
    setState(() {
      _isListening = true;
      _speechText = 'Listening... Speak now';
      _latestWords = '';
      _hasProcessed = false;
      _soundLevel = 0.0;
    });

    try {
      await _speech.start();
    } catch (e) {
      print('[VoiceSearch] Listen exception: $e');
    }
  }

  void _stopListening() async {
    await _speech.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _processSpeechResult(String recognizedWords) {
    if (_hasProcessed || recognizedWords.trim().isEmpty) return;
    _hasProcessed = true;

    final cleanWords = recognizedWords.trim().toLowerCase();

    // 🧠 Multi-lingual Vernacular NLP Detection (Kannada, Hindi, English)
    final canonical = CategoryUtils.normalize(cleanWords);
    String displayLabel;
    String estimatedFare = '₹199 Base Inspection';
    String problemDesc = 'Service request detected';
    String iconChar = '🛠️';

    switch (canonical) {
      case 'Plumber':
        displayLabel = 'Plumber / ಪ್ಲಂಬರ್';
        estimatedFare = '₹199 Base Inspection';
        problemDesc = 'Water leakage or pipe blockage detected';
        iconChar = '🔧';
        break;
      case 'Electrician':
        displayLabel = 'Electrician / ಇಲೆಕ್ಟ್ರಿಷಿಯನ್';
        estimatedFare = '₹149 Base Inspection';
        problemDesc = 'Electrical appliance, switch or wiring issue';
        iconChar = '⚡';
        break;
      case 'AC Service':
        displayLabel = 'AC Service / ಎಸಿ ಸರ್ವಿಸ್';
        estimatedFare = '₹399 Deep Service';
        problemDesc = 'Cooling efficiency & coil servicing detected';
        iconChar = '❄️';
        break;
      case 'Cleaning':
        displayLabel = 'Home Cleaning / ಮನೆ ಸ್ವಚ್ಛತೆ';
        estimatedFare = '₹499 Deep Clean';
        problemDesc = 'Deep home sanitation & disinfection';
        iconChar = '✨';
        break;
      case 'Laptop Repair':
        displayLabel = 'Laptop Repair / ಲ್ಯಾಪ್ಟಾಪ್';
        estimatedFare = '₹299 Base Inspection';
        problemDesc = 'Hardware or software diagnosis';
        iconChar = '💻';
        break;
      case 'Phone Repair':
        displayLabel = 'Phone Repair / ಮೊಬೈಲ್';
        estimatedFare = '₹199 Inspection';
        problemDesc = 'Screen, battery, or hardware servicing';
        iconChar = '📱';
        break;
      case 'Carpenter':
        displayLabel = 'Carpenter / ಕಾರ್ಪೆಂಟರ್';
        estimatedFare = '₹249 Base Visit';
        problemDesc = 'Woodwork, door lock & furniture repair';
        iconChar = '🪚';
        break;
      case 'Painter':
        displayLabel = 'Painter / ಪೇಂಟರ್';
        estimatedFare = '₹349 Visit';
        problemDesc = 'Wall painting & touchup service';
        iconChar = '🎨';
        break;
      case 'RO Service':
        displayLabel = 'Water Purifier / ವಾಟರ್ ಪ್ಯೂರಿಫೈಯರ್';
        estimatedFare = '₹249 Service';
        problemDesc = 'RO filter replacement & TDS balancing';
        iconChar = '💧';
        break;
      default:
        displayLabel = canonical.isNotEmpty ? '$canonical / ರಿಪೇರಿ' : 'General Repair / ರಿಪೇರಿ';
        estimatedFare = '₹199 Base Visit';
        problemDesc = recognizedWords.trim();
        iconChar = '🔧';
    }

    SearchHistoryService.instance.addTerm(displayLabel);
    HapticFeedback.heavyImpact();

    setState(() {
      _detectedBooking = {
        'canonical': canonical,
        'service': displayLabel,
        'fare': estimatedFare,
        'desc': problemDesc,
        'icon': iconChar,
      };
    });
  }

  void _onSuggestionTap(String service) {
    SearchHistoryService.instance.addTerm(service);
    HapticFeedback.lightImpact();
    final canonical = CategoryUtils.normalize(service);
    Navigator.pop(context);
    context.push('/user/worker-search?service=${Uri.encodeComponent(canonical)}');
  }

  @override
  Widget build(BuildContext context) {
    final scaleMultiplier = 1.0 + (_soundLevel.abs() * 0.05);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        elevation: 0,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header title with close button
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Bol Ke Book Karo 🎙️',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ಧ್ವನಿ ಬುಕಿಂಗ್ • Speak in Kannada, Hindi, or English',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFEA580C),
                    ),
                  ),
                  const SizedBox(height: 24),

              // Ripple animated pulsing microphone button
              GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ring waves (Pulse effect)
                      if (_isListening) ...[
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange.withValues(alpha: 0.12),
                          ),
                        ).animate(onPlay: (c) => c.repeat()).scale(
                              begin: const Offset(0.8, 0.8),
                              end: const Offset(1.5, 1.5),
                              duration: 1200.ms,
                              curve: Curves.easeOut,
                            ).fadeOut(duration: 1200.ms),
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange.withValues(alpha: 0.08),
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                              begin: const Offset(1.0, 1.0),
                              end: const Offset(1.3, 1.3),
                              delay: 400.ms,
                              duration: 1000.ms,
                            ),
                      ],
                      
                      // Center Mic Button with dynamic sound-level scaling
                      AnimatedScale(
                        scale: _isListening ? scaleMultiplier : 1.0,
                        duration: const Duration(milliseconds: 100),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _isListening 
                                  ? [Colors.orange, const Color(0xFFF97316)]
                                  : [AppColors.primary, const Color(0xFF3B82F6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_isListening ? Colors.orange : AppColors.primary).withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Animated Soundwave Equalizer when listening
              if (_isListening)
                _AudioSoundwaveVisualizer(soundLevel: _soundLevel)
              else
                const SizedBox(height: 18),

              const SizedBox(height: 16),

              // Transcribed/Speech Status Text
              Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _speechText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _isListening ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                  ),
                ),
              ),
              
              // 🤖 AI Smart Booking Confirmation Card
              if (_detectedBooking != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '⚡ 15-MIN EXPRESS',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _detectedBooking!['fare']!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            _detectedBooking!['icon']!,
                            style: const TextStyle(fontSize: 26),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _detectedBooking!['service']!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF78350F),
                                  ),
                                ),
                                Text(
                                  _detectedBooking!['desc']!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            final canonical = _detectedBooking!['canonical'] ??
                                CategoryUtils.normalize(_detectedBooking!['service']);
                            Navigator.pop(context);
                            context.push('/user/worker-search?service=${Uri.encodeComponent(canonical)}');
                          },
                          icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                          label: Text(
                            'Confirm & Match Technician / ಖಚಿತಪಡಿಸಿ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),

              const Divider(color: Color(0xFFE2E8F0), height: 1),
              const SizedBox(height: 14),

              // Suggestions title
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Popular Searches',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF475569),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Suggestions chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions.map((s) {
                  return GestureDetector(
                    onTap: () => _onSuggestionTap(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        s,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              if (_history.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Searches',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF475569),
                        letterSpacing: 0.5,
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        await SearchHistoryService.instance.clearHistory();
                        _loadHistory();
                      },
                      child: Text(
                        'Clear All',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _history.map((term) {
                    return Container(
                      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0xFFDCFCE7)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _onSuggestionTap(term),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.history_rounded,
                                  size: 12,
                                  color: Color(0xFF0D7844),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  term,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0D7844),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () async {
                              await SearchHistoryService.instance.removeTerm(term);
                              _loadHistory();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFFDBEAFE),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 10,
                                color: Color(0xFF1A56DB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}

class _AudioSoundwaveVisualizer extends StatelessWidget {
  final double soundLevel;
  const _AudioSoundwaveVisualizer({required this.soundLevel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final double baseHeight = 10.0 + (i % 3) * 6.0;
          final double dynamicHeight = (baseHeight + (soundLevel * 3.5 * (i % 2 == 0 ? 1.2 : 0.8))).clamp(8.0, 36.0);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 4.5,
            height: dynamicHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: const LinearGradient(
                colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          );
        }),
      ),
    );
  }
}
