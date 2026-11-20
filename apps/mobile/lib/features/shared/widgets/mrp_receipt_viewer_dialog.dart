import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/spare_part_quotation_item.dart';
import '../../../../core/utils/haptic_feedback_utils.dart';

/// Full-screen interactive pinch-to-zoom MRP receipt inspection modal.
/// Homeowners can inspect the store's physical bill, printed MRP, shop stamp, and item serial number.
class MrpReceiptViewerDialog extends StatelessWidget {
  final SparePartQuotationItem item;
  final VoidCallback? onApprove;
  final VoidCallback? onDecline;
  final bool showActionButtons;

  const MrpReceiptViewerDialog({
    super.key,
    required this.item,
    this.onApprove,
    this.onDecline,
    this.showActionButtons = true,
  });

  static Future<void> show(
    BuildContext context, {
    required SparePartQuotationItem item,
    VoidCallback? onApprove,
    VoidCallback? onDecline,
    bool showActionButtons = true,
  }) {
    AppHaptics.lightTick();
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => MrpReceiptViewerDialog(
        item: item,
        onApprove: onApprove,
        onDecline: onDecline,
        showActionButtons: showActionButtons,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF334155), width: 1.5),
        ),
        child: Column(
          children: [
            // Header bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          item.hardwareStoreName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      AppHaptics.lightTick();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF334155), height: 1),

            // Zoomable receipt viewport
            Expanded(
              child: Container(
                color: Colors.black,
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: item.receiptPhotoUrl.isNotEmpty && item.receiptPhotoUrl.startsWith('http')
                        ? Image.network(
                            item.receiptPhotoUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _buildPlaceholderReceipt(),
                          )
                        : _buildPlaceholderReceipt(),
                  ),
                ),
              ),
            ),

            // Financial & audit breakdown card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Printed MRP',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              '₹${item.mrpPrice.toStringAsFixed(0)}',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFCBD5E1),
                                fontSize: 13,
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Save ₹${item.savingsAmount.toStringAsFixed(0)}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF10B981),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Zero Platform Fee',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF64748B),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Billed Amount',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              '₹${item.billedPrice.toStringAsFixed(0)}',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFF59E0B),
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (showActionButtons && item.isPending) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              AppHaptics.mediumSnap();
                              Navigator.of(context).pop();
                              onDecline?.call();
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFEF4444)),
                              foregroundColor: const Color(0xFFEF4444),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Decline Quote', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              AppHaptics.heavySuccess();
                              Navigator.of(context).pop();
                              onApprove?.call();
                            },
                            icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                            label: Text(
                              'Approve ₹${item.billedPrice.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: item.isApproved
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.isApproved
                            ? '✅ Verified & Locked into Digital Bill'
                            : '❌ Spare Part Reimbursement Declined',
                        style: TextStyle(
                          color: item.isApproved ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderReceipt() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              item.hardwareStoreName.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.sourceCodePro(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: const Color(0xFF78350F),
              ),
            ),
          ),
          const Center(child: Text('TAX INVOICE / CASH BILL', style: TextStyle(fontSize: 10, color: Color(0xFF92400E)))),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFD97706), thickness: 0.8),
          Text('Item: ${item.itemName}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF78350F))),
          Text('Printed MRP: ₹${item.mrpPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Color(0xFF92400E))),
          Text('Net Billed: ₹${item.billedPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
          Text('Warranty: ${item.warrantyMonths} Months Mfr Warranty', style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          const Divider(color: Color(0xFFD97706), thickness: 0.8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text('Audit: ${item.auditSignature.substring(0, 8)}', style: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF)), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 4),
              const Flexible(child: Text('VERIFIED ✓', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF059669)), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ],
      ),
    );
  }
}
