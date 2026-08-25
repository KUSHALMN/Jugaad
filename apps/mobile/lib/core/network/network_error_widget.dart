// lib/core/network/network_error_widget.dart
// ═══════════════════════════════════════════════════════════════════
// Context-aware error widget — shows different UI based on error type.
// Drop-in replacement for generic "Something went wrong" screens.
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'api_error.dart';

class NetworkErrorWidget extends StatelessWidget {
  final ApiError error;
  final VoidCallback? onRetry;

  /// If true, uses a compact inline layout (for embedding inside lists/cards).
  /// If false, uses a centered full-screen layout.
  final bool compact;

  const NetworkErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _errorConfig(error);

    if (compact) {
      return _buildCompact(config);
    }
    return _buildFullScreen(config);
  }

  // ─── Full-screen centered layout ──────────────────────────────

  Widget _buildFullScreen(_ErrorDisplayConfig config) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with colored circle background
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: config.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(config.icon, color: config.color, size: 40),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              config.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.kTextPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Message
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.kTextSecond,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Auto-retry indicator OR retry button
            if (config.showAutoRetry)
              _buildAutoRetryIndicator(config)
            else if (onRetry != null)
              _buildRetryButton(config),
          ],
        ),
      ),
    );
  }

  // ─── Compact inline layout ────────────────────────────────────

  Widget _buildCompact(_ErrorDisplayConfig config) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: config.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(config.icon, color: config.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  config.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.kTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  error.message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.kTextSecond,
                  ),
                ),
              ],
            ),
          ),
          if (config.showAutoRetry)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.kWarning),
              ),
            )
          else if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: config.color,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 32),
              ),
              child: const Text('Retry',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  // ─── Auto-retry loading indicator ─────────────────────────────

  Widget _buildAutoRetryIndicator(_ErrorDisplayConfig config) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(config.color),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Retrying automatically...',
          style: TextStyle(
            fontSize: 13,
            color: config.color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─── Retry button ─────────────────────────────────────────────

  Widget _buildRetryButton(_ErrorDisplayConfig config) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Try Again'),
        style: ElevatedButton.styleFrom(
          backgroundColor: config.color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // ─── Error type → display config mapping ──────────────────────

  static _ErrorDisplayConfig _errorConfig(ApiError error) {
    switch (error.type) {
      case ApiErrorType.noInternet:
        return _ErrorDisplayConfig(
          icon: Icons.wifi_off_rounded,
          title: 'No Internet',
          color: AppColors.kDanger,
          showAutoRetry: false,
        );
      case ApiErrorType.serverColdStart:
        return _ErrorDisplayConfig(
          icon: Icons.cloud_sync_rounded,
          title: 'Waking Up Servers',
          color: AppColors.kWarning,
          showAutoRetry: true,
        );
      case ApiErrorType.slowConnection:
        return _ErrorDisplayConfig(
          icon: Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
          title: 'Slow Connection',
          color: AppColors.kWarning,
          showAutoRetry: true,
        );
      case ApiErrorType.serverError:
        return _ErrorDisplayConfig(
          icon: Icons.dns_rounded,
          title: 'Server Error',
          color: AppColors.kDanger,
          showAutoRetry: false,
        );
      case ApiErrorType.clientError:
        return _ErrorDisplayConfig(
          icon: Icons.error_outline_rounded,
          title: 'Request Failed',
          color: AppColors.primary,
          showAutoRetry: false,
        );
      case ApiErrorType.cancelled:
        return _ErrorDisplayConfig(
          icon: Icons.cancel_outlined,
          title: 'Cancelled',
          color: AppColors.kNeutral,
          showAutoRetry: false,
        );
      case ApiErrorType.unknown:
        return _ErrorDisplayConfig(
          icon: Icons.help_outline_rounded,
          title: 'Something Went Wrong',
          color: AppColors.kNeutral,
          showAutoRetry: false,
        );
    }
  }
}

class _ErrorDisplayConfig {
  final IconData icon;
  final String title;
  final Color color;
  final bool showAutoRetry;

  const _ErrorDisplayConfig({
    required this.icon,
    required this.title,
    required this.color,
    required this.showAutoRetry,
  });
}
