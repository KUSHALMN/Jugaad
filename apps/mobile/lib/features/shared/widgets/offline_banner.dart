// lib/features/shared/widgets/offline_banner.dart
// ═══════════════════════════════════════════════════════════════════
// Context-aware connectivity overlay. Shows different banners for:
//   - offline → red "No Internet" banner
//   - serverWaking → amber "Connecting to servers..." banner with spinner
//   - online → hidden
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/network/connectivity_service.dart';

class OfflineBannerOverlay extends StatefulWidget {
  final Widget child;
  const OfflineBannerOverlay({super.key, required this.child});

  @override
  State<OfflineBannerOverlay> createState() => _OfflineBannerOverlayState();
}

class _OfflineBannerOverlayState extends State<OfflineBannerOverlay>
    with SingleTickerProviderStateMixin {
  ConnectivityState _state = ConnectivityState.online;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // slide up from below
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    ConnectivityService.state.addListener(_onStateChanged);
    _state = ConnectivityService.state.value;

    if (_state != ConnectivityState.online) {
      _slideController.forward();
    }
  }

  void _onStateChanged() {
    if (!mounted) return;
    final newState = ConnectivityService.state.value;

    setState(() {
      _state = newState;
      _isDismissed = false;
    });

    if (newState == ConnectivityState.online) {
      _slideController.reverse();
    } else {
      _slideController.forward();
    }
  }

  @override
  void dispose() {
    ConnectivityService.state.removeListener(_onStateChanged);
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Animated banner sliding up from bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildBanner(),
          ),
        ),
      ],
    );
  }

  Widget _buildBanner() {
    if (_isDismissed) return const SizedBox.shrink();

    final config = _bannerConfig(_state);
    if (config == null) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: config.backgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Leading icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: config.iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: config.showSpinner
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              config.iconColor),
                        ),
                      )
                    : Icon(config.icon, color: config.iconColor, size: 24),
              ),
              const SizedBox(width: 14),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      config.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      config.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.kTextSecond,
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons (Retry + Close/Dismiss)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => ConnectivityService.retryConnection(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kSurface,
                      foregroundColor: AppColors.kTextPrimary,
                      side: const BorderSide(color: AppColors.kBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(0, 36),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      setState(() {
                        _isDismissed = true;
                      });
                      _slideController.reverse();
                    },
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                    splashRadius: 20,
                    color: AppColors.kTextSecond,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _BannerConfig? _bannerConfig(ConnectivityState state) {
    switch (state) {
      case ConnectivityState.online:
        return null; // no banner

      case ConnectivityState.offline:
        return _BannerConfig(
          icon: Icons.wifi_off_rounded,
          iconColor: AppColors.kDanger,
          title: 'No internet connection',
          subtitle: "Some features won't work.",
          backgroundColor: AppColors.kBackground,
          showSpinner: false,
        );

      case ConnectivityState.serverWaking:
        return _BannerConfig(
          icon: Icons.cloud_sync_rounded,
          iconColor: AppColors.kWarning,
          title: 'Connecting to servers...',
          subtitle: 'This may take a moment on first launch.',
          backgroundColor: AppColors.kWarningLight,
          showSpinner: true,
        );
    }
  }
}

class _BannerConfig {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final bool showSpinner;

  const _BannerConfig({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.showSpinner,
  });
}
