import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full-screen Tactical Incoming Request Card designed for two-wheeler motorcycle drivers.
/// High contrast, sunlight-readable, with a full-width 64px Slide-to-Accept gesture
/// that prevents accidental pocket taps.
class TacticalIncomingRequestCard extends StatefulWidget {
  final String jobId;
  final String skill;
  final double netPayout;
  final String customerArea;
  final double distanceKm;
  final int etaMinutes;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const TacticalIncomingRequestCard({
    super.key,
    required this.jobId,
    required this.skill,
    required this.netPayout,
    required this.customerArea,
    this.distanceKm = 1.8,
    this.etaMinutes = 7,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<TacticalIncomingRequestCard> createState() => _TacticalIncomingRequestCardState();
}

class _TacticalIncomingRequestCardState extends State<TacticalIncomingRequestCard>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _isAccepted = false;

  @override
  Widget build(BuildContext context) {
    const double slideBarHeight = 64.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF334155), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category Pill & Soundwave indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flash_on_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      widget.skill.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onDecline,
                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Guaranteed Net Earnings Hero Badge
          Text(
            'GUARANTEED NET EARNINGS',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF94A3B8),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹${widget.netPayout.toInt()}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF34D399),
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Direct to UPI',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6EE7B7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Location & Travel Distance Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF60A5FA), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.customerArea,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${widget.distanceKm} km away • ~${widget.etaMinutes} mins drive',
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
          ),
          const SizedBox(height: 26),

          // Full-Width 64px Slide-to-Accept Gesture
          LayoutBuilder(
            builder: (context, constraints) {
              final double trackWidth = constraints.maxWidth;
              final double maxSlide = trackWidth - slideBarHeight - 8.0;

              return Container(
                height: slideBarHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Slide hint text
                    Center(
                      child: Text(
                        _isAccepted ? 'ACCEPTED! STARTING GPS...' : 'SLIDE TO ACCEPT  ➔',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _isAccepted ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    // Draggable Knob
                    Positioned(
                      left: 4.0 + _dragPosition,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          if (_isAccepted) return;
                          setState(() {
                            _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxSlide);
                          });
                        },
                        onHorizontalDragEnd: (details) {
                          if (_isAccepted) return;
                          if (_dragPosition >= maxSlide * 0.75) {
                            HapticFeedback.heavyImpact();
                            setState(() {
                              _dragPosition = maxSlide;
                              _isAccepted = true;
                            });
                            Future.delayed(const Duration(milliseconds: 300), () {
                              widget.onAccept();
                            });
                          } else {
                            setState(() {
                              _dragPosition = 0.0;
                            });
                          }
                        },
                        child: Container(
                          width: slideBarHeight - 8.0,
                          height: slideBarHeight - 8.0,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x4410B981),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
