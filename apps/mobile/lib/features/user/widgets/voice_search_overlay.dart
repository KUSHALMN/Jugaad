import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/speech/speech_recognition_base.dart';
import '../../../../core/services/search_history_service.dart';
import '../../../../core/utils/category_utils.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/locale_provider.dart';

class VoiceSearchOverlay extends ConsumerStatefulWidget {
  const VoiceSearchOverlay({super.key});

  @override
  ConsumerState<VoiceSearchOverlay> createState() => _VoiceSearchOverlayState();
}

class _VoiceSearchOverlayState extends ConsumerState<VoiceSearchOverlay> {
  final SpeechRecognitionService _speech = SpeechRecognitionService();
  bool _isListening = false;
  String _speechText = 'Listening... Speak now';
  bool _speechEnabled = false;
  double _soundLevel = 0.0;

  String _latestWords = '';
  bool _hasProcessed = false;

  List<String> _history = [];
  Map<String, String>? _detectedBooking;

  // Curated popular services with trilingual support and canonical keys
  static const List<Map<String, String>> _suggestionChips = [
    {'icon': '⚡', 'canonical': 'Electrician', 'en': 'Electrician', 'kn': 'ಎಲೆಕ್ಟ್ರಿಷಿಯನ್', 'hi': 'इलेक्ट्रीशियन'},
    {'icon': '🔧', 'canonical': 'Plumber', 'en': 'Plumber', 'kn': 'ಪ್ಲಂಬರ್', 'hi': 'प्लंबर'},
    {'icon': '❄️', 'canonical': 'AC Service', 'en': 'AC Service', 'kn': 'ಎಸಿ ಸರ್ವಿಸ್', 'hi': 'एसी सर्विस'},
    {'icon': '🪚', 'canonical': 'Carpenter', 'en': 'Carpenter', 'kn': 'ಕಾರ್ಪೆಂಟರ್', 'hi': 'बढ़ई'},
    {'icon': '💻', 'canonical': 'Laptop Repair', 'en': 'Laptop Repair', 'kn': 'ಲ್ಯಾಪ್ಟಾಪ್', 'hi': 'लैपटॉप'},
    {'icon': '💧', 'canonical': 'RO Service', 'en': 'Water Purifier', 'kn': 'ವಾಟರ್ ಪ್ಯೂರಿಫೈಯರ್', 'hi': 'वाटर प्यूरीफायर'},
    {'icon': '🍳', 'canonical': 'General', 'en': 'Stove Gas', 'kn': 'ಗ್ಯಾಸ್ ಒಲೆ', 'hi': 'गैस चूल्हा'},
    {'icon': '🎨', 'canonical': 'Painter', 'en': 'Painter', 'kn': 'ಪೇಂಟರ್', 'hi': 'पेंटर'},
    {'icon': '🧹', 'canonical': 'Cleaning', 'en': 'Home Cleaning', 'kn': 'ಮನೆ ಸ್ವಚ್ಛತೆ', 'hi': 'सफाई'},
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
          if (val == 'done' || val == 'notListening') {
            if (mounted) {
              setState(() {
                _isListening = false;
              });

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
          if (mounted) {
            String friendlyMsg = 'Voice not recognized. Please try again.';
            if (val == 'not-allowed') {
              friendlyMsg = 'Microphone permission blocked. Please allow mic access.';
            } else if (val == 'no-speech') {
              friendlyMsg = 'No speech detected. Please speak clearly.';
            } else if (val == 'network') {
              friendlyMsg = 'Network error. Speech recognition requires internet.';
            } else if (val == 'aborted') {
              friendlyMsg = 'Speech search was stopped.';
            } else if (val == 'audio-capture') {
              friendlyMsg = 'No microphone detected.';
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
            _speechText = 'Speech search unavailable. Tap a service below:';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _speechEnabled = false;
          _speechText = 'Speech search unavailable. Tap a service below:';
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
      _detectedBooking = null;
      _soundLevel = 0.0;
    });

    try {
      await _speech.start();
    } catch (_) {}
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
    final tr = ref.watch(translationsProvider);
    final currentLang = ref.watch(localeProvider);
    final scaleMultiplier = 1.0 + (_soundLevel.abs() * 0.04);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        elevation: 0,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: math.min(600, MediaQuery.sizeOf(context).height - 40),
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── HEADER WITH VERNACULAR BADGE & CLOSE BUTTON ──
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          tr.voiceBookingTitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 19,
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
                    tr.voiceBookingSubtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFEA580C),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── MIC HERO OR COMPACT DETECTED STATE ──
                  if (_detectedBooking == null) ...[
                    // Pulsing microphone button with RepaintBoundary for 60fps compositor isolation
                    RepaintBoundary(
                      child: GestureDetector(
                        onTap: _isListening ? _stopListening : _startListening,
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_isListening) ...[
                                Container(
                                  width: 104,
                                  height: 104,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.orange.withValues(alpha: 0.14),
                                  ),
                                )
                                    .animate(onPlay: (c) => c.repeat())
                                    .scale(
                                      begin: const Offset(0.85, 0.85),
                                      end: const Offset(1.4, 1.4),
                                      duration: 1200.ms,
                                      curve: Curves.easeOut,
                                    )
                                    .fadeOut(duration: 1200.ms),
                                Container(
                                  width: 104,
                                  height: 104,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.orange.withValues(alpha: 0.08),
                                  ),
                                )
                                    .animate(onPlay: (c) => c.repeat(reverse: true))
                                    .scale(
                                      begin: const Offset(1.0, 1.0),
                                      end: const Offset(1.25, 1.25),
                                      delay: 300.ms,
                                      duration: 1000.ms,
                                    ),
                              ],
                              AnimatedScale(
                                scale: _isListening ? scaleMultiplier : 1.0,
                                duration: const Duration(milliseconds: 100),
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: _isListening
                                          ? [const Color(0xFFF97316), const Color(0xFFEA580C)]
                                          : [AppColors.primary, const Color(0xFF2563EB)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isListening ? Colors.orange : AppColors.primary)
                                            .withValues(alpha: 0.35),
                                        blurRadius: 16,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Audio soundwave isolated with RepaintBoundary
                    if (_isListening)
                      RepaintBoundary(
                        child: _AudioSoundwaveVisualizer(soundLevel: _soundLevel),
                      )
                    else
                      const SizedBox(height: 14),

                    const SizedBox(height: 8),

                    // Status / Live Transcript Text
                    Container(
                      constraints: const BoxConstraints(minHeight: 36),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _speechText,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _isListening ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Compact active listening reminder & retry pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0xFFFFEDD5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mic_rounded, color: Color(0xFFEA580C), size: 15),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 190),
                            child: Text(
                              _latestWords.isNotEmpty ? _latestWords : _speechText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF9A3412),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _startListening,
                            child: Text(
                              'Tap to retry',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFEA580C),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // AI Smart Booking Confirmation Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            blurRadius: 14,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tr.expressVisitBadge,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _detectedBooking!['fare']!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
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
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _detectedBooking!['service']!,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
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
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_outline_rounded, size: 11, color: Color(0xFF15803D)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    tr.priceLockGuarantee,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF15803D),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                final canonical = _detectedBooking!['canonical'] ??
                                    CategoryUtils.normalize(_detectedBooking!['service']);
                                Navigator.pop(context);
                                context.push(
                                    '/user/worker-search?service=${Uri.encodeComponent(canonical)}');
                              },
                              icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 17),
                              label: Text(
                                tr.confirmAndMatch,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEA580C),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFE2E8F0), height: 1),
                  const SizedBox(height: 12),

                  // ── POPULAR SERVICES CAROUSEL (ZERO VERTICAL OVERFLOW) ──
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr.popularSearches,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _suggestionChips.length,
                      separatorBuilder: (_, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final chip = _suggestionChips[index];
                        final isKn = currentLang == AppLanguage.kannada;
                        final isHi = currentLang == AppLanguage.hindi;
                        final label = isKn
                            ? chip['kn']!
                            : (isHi ? chip['hi']! : chip['en']!);

                        return GestureDetector(
                          onTap: () => _onSuggestionTap(chip['canonical']!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(chip['icon']!, style: const TextStyle(fontSize: 12)),
                                const SizedBox(width: 5),
                                Text(
                                  label,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // ── RECENT SEARCHES CAROUSEL ──
                  if (_history.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr.recentSearches,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                            letterSpacing: 0.4,
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await SearchHistoryService.instance.clearHistory();
                            _loadHistory();
                          },
                          child: Text(
                            tr.clearAll,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _history.length,
                        separatorBuilder: (_, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final term = _history[index];
                          return Container(
                            padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(20),
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
                                        color: Color(0xFF16A34A),
                                      ),
                                      const SizedBox(width: 4),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 130),
                                        child: Text(
                                          term,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF15803D),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 5),
                                GestureDetector(
                                  onTap: () async {
                                    await SearchHistoryService.instance.removeTerm(term);
                                    _loadHistory();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFDCFCE7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 9,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final double baseHeight = 8.0 + (i % 3) * 5.0;
          final double dynamicHeight =
              (baseHeight + (soundLevel * 3.0 * (i % 2 == 0 ? 1.2 : 0.8))).clamp(6.0, 26.0);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: 4.0,
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
