import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/services/demand_hotspot_service.dart';

/// Tactical Earnings Radar & Demand Hotspot Card for Worker Dashboard.
///
/// Visualizes live neighborhood booking spikes and active surge bonuses
/// (e.g., "+₹50 Weekend Rain Bonus in Gokulam") with 1-tap scooter navigation.
class DemandHotspotRadarCard extends StatefulWidget {
  final double currentLat;
  final double currentLng;
  final String city;
  final bool isAnimated;

  const DemandHotspotRadarCard({
    super.key,
    required this.currentLat,
    required this.currentLng,
    this.city = 'Mysuru',
    this.isAnimated = true,
  });

  @override
  State<DemandHotspotRadarCard> createState() => _DemandHotspotRadarCardState();
}

class _DemandHotspotRadarCardState extends State<DemandHotspotRadarCard> {
  int _selectedZoneIndex = 0;

  @override
  Widget build(BuildContext context) {
    final hotspots = DemandHotspotService.instance.getHotspots(city: widget.city);
    if (hotspots.isEmpty) return const SizedBox.shrink();

    final activeZone = hotspots[_selectedZoneIndex.clamp(0, hotspots.length - 1)];
    final distanceText = activeZone.formattedDistance(widget.currentLat, widget.currentLng);
    final driveMinutes = activeZone.estimatedScooterMinutes(widget.currentLat, widget.currentLng);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── RADAR HEADER WITH PULSING LIVE BEACON ──
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.isAnimated)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.6, 1.6), duration: 1200.ms)
                        .fadeOut(duration: 1200.ms),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Demand Radar',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'High-booking clusters across ${widget.city}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    Text(
                      'Surge Active',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── HOTSPOT ZONE TABS / CHIPS ──
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: hotspots.length,
              separatorBuilder: (context, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final zone = hotspots[index];
                final isSelected = index == _selectedZoneIndex;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedZoneIndex = index;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF97316) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(zone.demandTier.icon, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 5),
                        Text(
                          zone.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // ── ACTIVE ZONE DETAIL CARD ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF7ED), Color(0xFFFFFBEB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        activeZone.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (activeZone.surgeBonus > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '+₹${activeZone.surgeBonus} Bonus',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Demand summary tagline
                Text(
                  activeZone.summaryTagline,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFC2410C),
                  ),
                ),
                const SizedBox(height: 10),

                // Dominant trade + Scooter ETA pill
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.handyman_rounded, color: Color(0xFF475569), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            activeZone.dominantTrade,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.two_wheeler_rounded, color: Color(0xFF15803D), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '$driveMinutes mins ($distanceText)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── 1-TAP TWO-WHEELER NAVIGATION CTA ──
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      DemandHotspotService.instance.navigateToHotspot(activeZone);
                    },
                    icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 15),
                    label: Text(
                      'Navigate to ${activeZone.name}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
