import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart' as pkg_provider;

import '../../../core/theme/portal_mode.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  PortalMode? _hoveredMode;

  void _selectRole(BuildContext context, PortalMode mode) {
    HapticFeedback.lightImpact();
    pkg_provider.Provider.of<PortalModeProvider>(context, listen: false).setMode(mode);
    context.go('/auth/otp?role=${mode.name}');
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth >= 960;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9), // Serene clean warm canvas
      body: SafeArea(
        child: Stack(
          children: [
            // Soft decorative ambient washes
            Positioned(
              top: -60,
              left: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFDCFCE7).withValues(alpha: 0.35),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              right: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFEDD5).withValues(alpha: 0.35),
                ),
              ),
            ),

            // Main Content
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── 1. Top Navigation & Brand Header ───────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildBackButton(context),

                          // Brand Center Logo Lockup
                          _buildBrandHeader(),

                          // Location Pill
                          _buildLocationPill(),
                        ],
                      ).animate().fadeIn(duration: 300.ms),

                      const SizedBox(height: 36.0),

                      // ── 2. Platform Access Pill ────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20.0),
                          border: Border.all(color: const Color(0xFFDBEAFE), width: 1.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.settings_suggest_rounded, color: Color(0xFF2563EB), size: 14),
                            const SizedBox(width: 6.0),
                            Text(
                              'PLATFORM ACCESS',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 80.ms, duration: 350.ms).slideY(begin: 0.15, end: 0.0),

                      const SizedBox(height: 16.0),

                      // ── 3. Headline: "How will you use Jugaad?" ─────────────
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isWide ? 38.0 : 28.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                            color: const Color(0xFF0F172A),
                            height: 1.15,
                          ),
                          children: const [
                            TextSpan(text: 'How will you use '),
                            TextSpan(
                              text: 'Jug',
                              style: TextStyle(color: Color(0xFF059669)),
                            ),
                            TextSpan(
                              text: 'aad',
                              style: TextStyle(color: Color(0xFFEA580C)),
                            ),
                            TextSpan(text: '?'),
                          ],
                        ),
                      ).animate().fadeIn(delay: 140.ms, duration: 350.ms).slideY(begin: 0.15, end: 0.0),

                      const SizedBox(height: 10.0),

                      Text(
                        'Select your portal to continue. You can switch between booking and earning inside your profile anytime.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isWide ? 14.5 : 13.0,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                          height: 1.45,
                        ),
                      ).animate().fadeIn(delay: 200.ms, duration: 350.ms).slideY(begin: 0.15, end: 0.0),

                      const SizedBox(height: 32.0),

                      // ── 4. The Two Portal Cards (Side-by-Side or Stacked) ──
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildCustomerCard(isWide: true)),
                            const SizedBox(width: 20),
                            Expanded(child: _buildPartnerCard(isWide: true)),
                          ],
                        )
                      else ...[
                        _buildCustomerCard(isWide: false),
                        const SizedBox(height: 20),
                        _buildPartnerCard(isWide: false),
                      ],

                      const SizedBox(height: 36.0),

                      // ── 5. Footer Value Props (One Verified, Switch, Secure) ─
                      _buildFooterValueProps(isWide: isWide),
                      const SizedBox(height: 16.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TOP BRAND & CONTROLS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBrandHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF059669),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8.0),
            RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
                children: const [
                  TextSpan(text: 'JUG', style: TextStyle(color: Color(0xFF059669))),
                  TextSpan(text: 'AAD', style: TextStyle(color: Color(0xFFEA580C))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2.0),
        Text(
          'Local Help. Anytime.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_rounded, color: Color(0xFF059669), size: 16),
          const SizedBox(width: 6.0),
          Text(
            'Mysuru',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.0,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 4.0),
          const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20.0),
        padding: EdgeInsets.zero,
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/auth/onboarding');
          }
        },
        tooltip: 'Back',
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CARD 1: CONSUMER & BUSINESS ("Book a Service")
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCustomerCard({required bool isWide}) {
    final isHovered = _hoveredMode == PortalMode.user;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredMode = PortalMode.user),
      onExit: (_) => setState(() => _hoveredMode = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _selectRole(context, PortalMode.user),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, isHovered ? -3 : 0, 0),
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22.0),
            border: Border.all(
              color: isHovered ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
              width: isHovered ? 1.8 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: isHovered ? 0.12 : 0.04),
                blurRadius: isHovered ? 24 : 14,
                offset: Offset(0, isHovered ? 8 : 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool splitColumns = constraints.maxWidth >= 460;

              return splitColumns
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Visual Showcase with Badge
                        SizedBox(
                          width: 175,
                          height: 240,
                          child: _buildCustomerImageShowcase(),
                        ),
                        const SizedBox(width: 18),

                        // Right Details & Action
                        Expanded(child: _buildCustomerDetails()),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 160,
                          child: _buildCustomerImageShowcase(),
                        ),
                        const SizedBox(height: 16),
                        _buildCustomerDetails(),
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerImageShowcase() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/banner_tools_apple.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Image.network(
                'https://images.unsplash.com/photo-1581783342308-f792dbdd27c5?w=600&auto=format&fit=crop&q=80',
                fit: BoxFit.cover,
              ),
            ),
            // Floating bottom badge
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 12),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Reliable local professionals for your everyday needs',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tag & Header
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.search_rounded, color: Color(0xFF059669), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONSUMER',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: const Color(0xFF059669),
                    ),
                  ),
                  Text(
                    'Book a Service',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFDCFCE7)),
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF059669), size: 16),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          'Find trusted local professionals for home repairs, electrical, plumbing, cleaning, carpentry and more.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: const Color(0xFF64748B),
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 14),

        // Category Tag Chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildFeatureChip(icon: Icons.home_repair_service_rounded, label: 'Home repairs'),
            _buildFeatureChip(icon: Icons.bolt_rounded, label: 'Electrical', iconColor: const Color(0xFFD97706)),
            _buildFeatureChip(icon: Icons.cleaning_services_rounded, label: 'Cleaning', iconColor: const Color(0xFF059669)),
            _buildFeatureChip(icon: Icons.water_drop_rounded, label: 'Plumbing', iconColor: const Color(0xFF0284C7)),
            _buildFeatureChip(icon: Icons.handyman_rounded, label: 'Carpentry', iconColor: const Color(0xFFD97706)),
            _buildFeatureChip(icon: Icons.more_horiz_rounded, label: 'And more'),
          ],
        ),

        const SizedBox(height: 18),

        // Action CTA
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () => _selectRole(context, PortalMode.user),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue as Customer',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CARD 2: SERVICE PROFESSIONALS ("Join as a Partner")
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPartnerCard({required bool isWide}) {
    final isHovered = _hoveredMode == PortalMode.worker;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredMode = PortalMode.worker),
      onExit: (_) => setState(() => _hoveredMode = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _selectRole(context, PortalMode.worker),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, isHovered ? -3 : 0, 0),
          padding: const EdgeInsets.all(18.0),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDFB),
            borderRadius: BorderRadius.circular(22.0),
            border: Border.all(
              color: isHovered ? const Color(0xFFEA580C) : const Color(0xFFFED7AA),
              width: isHovered ? 1.8 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEA580C).withValues(alpha: isHovered ? 0.12 : 0.04),
                blurRadius: isHovered ? 24 : 14,
                offset: Offset(0, isHovered ? 8 : 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool splitColumns = constraints.maxWidth >= 460;

              return splitColumns
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Visual Showcase with Floating Pills & Badge
                        SizedBox(
                          width: 175,
                          height: 240,
                          child: _buildPartnerImageShowcase(),
                        ),
                        const SizedBox(width: 18),

                        // Right Details & Action
                        Expanded(child: _buildPartnerDetails()),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 160,
                          child: _buildPartnerImageShowcase(),
                        ),
                        const SizedBox(height: 16),
                        _buildPartnerDetails(),
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerImageShowcase() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/service_electrician.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Image.network(
                'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=600&auto=format&fit=crop&q=80',
                fit: BoxFit.cover,
              ),
            ),

            // Floating Top Pills
            Positioned(
              top: 8,
              left: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFloatingPill(icon: Icons.access_time_rounded, label: 'Set your hours'),
                  const SizedBox(height: 4),
                  _buildFloatingPill(icon: Icons.currency_rupee_rounded, label: 'Earn daily'),
                  const SizedBox(height: 4),
                  _buildFloatingPill(icon: Icons.business_center_rounded, label: 'Get job requests'),
                ],
              ),
            ),

            // Floating Bottom Badge
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Color(0xFFEA580C), size: 14),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Turn your skills into verified job opportunities in your area',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tag & Header
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDD5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.handyman_rounded, color: Color(0xFFEA580C), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SERVICE PROFESSIONAL',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: const Color(0xFFEA580C),
                    ),
                  ),
                  Text(
                    'Join as a Partner',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFFEA580C), size: 16),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          'Receive verified job requests in your area, set your own hours, and withdraw your earnings easily.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: const Color(0xFF64748B),
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 14),

        // Perk Tag Chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildFeatureChip(icon: Icons.access_time_rounded, label: 'Flexible hours', iconColor: const Color(0xFFEA580C)),
            _buildFeatureChip(icon: Icons.trending_up_rounded, label: 'Earn daily', iconColor: const Color(0xFFEA580C)),
            _buildFeatureChip(icon: Icons.business_center_rounded, label: 'Get job requests', iconColor: const Color(0xFFEA580C)),
            _buildFeatureChip(icon: Icons.security_rounded, label: 'Build your reputation', iconColor: const Color(0xFFEA580C)),
            _buildFeatureChip(icon: Icons.groups_rounded, label: 'Grow your business', iconColor: const Color(0xFFEA580C)),
          ],
        ),

        const SizedBox(height: 18),

        // Action CTA
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () => _selectRole(context, PortalMode.worker),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue as Partner',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REUSABLE PILL & CHIP HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFeatureChip({
    required IconData icon,
    required String label,
    Color iconColor = const Color(0xFF0F172A),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFEA580C), size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FOOTER VALUE PROPS (3 Columns)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFooterValueProps({required bool isWide}) {
    final List<Widget> items = [
      _buildValuePropItem(
        icon: Icons.verified_user_rounded,
        title: 'One Verified Account',
        subtitle: 'Access both customer and partner portals',
      ),
      _buildValuePropItem(
        icon: Icons.sync_rounded,
        title: 'Switch Anytime',
        subtitle: 'You can switch between portals from your profile',
      ),
      _buildValuePropItem(
        icon: Icons.lock_outline_rounded,
        title: 'Secure Platform',
        subtitle: 'Protected authentication and payments',
      ),
    ];

    if (isWide) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: items[0]),
            Container(width: 1, height: 38, color: const Color(0xFFE2E8F0)),
            Expanded(child: items[1]),
            Container(width: 1, height: 38, color: const Color(0xFFE2E8F0)),
            Expanded(child: items[2]),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            items[0],
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            items[1],
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            items[2],
          ],
        ),
      );
    }
  }

  Widget _buildValuePropItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFFDCFCE7),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF059669), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
