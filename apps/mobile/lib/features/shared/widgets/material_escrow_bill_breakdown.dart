import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/spare_part_quotation_item.dart';
import 'voice_briefing_pill.dart';

/// Transparent dual-tier digital invoice breakdown widget.
/// Distinctly separates platform labor charges from 100% cost pass-through spare parts escrow.
class MaterialEscrowBillBreakdown extends StatelessWidget {
  final double serviceLaborAmount;
  final List<SparePartQuotationItem> approvedParts;
  final double platformFee;
  final double discount;
  final bool isAnimated;

  const MaterialEscrowBillBreakdown({
    super.key,
    required this.serviceLaborAmount,
    required this.approvedParts,
    this.platformFee = 0.0,
    this.discount = 0.0,
    this.isAnimated = true,
  });

  double get totalPartsAmount => approvedParts.fold(0.0, (sum, p) => sum + p.billedPrice);
  double get totalMrpAmount => approvedParts.fold(0.0, (sum, p) => sum + p.mrpPrice);
  double get totalSavings => (totalMrpAmount > totalPartsAmount) ? (totalMrpAmount - totalPartsAmount) : 0.0;
  double get grandTotal => (serviceLaborAmount + totalPartsAmount + platformFee - discount).clamp(0.0, double.infinity);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_rounded, color: Color(0xFF16A34A), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Digital Bill & Material Escrow',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '100% AUDITED',
                  style: TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Service / Labor Fee
          _buildRow('Labor & Doorstep Inspection', '₹${serviceLaborAmount.toStringAsFixed(0)}'),
          const SizedBox(height: 8),

          // 2. Material Parts Escrow Breakdown
          if (approvedParts.isNotEmpty) ...[
            const Divider(color: Color(0xFFF1F5F9), height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.build_circle_outlined, size: 14, color: Color(0xFF047857)),
                    const SizedBox(width: 4),
                    Text(
                      'Materials & Parts (${approvedParts.length} verified)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹${totalPartsAmount.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF047857),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Indented parts list
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Column(
                children: approvedParts.map((part) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '• ${part.itemName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Text(
                          '₹${part.billedPrice.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          if (platformFee > 0) ...[
            const SizedBox(height: 8),
            _buildRow('Platform Fee', '₹${platformFee.toStringAsFixed(0)}'),
          ],

          if (discount > 0) ...[
            const SizedBox(height: 8),
            _buildRow('Promotional Discount', '-₹${discount.toStringAsFixed(0)}', isDiscount: true),
          ],

          const Divider(color: Color(0xFFE2E8F0), height: 20),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Payable',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                '₹${grandTotal.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF059669),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          // Audio-Assisted Voice Briefing ("Keli Thiliri" / "Sunke Samjho")
          VoiceBriefingPill(
            totalAmount: grandTotal.round(),
            hasVerifiedParts: approvedParts.isNotEmpty,
            isAnimated: isAnimated,
          ),

          // Savings banner if MRP discount present
          if (totalSavings > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings_rounded, size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Text(
                    'You saved ₹${totalSavings.toStringAsFixed(0)} below printed shop MRP!',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          // Zero Markup Trust Guarantee
          Row(
            children: const [
              Icon(Icons.lock_rounded, size: 12, color: Color(0xFF94A3B8)),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  '100% Cost Pass-Through: Technician is reimbursed exact store price without platform cuts.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), height: 1.2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isDiscount ? const Color(0xFF16A34A) : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
