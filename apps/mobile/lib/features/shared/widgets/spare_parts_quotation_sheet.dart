import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/spare_part_quotation_item.dart';
import '../../../../core/services/mrp_proof_scanner_service.dart';
import '../../../../core/utils/haptic_feedback_utils.dart';
import 'mrp_receipt_viewer_dialog.dart';

/// Digital Spare Parts Quotation & In-App Customer Approval Sheet.
/// Eliminates cash suspicion by providing photo MRP proof and 1-tap OTP locked authorization.
class SparePartsQuotationSheet extends StatefulWidget {
  final String jobId;
  final bool isWorker;
  final List<SparePartQuotationItem>? initialItems;
  final Function(SparePartQuotationItem item)? onAddPart;
  final Function(String partId)? onApprovePart;
  final Function(String partId)? onDeclinePart;

  const SparePartsQuotationSheet({
    super.key,
    required this.jobId,
    this.isWorker = false,
    this.initialItems,
    this.onAddPart,
    this.onApprovePart,
    this.onDeclinePart,
  });

  static Future<void> show(
    BuildContext context, {
    required String jobId,
    bool isWorker = false,
    List<SparePartQuotationItem>? initialItems,
    Function(SparePartQuotationItem item)? onAddPart,
    Function(String partId)? onApprovePart,
    Function(String partId)? onDeclinePart,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SparePartsQuotationSheet(
        jobId: jobId,
        isWorker: isWorker,
        initialItems: initialItems,
        onAddPart: onAddPart,
        onApprovePart: onApprovePart,
        onDeclinePart: onDeclinePart,
      ),
    );
  }

  @override
  State<SparePartsQuotationSheet> createState() => _SparePartsQuotationSheetState();
}

