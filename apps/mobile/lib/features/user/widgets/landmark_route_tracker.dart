import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/utils/haptic_feedback_utils.dart';

/// Landmark-based Route Milestones & Vehicle Pill.
/// Replaces generic map pins with familiar local Indian neighborhood cues.
class LandmarkRouteTracker extends StatefulWidget {
  final String workerName;
  final String? vehicleInfo;
  final int currentStep; // 0: Departed, 1: Landmark transit, 2: 1-km radar, 3: Arrived at gate
  final String landmarkText;
  final int etaMinutes;

  const LandmarkRouteTracker({
    super.key,
    required this.workerName,
    this.vehicleInfo,
    this.currentStep = 1,
    this.landmarkText = 'Near Saraswathipuram Fire Station',
    this.etaMinutes = 6,
  });

  @override
  State<LandmarkRouteTracker> createState() => _LandmarkRouteTrackerState();
}

class _LandmarkRouteTrackerState extends State<LandmarkRouteTracker> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicleInfo ?? '🛵 Hero Splendor (KA-09-EA-4821)';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Summary Header Bar
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              AppHaptics.lightTick();
              setState(() => _isExpanded = !_isExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.navigation_rounded,
                      color: Color(0xFF2563EB),
                      size: 18,
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
                              'Doorstep Live Radar',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
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
                              child: Text(
                                'ETA ${widget.etaMinutes}m',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF166534),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          widget.landmarkText,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            // Vehicle Info Pill
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Text(
                      vehicle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Verified ID',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4-Step Landmark Timeline
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                children: [
                  _buildMilestoneStep(
                    index: 0,
                    title: 'Departed Workshop',
                    subtitle: 'Kuvempunagar Hub',
                    isActive: widget.currentStep >= 0,
                    isDone: widget.currentStep > 0,
                  ),
                  _buildMilestoneStep(
                    index: 1,
                    title: 'Passing Landmark',
                    subtitle: widget.landmarkText,
                    isActive: widget.currentStep >= 1,
                    isDone: widget.currentStep > 1,
                  ),
                  _buildMilestoneStep(
                    index: 2,
                    title: '1.2 km away (~4 mins)',
                    subtitle: 'Approaching your cross road',
                    isActive: widget.currentStep >= 2,
                    isDone: widget.currentStep > 2,
                  ),
                  _buildMilestoneStep(
                    index: 3,
                    title: 'At Society Gate',
                    subtitle: 'Ready for 4-digit Doorstep PIN',
                    isActive: widget.currentStep >= 3,
                    isDone: widget.currentStep > 3,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMilestoneStep({
    required int index,
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isDone,
    bool isLast = false,
  }) {
    final dotColor = isDone
        ? const Color(0xFF10B981)
        : isActive
            ? const Color(0xFF2563EB)
            : const Color(0xFFCBD5E1);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step dot & connecting vertical line
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: dotColor.withValues(alpha: 0.4),
                            blurRadius: 6,
                          )
                        ]
                      : null,
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 8, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDone ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          // Title & Subtitle
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
