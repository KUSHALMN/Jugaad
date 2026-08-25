import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/portal_mode.dart';
import '../../core/widgets/jugaad_bottom_nav.dart';

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
    return Scaffold(
      body: child,
      bottomNavigationBar: JugaadBottomNav(
        mode: PortalMode.worker,
        currentIndex: _calculateSelectedIndex(context),
        onTap: (int idx) => _onItemTapped(idx, context),
      ),
    );
  }
}
