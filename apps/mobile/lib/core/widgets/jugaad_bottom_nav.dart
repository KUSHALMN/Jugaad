import 'package:flutter/material.dart';
import '../theme/portal_mode.dart';

/// Premium pill-shaped animated bottom navigation bar.
/// Active tab: orange/green pill with white icon + label.
/// Inactive: grey icon only, no label.
class JugaadBottomNav extends StatefulWidget {
  final PortalMode mode;
  final int currentIndex;
  final Function(int) onTap;

  const JugaadBottomNav({
    super.key,
    required this.mode,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<JugaadBottomNav> createState() => _JugaadBottomNavState();
}

class _JugaadBottomNavState extends State<JugaadBottomNav>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..forward();
  }

  @override
  void didUpdateWidget(JugaadBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _animController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.mode == PortalMode.user;
    final activeColor = isUser ? const Color(0xFF1A56DB) : const Color(0xFF16A34A);
    final inactiveColor = isUser ? const Color(0xFF94A3B8) : const Color(0xFF9CA3AF);

    final List<_NavItem> items = isUser
        ? const [
            _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
            _NavItem(icon: Icons.assignment_outlined, activeIcon: Icons.assignment_rounded, label: 'Jobs'),
            _NavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Chat'),
            _NavItem(icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded, label: 'Workers'),
            _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
          ]
        : const [
            _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Home'),
            _NavItem(icon: Icons.assignment_outlined, activeIcon: Icons.assignment_rounded, label: 'Jobs'),
            _NavItem(icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded, label: 'Earnings'),
            _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
          ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: isUser
            ? const [
                BoxShadow(
                  color: Color(0x14000000), // rgba(0,0,0,0.08)
                  blurRadius: 20,
                  offset: Offset(0, -4),
                )
              ]
            : [],
        border: isUser
            ? null
            : const Border(
                top: BorderSide(
                  color: Color(0xFFEEEEEE),
                  width: 0.5,
                ),
              ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isActive = index == widget.currentIndex;

              return Expanded(
                child: GestureDetector(
                  onTap: () => widget.onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      final scale = isActive
                          ? Curves.easeOutBack.transform(_animController.value)
                          : 1.0;
                      return Transform.scale(
                        scale: scale.clamp(0.9, 1.1),
                        child: _buildTabItem(
                          item: item,
                          isActive: isActive,
                          activeColor: activeColor,
                          inactiveColor: inactiveColor,
                          isUser: isUser,
                        ),
                      );
                    },
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required _NavItem item,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required bool isUser,
  }) {
    if (isUser) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? item.activeIcon : item.icon,
            color: isActive ? activeColor : inactiveColor,
            size: 24,
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              color: isActive ? activeColor : inactiveColor,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 4 : 0,
            height: isActive ? 4 : 0,
            decoration: BoxDecoration(
              color: activeColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isActive ? item.activeIcon : item.icon,
          color: isActive ? activeColor : inactiveColor,
          size: 24,
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isActive ? 6 : 0,
          height: isActive ? 6 : 0,
          decoration: BoxDecoration(
            color: activeColor,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

