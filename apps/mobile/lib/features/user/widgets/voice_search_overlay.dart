import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/speech/speech_recognition_base.dart';
import '../../../../core/services/search_history_service.dart';

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

  // Suggested search terms
  final List<String> _suggestions = [
    'Electrician',
    'Plumber',
    'Laptop Repair',
    'Phone Repair',
    'AC Service',
    'Cleaning',
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
    
    // Clean and match with our services list
    final cleanWords = recognizedWords.trim().toLowerCase();
    
    // Find closest service match
    String matchedService = '';
    for (final s in _suggestions) {
      if (cleanWords.contains(s.toLowerCase()) || s.toLowerCase().contains(cleanWords)) {
        matchedService = s;
        break;
      }
    }

    // Fallback if no matching suggestion is found: use the recognized words directly
    if (matchedService.isEmpty) {
      matchedService = recognizedWords.trim();
    }

    SearchHistoryService.instance.addTerm(matchedService);

    HapticFeedback.mediumImpact();
    
    // Wait a brief moment to let user read recognized word, then navigate
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.pop(context); // Close overlay
        // Route to search page preloaded with service query
        context.push('/user/worker-search?service=$matchedService');
      }
    });
  }

  void _onSuggestionTap(String service) {
    SearchHistoryService.instance.addTerm(service);
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    context.push('/user/worker-search?service=$service');
  }

  @override
  Widget build(BuildContext context) {
    final scaleMultiplier = 1.0 + (_soundLevel.abs() * 0.05);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header title
              Text(
                'Voice Search',
                style: GoogleFonts.syne(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Speak electrical, plumbing, laptop repair...',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 48),

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
              const SizedBox(height: 40),

              // Transcribed/Speech Status Text
              Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _speechText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _isListening ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              const Divider(color: Color(0xFFE2E8F0), height: 1),
              const SizedBox(height: 20),

              // Suggestions title
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Popular Searches',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF475569),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),

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
                        style: GoogleFonts.dmSans(
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
                const SizedBox(height: 20),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Searches',
                      style: GoogleFonts.dmSans(
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
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _history.map((term) {
                    return Container(
                      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
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
                                  color: Color(0xFF1A56DB),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  term,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1A56DB),
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
    );
  }
}
