import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart' as pkg_provider;

import '../../../core/theme/portal_mode.dart';

/// Minimalist, Apple & Urban Company-grade Role Select Screen
/// Features Claude-style warm editorial serif typography (Newsreader),
/// website brand Royal Blue (`#1A56DB`) and Partner Emerald accents,
/// on a serene warm cream canvas.
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
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6), // Warm Claude / Apple cream canvas
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Top Navigation & Brand Lockup ─────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildBackButton(context),
                      // Minimalist Brand Identity
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9.0),
                              child: Image.asset(
                                'assets/images/app_icon.png',
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.flash_on_rounded, color: Color(0xFF1A56DB), size: 22),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10.0),
                          Text(
                            'JUGAAD',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                              color: const Color(0xFF191817),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 40),
                    ],
                  ).animate().fadeIn(duration: 300.ms),

                  const SizedBox(height: 48.0),

                  // ── Claude-Style Warm Editorial Headline ─────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 5.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(color: const Color(0xFFDBEAFE), width: 1.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A56DB),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7.0),
                        Text(
                          'PLATFORM ACCESS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: const Color(0xFF1A56DB),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 80.ms, duration: 350.ms).slideY(begin: 0.15, end: 0.0),

                  const SizedBox(height: 18.0),

                  Text(
                    'How will you use Jugaad?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.newsreader(
                      fontSize: 38.0,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.8,
                      color: const Color(0xFF191817),
                      height: 1.15,
                    ),
                  ).animate().fadeIn(delay: 140.ms, duration: 350.ms).slideY(begin: 0.15, end: 0.0),

                  const SizedBox(height: 12.0),

                  Text(
                    'Select your portal to continue. You can seamlessly switch between booking and earning inside your profile anytime.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF716F68),
                      height: 1.5,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 350.ms).slideY(begin: 0.15, end: 0.0),

                  const SizedBox(height: 40.0),

                  // ── Portal Card 1: Consumer / Booking (Website Brand Royal Blue) ──
                  _buildMinimalRoleCard(
                    mode: PortalMode.user,
                    eyebrow: 'CONSUMER & BUSINESS',
                    title: 'Book a Service',
                    description: 'Find trusted local professionals for home repairs, electrical, plumbing, carpentry, and cleaning.',
                    accentColor: const Color(0xFF1A56DB), // Website Royal Blue
                    bgAccent: const Color(0xFFEFF6FF),
                    icon: Icons.search_rounded,
                    isHovered: _hoveredMode == PortalMode.user,
                    onHover: (hovered) => setState(() => _hoveredMode = hovered ? PortalMode.user : null),
                    onTap: () => _selectRole(context, PortalMode.user),
                  ).animate().fadeIn(delay: 260.ms, duration: 400.ms).slideY(begin: 0.1, end: 0.0),

                  const SizedBox(height: 16.0),

                  // ── Portal Card 2: Professional / Earning (Emerald Green) ────────
                  _buildMinimalRoleCard(
                    mode: PortalMode.worker,
                    eyebrow: 'SERVICE PROFESSIONALS',
                    title: 'Join as a Partner',
                    description: 'Receive verified job dispatches in your neighborhood, set your own hours, and withdraw daily payouts.',
                    accentColor: const Color(0xFF059669), // Partner Emerald Green
                    bgAccent: const Color(0xFFECFDF5),
                    icon: Icons.handyman_rounded,
                    isHovered: _hoveredMode == PortalMode.worker,
                    onHover: (hovered) => setState(() => _hoveredMode = hovered ? PortalMode.worker : null),
                    onTap: () => _selectRole(context, PortalMode.worker),
                  ).animate().fadeIn(delay: 340.ms, duration: 400.ms).slideY(begin: 0.1, end: 0.0),

                  const SizedBox(height: 36.0),

                  // ── Apple-Grade Discreet Footer Guarantee ──────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sync_rounded, color: Color(0xFF8C8980), size: 14.0),
                      const SizedBox(width: 8.0),
                      Flexible(
                        child: Text(
                          'One verified account gives you access to both customer and partner portals.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF8C8980),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 420.ms, duration: 400.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MINIMALIST SCULPTED ROLE CARD (Apple & Urban Company aesthetic)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMinimalRoleCard({
    required PortalMode mode,
    required String eyebrow,
    required String title,
    required String description,
    required Color accentColor,
    required Color bgAccent,
    required IconData icon,
    required bool isHovered,
    required ValueChanged<bool>? onHover,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      onEnter: onHover != null ? (_) => onHover(true) : null,
      onExit: onHover != null ? (_) => onHover(false) : null,
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22.0),
          border: Border.all(
            color: isHovered ? accentColor : const Color(0xFFE8E5DD),
            width: isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isHovered ? 0.08 : 0.02),
              blurRadius: isHovered ? 24 : 12,
              offset: Offset(0, isHovered ? 8 : 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22.0),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22.0),
            splashColor: accentColor.withValues(alpha: 0.06),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 22.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Minimal Icon Capsule
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: bgAccent,
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                    child: Icon(
                      icon,
                      color: accentColor,
                      size: 22.0,
                    ),
                  ),

                  const SizedBox(width: 18.0),

                  // Text details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eyebrow,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 3.0),
                        Text(
                          title,
                          style: GoogleFonts.newsreader(
                            fontSize: 21.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.4,
                            color: const Color(0xFF191817),
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          description,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF716F68),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12.0),

                  // Apple-style Minimalist Arrow Pill
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isHovered ? accentColor : bgAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isHovered ? accentColor : accentColor.withValues(alpha: 0.2),
                        width: 1.0,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: isHovered ? Colors.white : accentColor,
                      size: 16.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFE8E5DD), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: Color(0xFF191817),
          size: 18.0,
        ),
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
}
