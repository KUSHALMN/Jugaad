import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SymptomCardData {
  final String id;
  final String title;
  final String titleKannada;
  final String startingPrice;
  final IconData icon;
  final Color accentColor;
  final Color bgGradientStart;
  final Color bgGradientEnd;
  final String skillTarget;

  const SymptomCardData({
    required this.id,
    required this.title,
    required this.titleKannada,
    required this.startingPrice,
    required this.icon,
    required this.accentColor,
    required this.bgGradientStart,
    required this.bgGradientEnd,
    required this.skillTarget,
  });
}

/// Urban Company-grade Symptom-First Discovery Carousel.
/// Anchors users around specific trade repair problems rather than generic trade titles.
class SymptomDiscoveryCarousel extends StatelessWidget {
  final Function(SymptomCardData symptom)? onSymptomTap;

  const SymptomDiscoveryCarousel({
    super.key,
    this.onSymptomTap,
  });

  static const List<SymptomCardData> _symptoms = [
    SymptomCardData(
      id: 'fan_noise',
      title: 'Ceiling fan noisy?',
      titleKannada: 'ಫ್ಯಾನ್ ಶಬ್ದ ಮಾಡುತ್ತಿದೆಯೇ?',
      startingPrice: '₹149',
      icon: Icons.toys_rounded,
      accentColor: Color(0xFF2563EB),
      bgGradientStart: Color(0xFFEFF6FF),
      bgGradientEnd: Color(0xFFDBEAFE),
      skillTarget: 'electrician',
    ),
    SymptomCardData(
      id: 'tap_leak',
      title: 'Water tap leaking?',
      titleKannada: 'ನಲ್ಲಿ ಸೋರುತ್ತಿದೆಯೇ?',
      startingPrice: '₹99',
      icon: Icons.water_drop_rounded,
      accentColor: Color(0xFF0284C7),
      bgGradientStart: Color(0xFFF0F9FF),
      bgGradientEnd: Color(0xFFE0F2FE),
      skillTarget: 'plumber',
    ),
    SymptomCardData(
      id: 'mcb_trip',
      title: 'Main MCB tripped?',
      titleKannada: 'ಎಂಸಿಬಿ ಟ್ರಿಪ್ ಆಗಿದೆಯೇ?',
      startingPrice: '₹199',
      icon: Icons.electric_bolt_rounded,
      accentColor: Color(0xFFD97706),
      bgGradientStart: Color(0xFFFFFBEB),
      bgGradientEnd: Color(0xFFFEF3C7),
      skillTarget: 'electrician',
    ),
    SymptomCardData(
      id: 'ac_cooling',
      title: 'AC not cooling?',
      titleKannada: 'ಎಸಿ ತಣ್ಣಗಾಗುತ್ತಿಲ್ಲವೇ?',
      startingPrice: '₹249',
      icon: Icons.ac_unit_rounded,
      accentColor: Color(0xFF0D9488),
      bgGradientStart: Color(0xFFF0FDFA),
      bgGradientEnd: Color(0xFFCCFBF1),
      skillTarget: 'ac_service',
    ),
    SymptomCardData(
      id: 'lap_slow',
      title: 'Laptop overheating?',
      titleKannada: 'ಲ್ಯಾಪ್ಟಾಪ್ ಬಿಸಿಯಾಗುತ್ತಿದೆಯೇ?',
      startingPrice: '₹299',
      icon: Icons.laptop_mac_rounded,
      accentColor: Color(0xFF7C3AED),
      bgGradientStart: Color(0xFFF5F3FF),
      bgGradientEnd: Color(0xFFEDE9FE),
      skillTarget: 'laptop_repair',
    ),
    SymptomCardData(
      id: 'door_lock',
      title: 'Door lock jammed?',
      titleKannada: 'ಬಾಗಿಲಿನ ಲಾಕ್ ಜಾಮ್ ಆಗಿದೆಯೇ?',
      startingPrice: '₹179',
      icon: Icons.lock_open_rounded,
      accentColor: Color(0xFFEA580C),
      bgGradientStart: Color(0xFFFFF7ED),
      bgGradientEnd: Color(0xFFFFEDD5),
      skillTarget: 'carpenter',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.flash_on_rounded, color: Color(0xFF2563EB), size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'What needs fixing?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Text(
                'Top Solutions',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            scrollDirection: Axis.horizontal,
            itemCount: _symptoms.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = _symptoms[index];
              return InkWell(
                onTap: () => onSymptomTap?.call(item),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 170,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [item.bgGradientStart, item.bgGradientEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: item.accentColor.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: item.accentColor.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(item.icon, color: item.accentColor, size: 18),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              item.startingPrice,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: item.accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            item.titleKannada,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSansKannada(
                              fontSize: 10,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
