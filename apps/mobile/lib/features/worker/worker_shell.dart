import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/portal_mode.dart';
import '../../core/widgets/jugaad_bottom_nav.dart';

/// Worker portal shell wrapper providing responsive navigation:
/// - Desktop & Laptop (>= 800px): Sleek Emerald SaaS Top Navigation Bar with active indicator,
///   user portal switcher, and maximized viewport height.
/// - Tablet & Mobile (< 800px): Mobile bottom navigation bar.
class WorkerShell extends StatelessWidget {
  final Widget child;

  const WorkerShell({super.key, required this.child});

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
    final bool isDesktop = screenWidth >= 800;
    final int selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: isDesktop
          ? PreferredSize(
              preferredSize: const Size.fromHeight(68),
              child: _DesktopWorkerNavBar(
                selectedIndex: selectedIndex,
                onItemTapped: (idx) => _onItemTapped(idx, context),
              ),
            )
          : null,
      body: SizedBox.expand(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1140),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: isDesktop
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

class _DesktopWorkerNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const _DesktopWorkerNavBar({
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    final navItems = [
      (Icons.dashboard_rounded, Icons.dashboard_outlined, 'Dashboard'),
      (Icons.assignment_rounded, Icons.assignment_outlined, 'Jobs'),
      (Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Earnings'),
      (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1140),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Brand Logo + Pro Badge
              GestureDetector(
                onTap: () => onItemTapped(0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'JUGAAD PRO',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF16A34A),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Technician Network',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Center: Desktop Navigation Tabs
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(navItems.length, (idx) {
                  final item = navItems[idx];
                  final isSelected = idx == selectedIndex;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: InkWell(
                      onTap: () => onItemTapped(idx),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFF0FDF4) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? item.$1 : item.$2,
                              size: 18,
                              color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              item.$3,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? const Color(0xFF15803D) : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),

              // Right: Switch to User Mode
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      context.go('/user/home');
                    },
                    icon: const Icon(Icons.person_rounded, size: 16, color: Color(0xFF2563EB)),
                    label: Text(
                      'User Portal',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      backgroundColor: const Color(0xFFEFF6FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

