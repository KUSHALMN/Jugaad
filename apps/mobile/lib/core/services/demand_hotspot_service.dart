import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/high_demand_zone.dart';

/// Live Hotspot and Demand Surge Engine for Jugaad Gig Workers.
///
/// Directs field technicians towards high-request neighborhoods to eliminate
/// idle fuel waste and maximize hourly earnings.
class DemandHotspotService {
  DemandHotspotService._internal();
  static final DemandHotspotService instance = DemandHotspotService._internal();

  /// Curated active demand zones across Mysuru and Bengaluru
  static const List<HighDemandZone> _defaultHotspots = [
    // ── MYSURU HOTSPOTS ──
    HighDemandZone(
      id: 'mysore_vijayanagar_kuvempunagar',
      name: 'Vijayanagar & Kuvempunagar',
      city: 'Mysuru',
      latitude: 12.3374,
      longitude: 76.6111,
      activeRequestsCount: 8,
      demandTier: DemandTier.veryHigh,
      surgeBonus: 75,
      surgeReason: 'High Outage Volume',
      dominantTrade: 'Electrician & AC Service',
    ),
    HighDemandZone(
      id: 'mysore_gokulam',
      name: 'Gokulam Center',
      city: 'Mysuru',
      latitude: 12.3308,
      longitude: 76.6267,
      activeRequestsCount: 6,
      demandTier: DemandTier.high,
      surgeBonus: 50,
      surgeReason: 'Weekend Rain Bonus',
      dominantTrade: 'Plumbing & RO Purifier',
    ),
    HighDemandZone(
      id: 'mysore_saraswathipuram',
      name: 'Saraswathipuram',
      city: 'Mysuru',
      latitude: 12.3051,
      longitude: 76.6351,
      activeRequestsCount: 5,
      demandTier: DemandTier.high,
      surgeBonus: 30,
      surgeReason: 'Evening Rush',
      dominantTrade: 'Carpentry & Switchboard Repair',
    ),
    HighDemandZone(
      id: 'mysore_hebbal_industrial',
      name: 'Hebbal Industrial Zone',
      city: 'Mysuru',
      latitude: 12.3562,
      longitude: 76.6047,
      activeRequestsCount: 3,
      demandTier: DemandTier.moderate,
      surgeBonus: 0,
      dominantTrade: 'Heavy Appliance & Wiring',
    ),

    // ── BENGALURU HOTSPOTS ──
    HighDemandZone(
      id: 'blr_koramangala_hsr',
      name: 'Koramangala & HSR Layout',
      city: 'Bengaluru',
      latitude: 12.9352,
      longitude: 77.6245,
      activeRequestsCount: 12,
      demandTier: DemandTier.veryHigh,
      surgeBonus: 100,
      surgeReason: 'Peak Weekend Rush',
      dominantTrade: 'AC Service & Deep Cleaning',
    ),
    HighDemandZone(
      id: 'blr_indiranagar',
      name: 'Indiranagar 100ft Rd',
      city: 'Bengaluru',
      latitude: 12.9784,
      longitude: 77.6408,
      activeRequestsCount: 9,
      demandTier: DemandTier.veryHigh,
      surgeBonus: 80,
      surgeReason: 'Rain Surge Active',
      dominantTrade: 'Electrician & Plumbing',
    ),
  ];

  /// Get active hotspots filtered by city
  List<HighDemandZone> getHotspots({String? city}) {
    if (city == null || city.isEmpty) {
      return List<HighDemandZone>.from(_defaultHotspots);
    }
    final filtered = _defaultHotspots
        .where((z) => z.city.toLowerCase() == city.toLowerCase())
        .toList();
    return filtered.isNotEmpty ? filtered : List<HighDemandZone>.from(_defaultHotspots);
  }

  /// Find the geographically closest active hotspot to the worker
  HighDemandZone? getNearestHotspot(double currentLat, double currentLng, {String? city}) {
    final zones = getHotspots(city: city);
    if (zones.isEmpty) return null;

    if (currentLat == 0.0 && currentLng == 0.0) return zones.first;

    HighDemandZone? closestZone;
    double minDistance = double.infinity;

    for (final zone in zones) {
      final dist = zone.distanceInKm(currentLat, currentLng);
      if (dist < minDistance) {
        minDistance = dist;
        closestZone = zone;
      }
    }
    return closestZone;
  }

  /// Launch turn-by-turn navigation directly to the hotspot coordinates
  Future<bool> navigateToHotspot(HighDemandZone zone) async {
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${zone.latitude},${zone.longitude}&travelmode=two_wheeler',
    );
    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        return await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[HOTSPOT-SERVICE] Failed to launch navigation: $e');
    }
    return false;
  }
}
