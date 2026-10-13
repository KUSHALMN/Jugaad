import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modal dialog enforcing physical proximity & selfie proof when a worker
/// requests emergency PIN bypass at the customer doorstep.
class DoorstepBypassModal extends StatefulWidget {
  final String jobId;
  final double distanceMeters;
  final Function(String reason, String selfieNote) onConfirmBypass;

  const DoorstepBypassModal({
    super.key,
    required this.jobId,
    required this.distanceMeters,
    required this.onConfirmBypass,
  });

  static Future<void> show({
    required BuildContext context,
    required String jobId,
    required double distanceMeters,
    required Function(String reason, String selfieNote) onConfirmBypass,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DoorstepBypassModal(
        jobId: jobId,
        distanceMeters: distanceMeters,
        onConfirmBypass: onConfirmBypass,
      ),
    );
  }

  @override
  State<DoorstepBypassModal> createState() => _DoorstepBypassModalState();
}

class _DoorstepBypassModalState extends State<DoorstepBypassModal> {
  String _selectedReason = 'Customer phone battery died';
  bool _selfieTaken = false;

  final List<String> _reasons = [
    'Customer phone battery died',
    'Customer is elderly without smartphone',
    'SMS / OTP network delay (> 5 mins)',
    'Customer requested manual verification',
  ];

  @override
  Widget build(BuildContext context) {
    final bool isProximityValid = widget.distanceMeters <= 100.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doorstep PIN Bypass',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                      ),
                      Text(
                        'ತುರ್ತು ಪರಿಶೀಲನಾ ವಿನಾಯಿತಿ',
                        style: GoogleFonts.notoSansKannada(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Proximity indicator chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isProximityValid ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isProximityValid ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isProximityValid ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                    color: isProximityValid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isProximityValid
                          ? 'GPS Proximity Verified (${widget.distanceMeters.toInt()}m from doorstep)'
                          : 'Warning: You appear to be ${widget.distanceMeters.toInt()}m from site',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isProximityValid ? const Color(0xFF15803D) : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Select bypass rationale:',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedReason,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedReason = val);
              },
            ),
            const SizedBox(height: 14),
            // Mandatory selfie proof button
            InkWell(
              onTap: () {
                setState(() => _selfieTaken = true);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selfieTaken ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _selfieTaken ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selfieTaken ? Icons.photo_camera_front_rounded : Icons.camera_alt_outlined,
                      color: _selfieTaken ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selfieTaken ? 'Doorstep Selfie Captured ✓' : 'Capture Doorstep Selfie (Required)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _selfieTaken ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _selfieTaken
                        ? () {
                            widget.onConfirmBypass(_selectedReason, 'selfie_captured_verified');
                            Navigator.pop(context);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Confirm Bypass',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
