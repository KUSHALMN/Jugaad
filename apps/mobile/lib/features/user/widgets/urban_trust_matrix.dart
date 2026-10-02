import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UrbanTrustMatrix extends StatelessWidget {
  const UrbanTrustMatrix({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    Icons.verified_rounded,
                    color: Color(0xFF2563EB),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The Jugaad Guarantee',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Urban Company caliber quality standards',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),

            // 2x2 Grid of Trust Features
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTrustItem(
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFF16A34A),
                    bgColor: const Color(0xFFF0FDF4),
                    title: 'Verified Experts',
                    description: 'Background checked & skill certified pros',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildTrustItem(
                    icon: Icons.speed_rounded,
                    iconColor: const Color(0xFFEA580C),
                    bgColor: const Color(0xFFFFF7ED),
                    title: '15–30 Min Arrival',
                    description: 'Live GPS tracking right to your doorstep',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTrustItem(
                    icon: Icons.currency_rupee_rounded,
                    iconColor: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                    title: 'Upfront Pricing',
                    description: 'Fixed transparent rate card, zero surprises',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildTrustItem(
                    icon: Icons.workspace_premium_rounded,
                    iconColor: const Color(0xFF9333EA),
                    bgColor: const Color(0xFFF3E8FF),
                    title: '30-Day Warranty',
                    description: 'Free re-work and damage cover included',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            color: const Color(0xFF64748B),
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
