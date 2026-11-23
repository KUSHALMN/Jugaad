import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/voice_briefing_service.dart';

/// Interactive Voice Briefing Pill ("Keli Thiliri" / "Sunke Samjho").
///
/// Prominently displays beside invoices and material breakdowns, allowing
/// homeowners to hear verified totals and anti-fraud warnings in Kannada, Hindi, or English.
class VoiceBriefingPill extends ConsumerWidget {
  final int totalAmount;
  final bool hasVerifiedParts;
  final bool showCaptionBanner;
  final bool isAnimated;

  const VoiceBriefingPill({
    super.key,
    required this.totalAmount,
    this.hasVerifiedParts = true,
    this.showCaptionBanner = true,
    this.isAnimated = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(localeProvider);
    final service = VoiceBriefingService.instance;

    String buttonLabel;
    switch (language) {
      case AppLanguage.kannada:
        buttonLabel = 'ಕನ್ನಡದಲ್ಲಿ ಕೇಳಿ';
        break;
      case AppLanguage.hindi:
        buttonLabel = 'ऑडियो में सुनें';
        break;
      case AppLanguage.english:
        buttonLabel = 'Listen to Bill';
        break;
    }

    return ValueListenableBuilder<bool>(
      valueListenable: service.isPlaying,
      builder: (context, isPlaying, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                if (isPlaying) {
                  service.stopBriefing();
                } else {
                  service.playBriefing(
                    amount: totalAmount,
                    language: language,
                    hasVerifiedParts: hasVerifiedParts,
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isPlaying ? const Color(0xFFDCFCE7) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isPlaying ? const Color(0xFF16A34A) : const Color(0xFFBBF7D0),
                    width: isPlaying ? 1.5 : 1.0,
                  ),
                  boxShadow: isPlaying
                      ? [
                          BoxShadow(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPlaying ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                      color: const Color(0xFF15803D),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      buttonLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                    if (isPlaying) ...[
                      const SizedBox(width: 8),
                      // Animated equalizer soundwaves
                      RepaintBoundary(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(3, (i) {
                            final bar = Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              width: 3,
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                            if (!isAnimated) return bar;
                            return bar
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .scaleY(
                                  begin: 0.3,
                                  end: 1.0,
                                  duration: Duration(milliseconds: 300 + (i * 120)),
                                );
                          }),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Live Closed Caption Subtitle Banner
            if (showCaptionBanner)
              ValueListenableBuilder<String>(
                valueListenable: service.activeCaption,
                builder: (context, caption, _) {
                  if (!isPlaying || caption.isEmpty) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🗣️', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            caption,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFF8FAFC),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
