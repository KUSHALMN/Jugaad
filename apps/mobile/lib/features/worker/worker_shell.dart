import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/portal_mode.dart';
import '../../core/widgets/jugaad_bottom_nav.dart';
import 'widgets/worker_dashboard_sheets.dart';

/// Worker portal shell wrapper providing responsive navigation:
/// - Desktop (>= 1000px): SaaS Top Header + Left Sidebar + Main Canvas matching JUGAAD PRO mockup.
/// - Laptop / Tablet (800px - 1000px): SaaS Top Header + Responsive Canvas.
/// - Mobile (< 800px): Seamless mobile layout with bottom navigation bar.
class WorkerShell extends StatefulWidget {
  final Widget child;

  const WorkerShell({super.key, required this.child});

  @override
  State<WorkerShell> createState() => _WorkerShellState();
}

class _WorkerShellState extends State<WorkerShell> {
  String _selectedCity = 'Mysuru';

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/worker/home')) return 0;
    if (location.startsWith('/worker/active')) return 1;
    if (location.startsWith('/worker/earnings')) return 2;
    if (location.startsWith('/worker/profile')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    HapticFeedback.lightImpact();
    switch (index) {
      case 0:
        context.go('/worker/home');
        break;
      case 1:
        context.go('/worker/active');
        break;
      case 2:
        context.go('/worker/earnings');
        break;
      case 3:
        context.go('/worker/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1000;
    final bool isMediumOrDesktop = screenWidth >= 800;
    final int selectedIndex = _calculateSelectedIndex(context);

    final user = AuthService().currentUser;
    final displayName = (user?.displayName != null && user!.displayName!.isNotEmpty)
        ? user.displayName!
        : 'kush';
    final initialLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'K';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: isMediumOrDesktop
          ? PreferredSize(
              preferredSize: const Size.fromHeight(68),
              child: _DesktopWorkerNavBar(
                selectedIndex: selectedIndex,
                selectedCity: _selectedCity,
                userName: displayName,
                initialLetter: initialLetter,
                onItemTapped: (idx) => _onItemTapped(idx, context),
                onCityChanged: (city) => setState(() => _selectedCity = city),
              ),
            )
          : null,
      body: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left SaaS Sidebar matching mockup
                _DesktopWorkerSidebar(
                  selectedIndex: selectedIndex,
                  onItemTapped: (idx) => _onItemTapped(idx, context),
                ),
                // Main Content Canvas
                Expanded(
                  child: widget.child,
                ),
              ],
            )
          : widget.child,
      bottomNavigationBar: isMediumOrDesktop
          ? null
          : Container(
              color: Colors.white,
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: 1.0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1140),
                  child: JugaadBottomNav(
                    mode: PortalMode.worker,
                    currentIndex: selectedIndex,
                    onTap: (int idx) => _onItemTapped(idx, context),
                  ),
                ),
              ),
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DESKTOP TOP NAVIGATION BAR (Matching Mockup)
// ══════════════════════════════════════════════════════════════════════════════

class _DesktopWorkerNavBar extends StatelessWidget {
  final int selectedIndex;
  final String selectedCity;
  final String userName;
  final String initialLetter;
  final ValueChanged<int> onItemTapped;
  final ValueChanged<String> onCityChanged;