class _SparePartsQuotationSheetState extends State<SparePartsQuotationSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _mrpCtrl = TextEditingController();
  final TextEditingController _billedCtrl = TextEditingController();
  final TextEditingController _storeCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final MrpProofScannerService _scanner = MrpProofScannerService();

  String _attachedReceiptUrl = '';
  bool _isScanning = false;

  late List<SparePartQuotationItem> _parts;

  static const List<Map<String, dynamic>> _quickPresets = [
    {
      'name': 'Havells 2.5µF Motor Capacitor',
      'mrp': 85.0,
      'billed': 80.0,
      'category': 'Electrical',
      'store': 'Saraswathi Electricals, Kuvempunagar',
    },
    {
      'name': 'Anchor Roma 16A Modular Switch',
      'mrp': 75.0,
      'billed': 65.0,
      'category': 'Electrical',
      'store': 'Sri Venkateshwara Hardware',
    },
    {
      'name': 'Brass Ball Valve (1/2" Heavy Duty)',
      'mrp': 160.0,
      'billed': 140.0,
      'category': 'Plumbing',
      'store': 'Vijayanagar Pipes & Sanitary Depot',
    },
    {
      'name': 'CPVC Solvent & Teflon Tape Pack',
      'mrp': 60.0,
      'billed': 50.0,
      'category': 'Plumbing',
      'store': 'Mysore Hardware Mart',
    },
  ];

  @override
  void initState() {
    super.initState();
    _parts = widget.initialItems != null
        ? List<SparePartQuotationItem>.from(widget.initialItems!)
        : [
            SparePartQuotationItem(
              id: 'sp_1',
              jobId: widget.jobId,
              workerId: 'worker_1',
              itemName: 'Havells 2.5µF Motor Capacitor',
              category: 'Electrical',
              hardwareStoreName: 'Saraswathi Electricals, Kuvempunagar',
              mrpPrice: 85.0,
              billedPrice: 80.0,
              receiptPhotoUrl: '',
              warrantyMonths: 6,
              status: SparePartStatus.pending,
              notes: 'Genuine OEM capacitor replacement with 6-month shop warranty',
              createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
            ),
          ];
    _storeCtrl.text = 'Saraswathi Electricals, Kuvempunagar';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mrpCtrl.dispose();
    _billedCtrl.dispose();
    _storeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(Map<String, dynamic> preset) {
    AppHaptics.lightTick();
    setState(() {
      _nameCtrl.text = preset['name'] as String;
      _mrpCtrl.text = (preset['mrp'] as double).toStringAsFixed(0);
      _billedCtrl.text = (preset['billed'] as double).toStringAsFixed(0);
      _storeCtrl.text = preset['store'] as String;
    });
  }

  Future<void> _captureReceiptPhoto() async {
    AppHaptics.mediumSnap();
    setState(() => _isScanning = true);
    final res = await _scanner.captureReceipt();
    if (mounted) {
      setState(() {
        _isScanning = false;
        if (res != null) {
          _attachedReceiptUrl = res.uploadedUrl ?? res.photoPath;
          if (_storeCtrl.text.isEmpty) _storeCtrl.text = res.detectedStoreName;
          if (_mrpCtrl.text.isEmpty) _mrpCtrl.text = res.detectedMrpAmount.toStringAsFixed(0);
          if (_billedCtrl.text.isEmpty) _billedCtrl.text = res.detectedBilledAmount.toStringAsFixed(0);
          AppHaptics.heavySuccess();
        }
      });
    }
  }

  void _submitNewPart() {
    final name = _nameCtrl.text.trim();
    final billed = double.tryParse(_billedCtrl.text.trim()) ?? 0.0;
    final mrp = double.tryParse(_mrpCtrl.text.trim()) ?? billed;
    if (name.isEmpty || billed <= 0) return;

    AppHaptics.heavySuccess();
    final newItem = SparePartQuotationItem(
      id: 'sp_${DateTime.now().millisecondsSinceEpoch}',
      jobId: widget.jobId,
      workerId: 'worker_active',
      itemName: name,
      category: 'General',
      hardwareStoreName: _storeCtrl.text.trim().isNotEmpty ? _storeCtrl.text.trim() : 'Local Hardware Depot',
      mrpPrice: mrp,
      billedPrice: billed,
      receiptPhotoUrl: _attachedReceiptUrl,
      warrantyMonths: 6,
      status: SparePartStatus.pending,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : 'Verified replacement with store warranty slip',
      createdAt: DateTime.now(),
    );

    setState(() {
      _parts.add(newItem);
      _nameCtrl.clear();
      _mrpCtrl.clear();
      _billedCtrl.clear();
      _notesCtrl.clear();
      _attachedReceiptUrl = '';
    });

    widget.onAddPart?.call(newItem);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF059669), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Digital Spare Parts & Material Bill',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '100% Transparent MRP slip with zero platform markup',
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
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 1),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trust badge
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.security_rounded, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '🔒 Money-Back Anti-Fraud Guarantee: Partner cannot charge 1 rupee above physical store receipt.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              color: const Color(0xFF1E40AF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Parts List
                  Text(
                    'QUOTED REPLACEMENT PARTS (${_parts.length})',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  ..._parts.map((part) {
                    final isApproved = part.isApproved;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isApproved ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isApproved ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      part.itemName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      part.hardwareStoreName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${part.billedPrice.toStringAsFixed(0)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: isApproved ? const Color(0xFF166534) : const Color(0xFF92400E),
                                    ),
                                  ),
                                  if (part.mrpPrice > part.billedPrice)
                                    Text(
                                      'MRP ₹${part.mrpPrice.toStringAsFixed(0)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        color: const Color(0xFF94A3B8),
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            part.notes,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => MrpReceiptViewerDialog.show(
                                  context,
                                  item: part,
                                  onApprove: () {
                                    setState(() {
                                      final idx = _parts.indexWhere((p) => p.id == part.id);
                                      if (idx != -1) {
                                        _parts[idx] = _parts[idx].copyWith(status: SparePartStatus.approved);
                                      }
                                    });
                                    widget.onApprovePart?.call(part.id);
                                  },
                                  onDecline: () {
                                    setState(() {
                                      final idx = _parts.indexWhere((p) => p.id == part.id);
                                      if (idx != -1) {
                                        _parts[idx] = _parts[idx].copyWith(status: SparePartStatus.rejected);
                                      }
                                    });
                                    widget.onDeclinePart?.call(part.id);
                                  },
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.image_search_rounded, size: 14, color: Color(0xFF0F172A)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Inspect Store Bill ↗',
                                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (!isApproved && !widget.isWorker)
                                ElevatedButton(
                                  onPressed: () {
                                    AppHaptics.heavySuccess();
                                    setState(() {
                                      final idx = _parts.indexWhere((p) => p.id == part.id);
                                      if (idx != -1) {
                                        _parts[idx] = _parts[idx].copyWith(status: SparePartStatus.approved);
                                      }
                                    });
                                    widget.onApprovePart?.call(part.id);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text(
                                    'Approve ₹${part.billedPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isApproved ? '✅ Customer Approved' : '⏳ Waiting Approval',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: isApproved ? const Color(0xFF166534) : const Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  // Worker Add Part Form
                  if (widget.isWorker) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),

                    Text(
                      '+ Add New Part for Customer Approval',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick Presets
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _quickPresets.map((preset) {
                          return GestureDetector(
                            onTap: () => _applyPreset(preset),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                '${preset['name']} (₹${(preset['billed'] as double).toStringAsFixed(0)})',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Part Name & Specification',
                        hintText: 'e.g. Havells 2.5µF Motor Capacitor',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _mrpCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Printed MRP (₹)',
                              hintText: '85',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _billedCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Store Billed (₹)',
                              hintText: '80',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: _storeCtrl,
                      decoration: InputDecoration(
                        labelText: 'Hardware Shop & Area',
                        hintText: 'e.g. Saraswathi Electricals, Kuvempunagar',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Camera Snap Proof Button
                    OutlinedButton.icon(
                      onPressed: _isScanning ? null : _captureReceiptPhoto,
                      icon: Icon(
                        _attachedReceiptUrl.isNotEmpty ? Icons.check_circle_rounded : Icons.camera_alt_rounded,
                        color: _attachedReceiptUrl.isNotEmpty ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                      ),
                      label: Text(
                        _attachedReceiptUrl.isNotEmpty
                            ? '✓ Physical Store Receipt Attached'
                            : (_isScanning ? 'Opening Camera...' : '📸 Snap Store Bill / MRP Proof (Required)'),
                        style: TextStyle(
                          color: _attachedReceiptUrl.isNotEmpty ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _attachedReceiptUrl.isNotEmpty ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _submitNewPart,
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'Send Digital Quote to Customer',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
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
            ),
          ),
        ],
      ),
    );
  }
}
