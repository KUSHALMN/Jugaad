import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as pkg_provider;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/portal_mode.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  PortalMode? _hoveredMode;

  void _selectRole(BuildContext context, PortalMode mode) {
    pkg_provider.Provider.of<PortalModeProvider>(context, listen: false).setMode(mode);
    context.go('/auth/otp?role=${mode.name}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 960;
          if (isDesktop) {
            return _buildDesktopLayout(context);
          }
          return _buildMobileLayout(context);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT: High-Converting 2-Column SaaS Split Screen
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // ── Left Column: Brand Hero Showcase ──────────────────────────
        Expanded(
          flex: 5,
          child: _buildBrandHeroPanel(),
        ),

        // ── Right Column: Interactive Role Selection Workspace ────────
        Expanded(
          flex: 6,
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: SafeArea(
              child: Stack(
                children: [
                  // Back button at top left
                  Positioned(
                    top: 24,
                    left: 32,
                    child: _buildBackButton(context),
                  ),

                  // Center workspace card
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 40.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Eyebrow badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(30.0),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.18),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.hub_outlined, color: AppColors.primary, size: 14.0),
                                  const SizedBox(width: 6.0),
                                  Text(
                                    'SELECT YOUR PORTAL',
                                    style: AppTextStyles.labelCaps(color: AppColors.primary).copyWith(
                                      fontSize: 11.0,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0.0),

                            const SizedBox(height: 16.0),

                            // Main heading
                            Text(
                              'How will you use Jugaad?',
                              style: AppTextStyles.heading1(color: const Color(0xFF0F172A)).copyWith(
                                fontSize: 32.0,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                              ),
                            ).animate().fadeIn(delay: 80.ms, duration: 350.ms).slideY(begin: 0.15, end: 0.0),

                            const SizedBox(height: 10.0),

                            Text(
                              'Choose your experience. Whether you need skilled work done or want to offer your services, you can toggle between both portals anytime with one click.',
                              style: AppTextStyles.bodyMedium(color: const Color(0xFF64748B)).copyWith(
                                fontSize: 15.0,
                                height: 1.5,
                              ),
                            ).animate().fadeIn(delay: 140.ms, duration: 350.ms).slideY(begin: 0.15, end: 0.0),

                            const SizedBox(height: 36.0),

                            // Portal Card 1: User / Booking
                            _buildRoleCard(
                              context: context,
                              mode: PortalMode.user,
                              badge: 'FOR HOMES & BUSINESSES',
                              title: 'I want to Book a Service',
                              description: 'Find, schedule, and hire background-verified plumbers, electricians, AC mechanics & more in minutes.',
                              accentColor: const Color(0xFF1A56DB),
                              lightAccent: const Color(0xFFEFF6FF),
                              icon: Icons.person_search_rounded,
                              perks: ['⚡ 15-min dispatch', '🛡️ ₹10k damage cover', '⭐ 4.9★ rated pros'],
                              isHovered: _hoveredMode == PortalMode.user,
                              onHover: (hovered) => setState(() => _hoveredMode = hovered ? PortalMode.user : null),
                              onTap: () => _selectRole(context, PortalMode.user),
                            ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.12, end: 0.0),

                            const SizedBox(height: 20.0),

                            // Portal Card 2: Worker / Earning
                            _buildRoleCard(
                              context: context,
                              mode: PortalMode.worker,
                              badge: 'FOR SERVICE PROFESSIONALS',
                              title: 'I want to Earn as a Partner',
                              description: 'Receive real-time job requests in your neighborhood, grow your client base, and withdraw daily payouts.',
                              accentColor: const Color(0xFF16A34A),
                              lightAccent: const Color(0xFFE1F5EE),
                              icon: Icons.handyman_rounded,
                              perks: ['💰 0% commission intro', '📲 Instant job leads', '⚡ Daily direct payouts'],
                              isHovered: _hoveredMode == PortalMode.worker,
                              onHover: (hovered) => setState(() => _hoveredMode = hovered ? PortalMode.worker : null),
                              onTap: () => _selectRole(context, PortalMode.worker),
                            ).animate().fadeIn(delay: 280.ms, duration: 400.ms).slideY(begin: 0.12, end: 0.0),

                            const SizedBox(height: 32.0),

                            // Guarantee / Flexibility Trust Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6.0),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.sync_alt_rounded, color: Color(0xFF7C3AED), size: 16.0),
                                  ),
                                  const SizedBox(width: 12.0),
                                  Expanded(
                                    child: Text(
                                      'Dual profile support enabled: seamlessly switch between booking and earning inside your profile anytime.',
                                      style: AppTextStyles.bodySmall(color: const Color(0xFF475569)).copyWith(
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(delay: 360.ms, duration: 400.ms),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MOBILE / TABLET COMPACT LAYOUT
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Top Hero Banner with brand aesthetics
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 28.0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF071329),
                    Color(0xFF0E2856),
                    Color(0xFF1A56DB),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28.0),
                  bottomRight: Radius.circular(28.0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildBackButton(context, isDark: true),
                      // Live pro indicator pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20.0),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6.0),
                            const Text(
                              '450+ Pros Online',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24.0),
                  // App branding
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
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
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.flash_on_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      Text(
                        'JUGAAD',
                        style: AppTextStyles.heading3(color: Colors.white).copyWith(
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    'How will you use Jugaad?',
                    style: AppTextStyles.heading1(color: Colors.white).copyWith(
                      fontSize: 26.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Select your portal to start. You can switch between booking and earning anytime in your account.',
                    style: AppTextStyles.bodyMedium(color: Colors.white.withValues(alpha: 0.85)).copyWith(
                      height: 1.4,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),

            // Content Container
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const SizedBox(height: 8.0),
                  // User Role Card
                  _buildRoleCard(
                    context: context,
                    mode: PortalMode.user,
                    badge: 'FOR CUSTOMERS',
                    title: 'I want to Book',
                    description: 'Book verified plumbers, electricians, cleaners & technicians in minutes.',
                    accentColor: const Color(0xFF1A56DB),
                    lightAccent: const Color(0xFFEFF6FF),
                    icon: Icons.person_search_rounded,
                    perks: ['⚡ 15-min arrival', '🛡️ Damage protection', '⭐ 4.9★ Pros'],
                    isHovered: false,
                    onHover: null,
                    onTap: () => _selectRole(context, PortalMode.user),
                  ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0.0),

                  const SizedBox(height: 16.0),

                  // Worker Role Card
                  _buildRoleCard(
                    context: context,
                    mode: PortalMode.worker,
                    badge: 'FOR SERVICE PARTNERS',
                    title: 'I want to Earn',
                    description: 'Get local job requests, work on your terms, and receive instant payouts.',
                    accentColor: const Color(0xFF16A34A),
                    lightAccent: const Color(0xFFE1F5EE),
                    icon: Icons.handyman_rounded,
                    perks: ['💰 0% commission', '📲 Direct leads', '⚡ Daily payouts'],
                    isHovered: false,
                    onHover: null,
                    onTap: () => _selectRole(context, PortalMode.worker),
                  ).animate().fadeIn(delay: 100.ms, duration: 350.ms).slideY(begin: 0.1, end: 0.0),

                  const SizedBox(height: 24.0),

                  // Bottom Notice
                  Container(
                    padding: const EdgeInsets.all(14.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Color(0xFF1A56DB), size: 18.0),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: Text(
                            'One single profile for everything. Switch roles with 1 tap.',
                            style: AppTextStyles.bodySmall(color: const Color(0xFF64748B), weight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24.0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BRAND HERO PANEL (Desktop Left Side)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildBrandHeroPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF060D1E),
            Color(0xFF0A1C3C),
            Color(0xFF0F2C61),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 56.0, vertical: 48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Category Pill
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.flash_on_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 14.0),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'JUGAAD',
                    style: AppTextStyles.heading3(color: Colors.white).copyWith(
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'HYPERLOCAL WORK PLATFORM',
                    style: AppTextStyles.labelCaps(color: Colors.white.withValues(alpha: 0.65)).copyWith(
                      fontSize: 10.0,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Live Pulse Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30.0),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF22C55E),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),
                Text(
                  'Active in Mysuru • 480+ Certified Pros',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 24.0),

          // High-Impact SaaS Headline
          Text(
            'The Smartest Way to\nBook or Deliver Local Work.',
            style: AppTextStyles.displayHero(fontSize: 40.0, color: Colors.white).copyWith(
              height: 1.15,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.15, end: 0.0),

          const SizedBox(height: 16.0),

          Text(
            'Join thousands of residents and independent technicians using Jugaad for transparent, reliable home & commercial services with real-time tracking.',
            style: AppTextStyles.bodyLarge(color: Colors.white.withValues(alpha: 0.75)).copyWith(
              height: 1.5,
              fontSize: 16.0,
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

          const SizedBox(height: 36.0),

          // 3 Trust Metrics Horizontal Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricColumn('15 min', 'Avg. Dispatch', Icons.bolt_rounded, const Color(0xFFF59E0B)),
                Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.15)),
                _buildMetricColumn('₹10,000', 'Damage Cover', Icons.verified_user_rounded, const Color(0xFF38BDF8)),
                Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.15)),
                _buildMetricColumn('4.9 / 5', 'Rating (12k+)', Icons.star_rounded, const Color(0xFFFBBF24)),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

          const Spacer(),

          // Worker & Customer Social Proof Snippet
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF1A56DB),
                  child: const Icon(Icons.engineering_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Suresh M.',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          const SizedBox(width: 6.0),
                          const Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 14.0),
                          const Spacer(),
                          const Row(
                            children: [
                              Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 14),
                              SizedBox(width: 2),
                              Text('4.96', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        'Master Electrician • "Earned ₹38,400 last month on Jugaad with instant local bookings."',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.0),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String value, String label, IconData icon, Color iconColor) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 11.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REUSABLE SAAS ROLE CARD
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildRoleCard({
    required BuildContext context,
    required PortalMode mode,
    required String badge,
    required String title,
    required String description,
    required Color accentColor,
    required Color lightAccent,
    required IconData icon,
    required List<String> perks,
    required bool isHovered,
    required ValueChanged<bool>? onHover,
    required VoidCallback onTap,
  }) {
    final cardContent = MouseRegion(
      onEnter: onHover != null ? (_) => onHover(true) : null,
      onExit: onHover != null ? (_) => onHover(false) : null,
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, isHovered ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22.0),
          border: Border.all(
            color: isHovered ? accentColor : const Color(0xFFE2E8F0),
            width: isHovered ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isHovered
                  ? accentColor.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isHovered ? 24 : 14,
              offset: Offset(0, isHovered ? 8 : 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22.0),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22.0),
            splashColor: accentColor.withValues(alpha: 0.08),
            highlightColor: accentColor.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Category tag + arrow action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: lightAccent,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: isHovered ? accentColor : lightAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: isHovered ? Colors.white : accentColor,
                          size: 16.0,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16.0),

                  // Middle Row: Big Icon + Title + Description
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accentColor, accentColor.withValues(alpha: 0.85)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 26.0),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTextStyles.heading3(color: const Color(0xFF0F172A)).copyWith(
                                fontSize: 18.0,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5.0),
                            Text(
                              description,
                              style: AppTextStyles.bodyMedium(color: const Color(0xFF64748B)).copyWith(
                                fontSize: 13.5,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16.0),

                  // Bottom Row: Perks Chips
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 6.0,
                    children: perks.map((perk) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20.0),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          perk,
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 11.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return cardContent;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BACK BUTTON
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildBackButton(BuildContext context, {bool isDark = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          size: 20.0,
        ),
        onPressed: () => context.go('/'),
        tooltip: 'Back to Home',
      ),
    );
  }
}
