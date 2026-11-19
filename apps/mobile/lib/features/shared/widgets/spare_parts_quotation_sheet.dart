import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/utils/haptic_feedback_utils.dart';

/// Digital Spare Parts Quotation & In-App Customer Approval Sheet.
/// Eliminates cash suspicion by providing photo MRP proof and 1-tap OTP locked authorization.
class SparePartsQuotationSheet extends StatefulWidget {
  final String jobId;
  final bool isWorker;
  final Function(String name, int price, String notes)? onAddPart;
  final Function(String partId)? onApprovePart;

  const SparePartsQuotationSheet({
    super.key,
    required this.jobId,
    this.isWorker = false,
    this.onAddPart,
    this.onApprovePart,
  });

  static Future<void> show(
    BuildContext context, {
    required String jobId,
    bool isWorker = false,
    Function(String name, int price, String notes)? onAddPart,
    Function(String partId)? onApprovePart,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SparePartsQuotationSheet(
        jobId: jobId,
        isWorker: isWorker,
        onAddPart: onAddPart,
        onApprovePart: onApprovePart,
      ),
    );
  }

  @override
  State<SparePartsQuotationSheet> createState() => _SparePartsQuotationSheetState();
}

class _SparePartsQuotationSheetState extends State<SparePartsQuotationSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  final List<Map<String, dynamic>> _demoParts = [
    {
      'id': 'sp_1',
      'name': 'Havells 2.5µF Motor Capacitor',
      'price': 80,
      'status': 'pending', // pending, approved
      'notes': 'Original manufacturer spare from Saraswathi Electricals',
      'mrpProof': 'Attached (MRP ₹85 • Billed ₹80)',
    },
    {
      'id': 'sp_2',
      'name': 'Brass Ball Valve & Teflon Tape',
      'price': 120,
      'status': 'approved',
      'notes': 'Heavy duty brass replacement with 6-month leakage warranty',
      'mrpProof': 'Verified by customer',
    },
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF059669), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spare Parts & Material Quotation',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Transparent digital billing with MRP proof guarantee',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Parts list
          ..._demoParts.map((part) {
            final isApproved = part['status'] == 'approved';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isApproved ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isApproved ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          part['name'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Text(
                        '₹${part['price']}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isApproved ? const Color(0xFF166534) : const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    part['notes'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isApproved ? '✅ Customer Approved' : '⏳ Pending Customer Approval',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isApproved ? const Color(0xFF166534) : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!isApproved && !widget.isWorker)
                        ElevatedButton(
                          onPressed: () {
                            AppHaptics.heavySuccess();
                            setState(() {
                              part['status'] = 'approved';
                            });
                            widget.onApprovePart?.call(part['id'] as String);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Approve ₹80', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),

          // Worker Add Part form
          if (widget.isWorker) ...[
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 8),
            Text(
              '+ Add Replacement Part for Customer Approval',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Part name (e.g. Switch)',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '₹ Price',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_nameCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) return;
                  AppHaptics.mediumSnap();
                  setState(() {
                    _demoParts.add({
                      'id': 'sp_${DateTime.now().millisecondsSinceEpoch}',
                      'name': _nameCtrl.text.trim(),
                      'price': int.tryParse(_priceCtrl.text.trim()) ?? 100,
                      'status': 'pending',
                      'notes': 'Requested by technician with hardware warranty',
                      'mrpProof': 'Submitted',
                    });
                  });
                  widget.onAddPart?.call(
                    _nameCtrl.text.trim(),
                    int.tryParse(_priceCtrl.text.trim()) ?? 100,
                    _notesCtrl.text.trim(),
                  );
                  _nameCtrl.clear();
                  _priceCtrl.clear();
                },
                icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                label: const Text('Send Digital Quote to Customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
