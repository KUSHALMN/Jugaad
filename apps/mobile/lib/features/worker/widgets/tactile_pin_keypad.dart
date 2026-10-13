import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tactile 4-Box PIN Doorstep Handshake Keypad.
/// Eliminates clumsy system keyboards on doorstep arrival.
class TactilePinKeypad extends StatefulWidget {
  final String title;
  final String subtitle;
  final Function(String pin) onPinCompleted;
  final VoidCallback? onCancel;

  const TactilePinKeypad({
    super.key,
    this.title = 'Enter Doorstep PIN',
    this.subtitle = 'Ask the customer for their 4-digit arrival PIN',
    required this.onPinCompleted,
    this.onCancel,
  });

  static Future<String?> show({
    required BuildContext context,
    String title = 'Enter Doorstep PIN',
    String subtitle = 'Ask the customer for their 4-digit arrival PIN',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TactilePinKeypad(
        title: title,
        subtitle: subtitle,
        onPinCompleted: (pin) => Navigator.pop(ctx, pin),
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  State<TactilePinKeypad> createState() => _TactilePinKeypadState();
}

class _TactilePinKeypadState extends State<TactilePinKeypad> {
  String _enteredPin = '';

  void _onKeyPress(String val) {
    if (_enteredPin.length >= 4) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _enteredPin += val;
    });

    if (_enteredPin.length == 4) {
      HapticFeedback.heavyImpact();
      widget.onPinCompleted(_enteredPin);
    }
  }

  void _onDelete() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          Text(
            widget.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 24),

          // 4-Box PIN Input Cells (60x60px)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < _enteredPin.length;
              final digit = isFilled ? _enteredPin[index] : '';

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 58,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isFilled ? const Color(0xFF1E293B) : const Color(0xFF1E293B).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isFilled ? const Color(0xFF3B82F6) : const Color(0xFF334155),
                    width: 2,
                  ),
                ),
                child: Text(
                  digit,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),

          // Dedicated 3x4 Numeric Keypad
          _buildKeypad(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'DEL'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 74, height: 56);
              }
              if (key == 'DEL') {
                return InkWell(
                  onTap: _onDelete,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 74,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.backspace_outlined, color: Color(0xFF94A3B8), size: 22),
                  ),
                );
              }
              return InkWell(
                onTap: () => _onKeyPress(key),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 74,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    key,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
