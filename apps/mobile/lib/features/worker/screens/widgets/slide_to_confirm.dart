// lib/features/worker/screens/widgets/slide_to_confirm.dart
// ═══════════════════════════════════════════════════════════════════
// Swipe/slide-to-confirm interaction widget with haptic feedback.
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jugaad_mvp/core/theme/worker_app_theme.dart';
import 'package:jugaad_mvp/core/utils/haptic_feedback_utils.dart';

class SlideToConfirm extends StatefulWidget {
  final String label;
  final VoidCallback onConfirm;
  final bool isLoading;
  final Color? trackColor;
  final IconData icon;

  const SlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirm,
    this.isLoading = false,
    this.trackColor,
    this.icon = Icons.arrow_forward_rounded,
  });

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  double _dragProgress = 0.0;
  int _lastMilestone = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double trackWidth = constraints.maxWidth;
        if (trackWidth <= 60.0) {
          return const SizedBox.shrink();
        }
        final double thumbSize = 50.0;
        final double maxDragDistance = (trackWidth - thumbSize - 6.0).clamp(1.0, double.infinity);

        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: widget.trackColor ??
                (widget.isLoading
                    ? WorkerAppTheme.primaryGreen.withValues(alpha: 0.6)
                    : WorkerAppTheme.primaryGreen),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: (widget.trackColor ?? WorkerAppTheme.primaryGreen).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Center(
                child: Opacity(
                  opacity: (1.0 - _dragProgress).clamp(0.2, 1.0),
                  child: Text(
                    widget.isLoading ? 'Processing...' : widget.label,
                    style: WorkerAppTheme.heading(
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 3.0 + (_dragProgress * maxDragDistance),
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (widget.isLoading) return;
                    setState(() {
                      _dragProgress += details.primaryDelta! / maxDragDistance;
                      _dragProgress = _dragProgress.clamp(0.0, 1.0);
                      final currentMilestone = (_dragProgress * 4).floor();
                      if (currentMilestone != _lastMilestone) {
                        _lastMilestone = currentMilestone;
                        AppHaptics.sliderNotch();
                      }
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (widget.isLoading) return;
                    _lastMilestone = 0;
                    if (_dragProgress >= 0.85) {
                      AppHaptics.heavySuccess();
                      widget.onConfirm();
                      setState(() {
                        _dragProgress = 1.0;
                      });
                    } else {
                      AppHaptics.lightTick();
                      setState(() {
                        _dragProgress = 0.0;
                      });
                    }
                  },
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: WorkerAppTheme.primaryGreen,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_forward_rounded,
                              color: WorkerAppTheme.primaryGreen,
                              size: 24,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
