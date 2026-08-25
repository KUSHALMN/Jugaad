import 'package:haptic_feedback/haptic_feedback.dart';

class JugaadHaptics {
  JugaadHaptics._();

  static Future<void> light()     => Haptics.vibrate(HapticsType.light);
  static Future<void> medium()    => Haptics.vibrate(HapticsType.medium);
  static Future<void> heavy()     => Haptics.vibrate(HapticsType.heavy);
  static Future<void> success()   => Haptics.vibrate(HapticsType.success);
  static Future<void> warning()   => Haptics.vibrate(HapticsType.warning);
  static Future<void> error()     => Haptics.vibrate(HapticsType.error);
  static Future<void> selection() => Haptics.vibrate(HapticsType.selection);
}
