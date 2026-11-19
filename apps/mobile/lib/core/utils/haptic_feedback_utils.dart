import 'package:flutter/services.dart';

/// Centralized micro-haptic feedback utility for tactile UX across Jugaad.
/// Follows Apple HIG & Material 3 sensory design patterns.
class AppHaptics {
  AppHaptics._();

  /// Light tick for toggling chips, filter tabs, or scrolling milestone lists.
  static Future<void> lightTick() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Medium snap for expanding bottom sheets, modal cards, or accordion headers.
  static Future<void> mediumSnap() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Heavy impact for booking confirmation, payment transfer, or job dispatch.
  static Future<void> heavySuccess() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Selection click for segmented controls and number keypads.
  static Future<void> selectionChange() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Tactile resistance notch for swipe-to-confirm sliders.
  static Future<void> sliderNotch() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Error buzz for validation rejection, OTP mismatch, or cancelled request.
  static Future<void> errorBuzz() async {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }
}
