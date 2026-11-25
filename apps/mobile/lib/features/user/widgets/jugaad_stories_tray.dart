import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

class StoryDiagnosisItem {
  final String id;
  final String titleLine1;
  final String titleLine2;
  final String category;
  final String emoji;
  final IconData icon;
  final String duration;
  final String videoAssetPath;
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
    required this.videoAssetPath,
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
      videoAssetPath: 'assets/videos/ac.mp4',
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
      videoAssetPath: 'assets/videos/fan.mp4',
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
      videoAssetPath: 'assets/videos/plumber.mp4',
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
      videoAssetPath: 'assets/videos/mcb.mp4',
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
      videoAssetPath: 'assets/videos/gyser.mp4',
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

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close video diagnosis',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, anim1, anim2) => _FullScreenVideoDiagnosisPlayer(item: item),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
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

class _FullScreenVideoDiagnosisPlayer extends StatefulWidget {
  final StoryDiagnosisItem item;

  const _FullScreenVideoDiagnosisPlayer({required this.item});

  @override
  State<_FullScreenVideoDiagnosisPlayer> createState() => _FullScreenVideoDiagnosisPlayerState();
}

class _FullScreenVideoDiagnosisPlayerState extends State<_FullScreenVideoDiagnosisPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.asset(widget.item.videoAssetPath);
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  void _toggleMute() {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isMuted = !_isMuted;
      controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-Screen Background Blur + Ambient Category Glow
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.1,
                  colors: [
                    item.gradientStart.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),
          ),

          // Centered Full-Height Reel Frame (Full Screen on Mobile, Sleek Portrait Reel on Desktop)
          SafeArea(
            child: Center(
              child: Container(
                width: isWide ? 440 : size.width,
                height: isWide ? size.height * 0.90 : size.height,
                decoration: BoxDecoration(
                  color: const Color(0xFF020617),
                  borderRadius: BorderRadius.circular(isWide ? 28 : 0),
                  border: isWide
                      ? Border.all(color: Colors.white.withValues(alpha: 0.16), width: 1.2)
                      : null,
                  boxShadow: isWide
                      ? [
                          BoxShadow(
                            color: item.gradientStart.withValues(alpha: 0.35),
                            blurRadius: 48,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.65),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isWide ? 28 : 0),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Video Canvas (fills frame edge-to-edge cleanly)
                      if (_hasError)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_circle_outline_rounded, color: item.gradientStart, size: 56),
                              const SizedBox(height: 12),
                              Text(
                                item.title,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (!_isInitialized || _controller == null)
                        Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: item.gradientStart,
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _togglePlayPause,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(
                              width: _controller!.value.size.width > 0
                                  ? _controller!.value.size.width
                                  : 1080,
                              height: _controller!.value.size.height > 0
                                  ? _controller!.value.size.height
                                  : 1920,
                              child: VideoPlayer(_controller!),
                            ),
                          ),
                        ),

                      // Top & Bottom Gradient Scrims for Contrast
                      IgnorePointer(
                        child: Column(
                          children: [
                            Container(
                              height: 120,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.72),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              height: 170,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.85),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Center Pause Play Button Overlay
                      if (_isInitialized && _controller != null && !_controller!.value.isPlaying)
                        Center(
                          child: GestureDetector(
                            onTap: _togglePlayPause,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                              ),
                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 42),
                            ),
                          ),
                        ),

                      // Floating Glassmorphic Top Bar
                      Positioned(
                        top: 14,
                        left: 14,
                        right: 14,
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [item.gradientStart, item.gradientEnd],
                                ),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(item.icon, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item.title,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.duration,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    item.category,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _toggleMute,
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                                ),
                                child: Icon(
                                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                                ),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Floating Bottom Scrubber + Book Verified Technician CTA
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 18,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isInitialized && _controller != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: VideoProgressIndicator(
                                    _controller!,
                                    allowScrubbing: true,
                                    padding: EdgeInsets.zero,
                                    colors: VideoProgressColors(
                                      playedColor: item.gradientStart,
                                      bufferedColor: Colors.white.withValues(alpha: 0.35),
                                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                                    ),
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  Navigator.pop(context);
                                  context.push('/user/worker-search?service=${Uri.encodeComponent(item.category)}');
                                },
                                icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                                label: Text(
                                  'Book Verified Technician (₹${item.estimatedFare.toInt()})',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: item.gradientStart,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 4,
                                  shadowColor: item.gradientStart.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
