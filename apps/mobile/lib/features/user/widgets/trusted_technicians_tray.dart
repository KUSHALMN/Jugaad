import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/haptic_feedback_utils.dart';

/// "Mane Technician" (ನನ್ನ ಮೆಕ್ಯಾನಿಕ್) - 1-Tap Quick-Dial Rebooking Tray.
/// In Indian households, familiar workers build immense long-term trust.
class TrustedTechniciansTray extends ConsumerWidget {
  const TrustedTechniciansTray({super.key});

  static final List<Map<String, dynamic>> _trustedWorkers = [
    {
      'id': 'w_ramesh_plumber',
      'name': 'Ramesh K.',
      'trade': 'Plumber / ಪ್ಲಂಬರ್',
      'rating': 4.9,
      'jobs': 142,
      'avatarColor': const Color(0xFF2563EB),
      'initial': 'R',
      'lastServiced': 'Kitchen leak fixed 2 wks ago',
      'query': 'Plumber',
    },
    {
      'id': 'w_suresh_electrician',
      'name': 'Suresh V.',
      'trade': 'Electrician / ಎಲೆಕ್ಟ್ರಿಷಿಯನ್',
      'rating': 4.95,
      'jobs': 210,
      'avatarColor': const Color(0xFFEA580C),
      'initial': 'S',
      'lastServiced': 'MCB repair last month',
      'query': 'Electrician',
    },
    {
      'id': 'w_manju_ac',
      'name': 'Manjunath',
      'trade': 'AC Service / ಎಸಿ ಸರ್ವಿಸ್',
      'rating': 4.88,
      'jobs': 98,
      'avatarColor': const Color(0xFF0D9488),
      'initial': 'M',
      'lastServiced': 'Summer coil cleaning',
      'query': 'AC Service',
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(translationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      size: 14,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr.maneTechnicianTitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '1-Tap Rebook',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal Carousel
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _trustedWorkers.length,
            itemBuilder: (context, index) {
              final worker = _trustedWorkers[index];
              return Container(
                width: 250,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: worker['avatarColor'] as Color,
                          child: Text(
                            worker['initial'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
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
                                      worker['name'] as String,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF2563EB)),
                                ],
                              ),
                              Text(
                                worker['trade'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 12, color: Color(0xFFD97706)),
                              const SizedBox(width: 2),
                              Text(
                                '${worker['rating']}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '🏠 ${worker['lastServiced']}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D9488),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          AppHaptics.mediumSnap();
                          final query = Uri.encodeComponent(worker['query'] as String);
                          context.push('/user/worker-search?service=$query');
                        },
                        icon: const Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                        label: Text(
                          'Book Again • 15m Visit',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: EdgeInsets.zero,
                          elevation: 0,
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
