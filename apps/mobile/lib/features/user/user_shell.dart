import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/portal_mode.dart';
import '../../core/widgets/jugaad_bottom_nav.dart';

class UserShell extends StatelessWidget {
  final Widget child;

  const UserShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/user/home')) return 0;
    if (location.startsWith('/user/jobs')) return 1;
    if (location.startsWith('/user/chat')) return 2;
    if (location.startsWith('/user/workers')) return 3;
    if (location.startsWith('/user/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
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
    return Scaffold(
      body: child,
      bottomNavigationBar: JugaadBottomNav(
        mode: PortalMode.user,
        currentIndex: _calculateSelectedIndex(context),
        onTap: (int idx) => _onItemTapped(idx, context),
      ),
    );
  }
}
