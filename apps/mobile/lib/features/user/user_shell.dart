import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/portal_mode.dart';
import '../../core/widgets/jugaad_bottom_nav.dart';

/// User portal shell wrapper providing responsive navigation:
/// - Desktop & Laptop (>= 800px): Sleek SaaS Top Navigation Bar with active indicator,
///   portal switcher, and maximized viewport height (no mobile bottom bar).
/// - Tablet & Mobile (< 800px): Clean mobile experience with bottom navigation bar.
class UserShell extends StatelessWidget {
  final Widget child;

  const UserShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/user/home')) return 0;
    if (location.startsWith('/user/jobs')) return 1;
    if (location.startsWith('/user/chat')) return 2;
    if (location.startsWith('/user/workers')) return 3;
    if (location.startsWith('/user/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    HapticFeedback.lightImpact();
    switch (index) {
      case 0:
        context.go('/user/home');
        break;
      case 1:
        context.go('/user/jobs');
        break;
      case 2:
        context.go('/user/chat');
        break;
      case 3:
        context.go('/user/workers');
        break;
      case 4:
        context.go('/user/profile');
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
              child: _DesktopUserNavBar(
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
                    mode: PortalMode.user,
                    currentIndex: selectedIndex,
                    onTap: (int idx) => _onItemTapped(idx, context),
                  ),
                ),
              ),
            ),
    );
  }
}

class _DesktopUserNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const _DesktopUserNavBar({
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    final navItems = [
      (Icons.home_rounded, Icons.home_outlined, 'Home'),
      (Icons.assignment_rounded, Icons.assignment_outlined, 'Jobs'),
      (Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded, 'Chat'),
      (Icons.people_rounded, Icons.people_outline_rounded, 'Workers'),
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
              // Left: Brand Logo + City
              GestureDetector(
                onTap: () => onItemTapped(0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'JUGAAD',
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
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
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
                            'Bengaluru & Mysuru',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
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
                          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? item.$1 : item.$2,
                              size: 18,
                              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              item.$3,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),

              // Right: Switch to Worker Mode + Monogram
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      context.go('/worker/home');
                    },
                    icon: const Icon(Icons.engineering_rounded, size: 16, color: Color(0xFF16A34A)),
                    label: Text(
                      'Worker Portal',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      side: const BorderSide(color: Color(0xFFBBF7D0)),
                      backgroundColor: const Color(0xFFF0FDF4),
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

