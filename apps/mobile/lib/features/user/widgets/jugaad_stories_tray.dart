import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class StoryDiagnosisItem {
  final String id;
  final String titleLine1;
  final String titleLine2;
  final String category;
  final String emoji;
  final IconData icon;
  final String duration;
  final Color cardBg;
  final Color borderColor;
  final Color iconColor;
  final Color buttonBg;
  final Color buttonIconColor;
  final Color gradientStart;
  final Color gradientEnd;
  final List<String> steps;
  final double estimatedFare;

  const StoryDiagnosisItem({
    required this.id,
    required this.titleLine1,
    required this.titleLine2,
    required this.category,
    required this.emoji,
    required this.icon,
    required this.duration,
    required this.cardBg,
    required this.borderColor,
    required this.iconColor,
    required this.buttonBg,
    required this.buttonIconColor,
    required this.gradientStart,
    required this.gradientEnd,
    required this.steps,
    required this.estimatedFare,
  });

  String get title => '$titleLine1 $titleLine2';
}

class JugaadStoriesTray extends StatelessWidget {
  const JugaadStoriesTray({super.key});

  static const List<StoryDiagnosisItem> stories = [
    StoryDiagnosisItem(
      id: 'ac_leak',
      titleLine1: 'AC',
      titleLine2: 'Leaking Issue',
      category: 'AC Repair / ಎಸಿ ರಿಪೇರ್',
      emoji: '❄️',
      icon: Icons.ac_unit_rounded,
      duration: '30s',
      cardBg: Color(0xFFF0F9FF),
      borderColor: Color(0xFFBAE6FD),
      iconColor: Color(0xFF0284C7),
      buttonBg: Color(0xFFBAE6FD),
      buttonIconColor: Color(0xFF0284C7),
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
      titleLine1: 'Fan Humming',
      titleLine2: 'Noise',
      category: 'Electrician / ಇಲೆಕ್ಟ್ರಿಷಿಯನ್',
      emoji: '⚡',
      icon: Icons.bolt_rounded,
      duration: '25s',
      cardBg: Color(0xFFFFFBEB),
      borderColor: Color(0xFFFDE68A),
      iconColor: Color(0xFFD97706),
      buttonBg: Color(0xFFFDE68A),
      buttonIconColor: Color(0xFFD97706),
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
      titleLine1: 'Low Tap',
      titleLine2: 'Water Flow',
      category: 'Plumber / ಪ್ಲಂಬರ್',
      emoji: '💧',
      icon: Icons.water_drop_rounded,
      duration: '20s',
      cardBg: Color(0xFFEFF6FF),
      borderColor: Color(0xFFBFDBFE),
      iconColor: Color(0xFF2563EB),
      buttonBg: Color(0xFFBFDBFE),
      buttonIconColor: Color(0xFF2563EB),
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
      titleLine1: 'MCB',
      titleLine2: 'Tripping',
      category: 'Electrician / ಇಲೆಕ್ಟ್ರಿಷಿಯನ್',
      emoji: '🔌',
      icon: Icons.power_rounded,
      duration: '35s',
      cardBg: Color(0xFFFFF1F2),
      borderColor: Color(0xFFFECDD3),
      iconColor: Color(0xFFE11D48),
      buttonBg: Color(0xFFFECDD3),
      buttonIconColor: Color(0xFFE11D48),
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
      titleLine1: 'Geyser',
      titleLine2: 'Not Heating',
      category: 'Plumber / ಪ್ಲಂಬರ್',
      emoji: '🚿',
      icon: Icons.shower_rounded,
      duration: '30s',
      cardBg: Color(0xFFF0FDF4),
      borderColor: Color(0xFFBBF7D0),
      iconColor: Color(0xFF16A34A),
      buttonBg: Color(0xFFBBF7D0),
      buttonIconColor: Color(0xFF16A34A),
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

  void _showVideoRecordingSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '30s Video Diagnosis',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF38BDF8)),
                                ),
                                child: const Text(
                                  'AI AUDIO/VIDEO',
                                  style: TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Capture the issue in 30 seconds for instant quote',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF818CF8), size: 28),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Point camera at the leaking pipe, sparking wire, or fan',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE11D48)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF43F5E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'MAX 30s',
                                style: TextStyle(
                                  color: Color(0xFFF43F5E),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Video uploaded! Diagnosing issue via AI in 15 seconds...'),
                              backgroundColor: Color(0xFF4F46E5),
                            ),
                          );
                        },
                        icon: const Icon(Icons.file_upload_outlined, color: Colors.white, size: 18),
                        label: Text(
                          'Upload Video',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF475569)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Starting 30s camera recording...'),
                              backgroundColor: Color(0xFF16A34A),
                            ),
                          );
                        },
                        icon: const Icon(Icons.fiber_manual_record_rounded, color: Colors.white, size: 20),
                        label: Text(
                          'Record 30s Video',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFF0F5FF),
              Color(0xFFF8FAFD),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Section: Camera icon, Title, GUIDES pill, Subtitle, and 30s clapperboard badge
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showVideoRecordingSheet(context),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '30s Video Diagnosis',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.menu_book_rounded,
                                  size: 10,
                                  color: Color(0xFF15803D),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'GUIDES',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF15803D),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Record a short video (30 seconds) and get quick help to identify the issue.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Visual Clapperboard badge with 30s duration
                GestureDetector(
                  onTap: () => _showVideoRecordingSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '30s',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF1E40AF),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Horizontal Issue Cards Row
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: stories.length,
                separatorBuilder: (context, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final story = stories[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _showDiagnosisModal(context, story),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: story.cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: story.borderColor, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: story.borderColor.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Circular icon container
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: story.iconColor.withValues(alpha: 0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                story.icon,
                                color: story.iconColor,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 10),
                            // 2-line title
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  story.titleLine1,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                    height: 1.15,
                                  ),
                                ),
                                Text(
                                  story.titleLine2,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            // Circular chevron button
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: story.buttonBg,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: story.buttonIconColor,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
