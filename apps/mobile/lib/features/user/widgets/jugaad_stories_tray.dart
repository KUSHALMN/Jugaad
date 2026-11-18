import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class StoryDiagnosisItem {
  final String id;
  final String title;
  final String category;
  final String emoji;
  final String duration;
  final Color gradientStart;
  final Color gradientEnd;
  final List<String> steps;
  final double estimatedFare;

  const StoryDiagnosisItem({
    required this.id,
    required this.title,
    required this.category,
    required this.emoji,
    required this.duration,
    required this.gradientStart,
    required this.gradientEnd,
    required this.steps,
    required this.estimatedFare,
  });
}

class JugaadStoriesTray extends StatelessWidget {
  const JugaadStoriesTray({super.key});

  static const List<StoryDiagnosisItem> stories = [
    StoryDiagnosisItem(
      id: 'ac_leak',
      title: 'AC Leaking Water?',
      category: 'AC Repair / ಎಸಿ ರಿಪೇರ್',
      emoji: '❄️',
      duration: '30s',
      gradientStart: Color(0xFF0284C7),
      gradientEnd: Color(0xFF0EA5E9),
      estimatedFare: 299,
      steps: [
        'Turn off the AC indoor unit immediately to prevent electrical shorting.',
        'Inspect the outside drainage pipe; 80% of leaks are caused by dust sludge clogs.',
        'If water drips from the front vent, your cooling coil has ice build-up.',
      ],
    ),
    StoryDiagnosisItem(
      id: 'fan_hum',
      title: 'Fan Humming?',
      category: 'Electrician / ಇಲೆಕ್ಟ್ರಿಷಿಯನ್',
      emoji: '⚡',
      duration: '25s',
      gradientStart: Color(0xFFEA580C),
      gradientEnd: Color(0xFFF97316),
      estimatedFare: 149,
      steps: [
        'If the fan hums but blades do not rotate, the starting capacitor is blown.',
        'Never push the blade with a stick while the switch is ON.',
        'Capacitor replacement takes 15 minutes by our verified electrician.',
      ],
    ),
    StoryDiagnosisItem(
      id: 'tap_low',
      title: 'Low Tap Water?',
      category: 'Plumber / ಪ್ಲಂಬರ್',
      emoji: '💧',
      duration: '20s',
      gradientStart: Color(0xFF2563EB),
      gradientEnd: Color(0xFF3B82F6),
      estimatedFare: 120,
      steps: [
        'Unscrew the small mesh filter (aerator) at the tip of the faucet.',
        'Soak it in vinegar or tap water to clear hard water salt deposits.',
        'If pressure is low across all taps, pipe line air-lock needs clearance.',
      ],
    ),
    StoryDiagnosisItem(
      id: 'mcb_trip',
      title: 'MCB Tripping?',
      category: 'Electrician / ಇಲೆಕ್ಟ್ರಿಷಿಯನ್',
      emoji: '🔌',
      duration: '35s',
      gradientStart: Color(0xFFE11D48),
      gradientEnd: Color(0xFFF43F5E),
      estimatedFare: 199,
      steps: [
        'Unplug all heavy appliances (Geyser, AC, Microwave) connected to that circuit.',
        'Push the MCB lever firmly all the way DOWN, then flip it all the way UP.',
        'If it trips instantly with no appliances on, you have a concealed wire short.',
      ],
    ),
    StoryDiagnosisItem(
      id: 'geyser_cold',
      title: 'Geyser Cold Water?',
      category: 'Plumber / ಪ್ಲಂಬರ್',
      emoji: '🚿',
      duration: '30s',
      gradientStart: Color(0xFF0D9488),
      gradientEnd: Color(0xFF14B8A6),
      estimatedFare: 249,
      steps: [
        'Check if the reset button on the thermostat bottom panel has popped out.',
        'Inspect the power plug for heating or burning marks.',
        'Heating element scaling is common with hard water; requires technician cleaning.',
      ],
    ),
  ];

  void _showDiagnosisModal(BuildContext context, StoryDiagnosisItem item) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 32,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [item.gradientStart, item.gradientEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(item.emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.duration,
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.category,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF38BDF8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '30-SECOND QUICK DIAGNOSIS GUIDE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            ...item.steps.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final text = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E293B),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$idx',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFFE2E8F0),
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚡ 15-Min Doorstep Guarantee • Insured up to ₹25,000',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF6EE7B7),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(ctx);
                  context.push('/user/worker-search?service=${Uri.encodeComponent(item.category)}');
                },
                icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                label: Text(
                  'Book Verified Technician (₹${item.estimatedFare.toInt()})',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: item.gradientStart,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '30s Video Diagnosis',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'GUIDES',
                  style: TextStyle(color: Color(0xFF15803D), fontSize: 9.5, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: stories.length,
            separatorBuilder: (context, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final story = stories[index];
              return GestureDetector(
                onTap: () => _showDiagnosisModal(context, story),
                child: Column(
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [story.gradientStart, story.gradientEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: story.gradientStart.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          story.emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 74,
                      child: Text(
                        story.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF334155),
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
    );
  }
}