  const _DesktopWorkerNavBar({
    required this.selectedIndex,
    required this.selectedCity,
    required this.userName,
    required this.initialLetter,
    required this.onItemTapped,
    required this.onCityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final navItems = [
      (Icons.dashboard_rounded, 'Dashboard'),
      (Icons.assignment_rounded, 'Jobs'),
      (Icons.account_balance_wallet_rounded, 'Earnings'),
      (Icons.person_rounded, 'Profile'),
    ];

    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ─── LEFT: BRAND LOGO + LOCATION SELECTOR ─────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // JUGAAD PRO Logo
              GestureDetector(
                onTap: () => onItemTapped(0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF10B981)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.lightbulb_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              'JUGAAD ',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF0F172A),
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              'PRO',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF059669),
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Work. Earn. Grow.',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            fontSize: 10.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // Location Selector Pill (📍 Mysuru ▾)
              InkWell(
                onTap: () => WorkerDashboardSheets.showCitySelector(
                  context,
                  currentCity: selectedCity,
                  onCitySelected: onCityChanged,
                ),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, color: Color(0xFF0F172A), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        selectedCity,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ─── CENTER: NAV TABS (Dashboard, Jobs [3], Earnings, Profile) ───
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(navItems.length, (idx) {
              final item = navItems[idx];
              final isSelected = idx == selectedIndex;
              final bool hasJobBadge = idx == 1; // Jobs tab badge 3

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: InkWell(
                  onTap: () => onItemTapped(idx),
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE8F8F0) : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.$1,
                          size: 18,
                          color: isSelected ? const Color(0xFF059669) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          item.$2,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? const Color(0xFF059669) : const Color(0xFF475569),
                          ),
                        ),
                        if (hasJobBadge) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '3',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),

          // ─── RIGHT: NOTIFICATION BELL + USER AVATAR & DROPDOWN ───────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Notification Bell with Badge 3
              InkWell(
                onTap: () => WorkerDashboardSheets.showNotifications(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.notifications_none_rounded, color: Color(0xFF1E293B), size: 20),
                      Positioned(
                        top: 7,
                        right: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // User Avatar + Name Dropdown
              PopupMenuButton<String>(
                offset: const Offset(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (value) {
                  switch (value) {
                    case 'user_portal':
                      context.go('/user/home');
                      break;
                    case 'profile':
                      context.go('/worker/profile');
                      break;
                    case 'safety':
                      WorkerDashboardSheets.showSupportSheet(context);
                      break;
                    case 'logout':
                      AuthService().signOut();
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'user_portal',
                    child: Row(
                      children: [
                        const Icon(Icons.swap_horiz_rounded, color: Color(0xFF2563EB), size: 18),
                        const SizedBox(width: 10),
                        Text('Switch to Customer Mode', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, color: Color(0xFF059669), size: 18),
                        const SizedBox(width: 10),
                        Text('Partner Profile & KYC', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'safety',
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 10),
                        Text('24/7 Safety & SOS Desk', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded, color: Color(0xFF64748B), size: 18),
                        const SizedBox(width: 10),
                        Text('Sign Out', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFF86EFAC),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            initialLetter,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF14532D),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        userName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DESKTOP LEFT SIDEBAR (Matching Mockup)
// ══════════════════════════════════════════════════════════════════════════════

class _DesktopWorkerSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const _DesktopWorkerSidebar({
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Navigation Items
                  _buildSidebarItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    isSelected: selectedIndex == 0,
                    onTap: () => onItemTapped(0),
                  ),
                  _buildSidebarItem(
                    icon: Icons.assignment_outlined,
                    label: 'Jobs',
                    badgeText: '3',
                    badgeColor: const Color(0xFFEF4444),
                    isSelected: selectedIndex == 1,
                    onTap: () => onItemTapped(1),
                  ),
                  _buildSidebarItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Earnings',
                    isSelected: selectedIndex == 2,
                    onTap: () => onItemTapped(2),
                  ),
                  _buildSidebarItem(
                    icon: Icons.handyman_outlined,
                    label: 'My Services',
                    isSelected: false,
                    onTap: () => WorkerDashboardSheets.showMyServices(
                      context,
                      currentSkills: const ['electrician'],
                      onSkillsUpdated: (_) {},
                    ),
                  ),
                  _buildSidebarItem(
                    icon: Icons.description_outlined,
                    label: 'Documents',
                    badgeText: '!',
                    badgeColor: const Color(0xFFF59E0B),
                    isSelected: false,
                    onTap: () => WorkerDashboardSheets.showDocuments(context),
                  ),
                  _buildSidebarItem(
                    icon: Icons.credit_card_outlined,
                    label: 'Wallet & UPI',
                    isSelected: false,
                    onTap: () => WorkerDashboardSheets.showBankAndUpi(context),
                  ),
                  _buildSidebarItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Profile',
                    isSelected: selectedIndex == 3,
                    onTap: () => onItemTapped(3),
                  ),
                  _buildSidebarItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    isSelected: false,
                    onTap: () => onItemTapped(3),
                  ),

                  const SizedBox(height: 28),

                  // JUGAAD PRO Partner Network Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('👑', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'JUGAAD PRO',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  Text(
                                    'Partner Network',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Get more jobs, higher earnings and priority support.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => WorkerDashboardSheets.showPartnerNetworkPerks(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F8F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Learn More',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF059669),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded, color: Color(0xFF059669), size: 14),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Need Help Support Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.headset_mic_outlined, color: Color(0xFF2563EB), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Need Help?',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              InkWell(
                                onTap: () => WorkerDashboardSheets.showSupportSheet(context),
                                child: Text(
                                  'Chat with Support →',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    String? badgeText,
    Color? badgeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE8F8F0) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? const Color(0xFF059669) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF059669) : const Color(0xFF334155),
                  ),
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor ?? const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
