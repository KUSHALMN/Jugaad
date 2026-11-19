import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sound and Haptic feedback service for on-field gig workers.
/// Provides audible and tactile cues for new job alerts, PIN verification
/// handshakes, and instant wallet payouts ("Soundbox" style feedback).
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  static const String _prefKeySoundEnabled = 'jugaad_worker_sound_cues_enabled';
  bool _isSoundEnabled = true;
  bool _isInitialized = false;

  bool get isSoundEnabled => _isSoundEnabled;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSoundEnabled = prefs.getBool(_prefKeySoundEnabled) ?? true;
      _isInitialized = true;
    } catch (e) {
      debugPrint('[SoundService] Init error: $e');
      _isInitialized = true;
    }
  }

  Future<void> toggleSound(bool enabled) async {
    _isSoundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeySoundEnabled, enabled);
    } catch (e) {
      debugPrint('[SoundService] Error saving sound preference: $e');
    }
  }

  /// Urgent attention chime for incoming new booking leads.
  /// Crucial for field workers on bikes or in noisy urban traffic.
  Future<void> playJobAlert() async {
    if (!_isSoundEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('[SoundService] Error playing job alert: $e');
    }
  }

  /// Pleasant confirmation chime when 4-digit PIN handshake succeeds.
  Future<void> playPinSuccess() async {
    if (!_isSoundEnabled) return;
    try {
      await HapticFeedback.selectionClick();
      await SystemSound.play(SystemSoundType.click);
      await Future.delayed(const Duration(milliseconds: 120));
      await HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('[SoundService] Error playing PIN success: $e');
    }
  }

  /// Reassuring security handshake chirp when Doorstep OTP matches
  /// or worker verified badge is validated.
  Future<void> playSecurityChirp() async {
    if (!_isSoundEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.click);
      await Future.delayed(const Duration(milliseconds: 90));
      await HapticFeedback.lightImpact();
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('[SoundService] Error playing security chirp: $e');
    }
  }

  /// Celebratory sound when worker completes milestone or levels up.
  Future<void> playMilestoneUnlocked() async {
    if (!_isSoundEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(milliseconds: 140));
      await HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('[SoundService] Error playing milestone unlocked: $e');
    }
  }

  /// Cash register celebratory cue when instant UPI cashout is executed.
  Future<void> playCashoutSuccess() async {
    if (!_isSoundEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.click);
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.selectionClick();
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('[SoundService] Error playing cashout cue: $e');
    }
  }

  /// High-priority SOS tone for emergency triggers.
  Future<void> playEmergencyAlert() async {
    try {
      await HapticFeedback.vibrate();
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      debugPrint('[SoundService] Error playing emergency alert: $e');
    }
  }
}
