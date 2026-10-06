import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/jugaad_haptics.dart';
import '../screens/post_job/post_job_state.dart';

class RateCardItem {
  final String id;
  final String title;
  final String duration;
  final double price;
  final String categoryId;
  final String? note;

  const RateCardItem({
    required this.id,
    required this.title,
    required this.duration,
    required this.price,
    required this.categoryId,
    this.note,
  });
}

class RateCategory {
  final String id;
  final String title;
  final IconData icon;
  final Color color;

  const RateCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
  });
}

class RateCardCalculatorSheet extends ConsumerStatefulWidget {
  final String? initialCategory;

  const RateCardCalculatorSheet({
    super.key,
    this.initialCategory,
  });

  static Future<void> show(BuildContext context, {String? initialCategory}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RateCardCalculatorSheet(initialCategory: initialCategory),
    );
  }

  @override
  ConsumerState<RateCardCalculatorSheet> createState() => _RateCardCalculatorSheetState();
}

class _RateCardCalculatorSheetState extends ConsumerState<RateCardCalculatorSheet> {
  static const List<RateCategory> categories = [
    RateCategory(id: 'electrician', title: 'Electrician', icon: Icons.bolt_rounded, color: Color(0xFFEA580C)),
    RateCategory(id: 'plumber', title: 'Plumber', icon: Icons.water_drop_rounded, color: Color(0xFF2563EB)),
    RateCategory(id: 'ac_service', title: 'AC Service', icon: Icons.ac_unit_rounded, color: Color(0xFF0284C7)),
    RateCategory(id: 'carpenter', title: 'Carpenter', icon: Icons.carpenter_rounded, color: Color(0xFFD97706)),
    RateCategory(id: 'stove_repair', title: 'Stove Repair', icon: Icons.local_fire_department_rounded, color: Color(0xFFE11D48)),
    RateCategory(id: 'phone_repair', title: 'Phone Repair', icon: Icons.phone_android_rounded, color: Color(0xFF0D9488)),
    RateCategory(id: 'laptop_repair', title: 'Laptop Repair', icon: Icons.laptop_mac_rounded, color: Color(0xFF6366F1)),
  ];

  static const List<RateCardItem> allItems = [
    // Electrician
    RateCardItem(id: 'e1', title: 'Ceiling Fan Installation / Repair', duration: '20–30 min', price: 149, categoryId: 'electrician'),
    RateCardItem(id: 'e2', title: 'Switchboard / Socket Repair', duration: '15–20 min', price: 99, categoryId: 'electrician'),
    RateCardItem(id: 'e3', title: 'MCB / Fuse Tripping Fix', duration: '25 min', price: 199, categoryId: 'electrician'),
    RateCardItem(id: 'e4', title: 'Tubelight / Chandelier Fitting', duration: '20 min', price: 129, categoryId: 'electrician'),
    RateCardItem(id: 'e5', title: 'Complete Room Wiring Inspection', duration: '40 min', price: 299, categoryId: 'electrician'),

    // Plumber
    RateCardItem(id: 'p1', title: 'Water Tap / Faucet Replacement', duration: '20 min', price: 120, categoryId: 'plumber'),
    RateCardItem(id: 'p2', title: 'Pipe Leakage Joint Sealing', duration: '30 min', price: 180, categoryId: 'plumber'),
    RateCardItem(id: 'p3', title: 'Washbasin / Sink Drainage Clog', duration: '35 min', price: 240, categoryId: 'plumber'),
    RateCardItem(id: 'p4', title: 'Flush Tank Repair / Replacement', duration: '30 min', price: 219, categoryId: 'plumber'),
    RateCardItem(id: 'p5', title: 'Water Tank Float Valve Fitting', duration: '40 min', price: 299, categoryId: 'plumber'),

    // AC Service
    RateCardItem(id: 'a1', title: 'Filter & Foam Jet Deep Cleaning', duration: '45 min', price: 349, categoryId: 'ac_service'),
    RateCardItem(id: 'a2', title: 'AC Gas Pressure Check & Top-up', duration: '30 min', price: 499, categoryId: 'ac_service'),
    RateCardItem(id: 'a3', title: 'Water Leakage Drainage Fix', duration: '30 min', price: 299, categoryId: 'ac_service'),
    RateCardItem(id: 'a4', title: 'AC Installation / Dismantling', duration: '60 min', price: 699, categoryId: 'ac_service'),

    // Carpenter
    RateCardItem(id: 'c1', title: 'Door Lock / Mortise Latch Repair', duration: '30 min', price: 179, categoryId: 'carpenter'),
    RateCardItem(id: 'c2', title: 'Hinge / Door Alignment Adjustment', duration: '20 min', price: 99, categoryId: 'carpenter'),
    RateCardItem(id: 'c3', title: 'Curtain Rod / Wall Shelf Drill & Fit', duration: '25 min', price: 149, categoryId: 'carpenter'),
    RateCardItem(id: 'c4', title: 'Bed / Table Furniture Assembly', duration: '50 min', price: 399, categoryId: 'carpenter'),

    // Stove Repair
    RateCardItem(id: 's1', title: 'Burner Deep Descaling & Clean', duration: '25 min', price: 149, categoryId: 'stove_repair'),
    RateCardItem(id: 's2', title: 'Gas Valve / Knob Tightening', duration: '20 min', price: 129, categoryId: 'stove_repair'),
    RateCardItem(id: 's3', title: 'Safety Gas Hose Pipe Replacement', duration: '25 min', price: 199, categoryId: 'stove_repair'),

    // Phone Repair
    RateCardItem(id: 'ph1', title: 'Doorstep Screen Diagnosis', duration: '20 min', price: 149, categoryId: 'phone_repair'),
    RateCardItem(id: 'ph2', title: 'Battery Health Check & Testing', duration: '20 min', price: 99, categoryId: 'phone_repair'),
    RateCardItem(id: 'ph3', title: 'Charging Port Dust Cleaning & Fix', duration: '25 min', price: 179, categoryId: 'phone_repair'),

    // Laptop Repair
    RateCardItem(id: 'l1', title: 'Thermal Paste & Internal Fan Clean', duration: '40 min', price: 299, categoryId: 'laptop_repair'),
    RateCardItem(id: 'l2', title: 'OS Reinstall / Speed Optimization', duration: '45 min', price: 349, categoryId: 'laptop_repair'),
    RateCardItem(id: 'l3', title: 'RAM / SSD Upgrade Installation', duration: '30 min', price: 249, categoryId: 'laptop_repair'),
  ];

  late String _selectedCategory;
  final Map<String, int> _quantities = {};

  static const double kVisitingFee = 99.0;
  static const double kWaiverThreshold = 199.0;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'electrician';
  }

  double get _subtotal {
    double total = 0;
    _quantities.forEach((id, qty) {
      if (qty > 0) {
        final item = allItems.firstWhere((it) => it.id == id, orElse: () => allItems.first);
        total += item.price * qty;
      }
    });
    return total;
  }

  bool get _isVisitingFeeWaived => _subtotal >= kWaiverThreshold;

  double get _totalEstimated {
    if (_subtotal == 0) return kVisitingFee;
    return _subtotal + (_isVisitingFeeWaived ? 0 : kVisitingFee);
  }

  int get _totalSelectedItems {
    int count = 0;
    _quantities.forEach((_, qty) => count += qty);
    return count;
  }

  void _increment(String id) {
    HapticFeedback.lightImpact();
    setState(() {
      _quantities[id] = (_quantities[id] ?? 0) + 1;
    });
  }

  void _decrement(String id) {
    HapticFeedback.lightImpact();
    setState(() {
      final cur = _quantities[id] ?? 0;
      if (cur > 0) {
        _quantities[id] = cur - 1;
      }
    });
  }

  void _bookWithEstimate() {
    JugaadHaptics.selection();
    Navigator.of(context).pop();

    // Compile items into description
    final selectedDescriptions = <String>[];
    _quantities.forEach((id, qty) {
      if (qty > 0) {
        final item = allItems.firstWhere((it) => it.id == id);
        selectedDescriptions.add('${item.title} (x$qty)');
      }
    });

    final desc = selectedDescriptions.isNotEmpty
        ? 'Estimated Services: ${selectedDescriptions.join(", ")}'
        : 'Inspection & Repair for $_selectedCategory';

    // Store in post job state
    final skillName = _selectedCategory.replaceAll('_', ' ');
    ref.read(postJobProvider.notifier).setSkill(skillName);
    ref.read(postJobProvider.notifier).setDescription(desc);

    context.push('/user/post-job/step2');
  }

  @override
  Widget build(BuildContext context) {
    final currentCatItems = allItems.where((it) => it.categoryId == _selectedCategory).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, -6)),
            ],
          ),
          child: Column(
            children: [
              // ── DRAG HANDLE ──
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // ── HEADER ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Transparent Rate Card',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Text(
                                'Mysuru & BLR',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF059669),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Fixed price estimates • Zero doorstep bargaining',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),

              // ── CATEGORY TABS (HORIZONTAL SCROLL) ──
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = cat.id == _selectedCategory;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = cat.id);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF059669) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF059669).withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              cat.icon,
                              size: 16,
                              color: isSelected ? Colors.white : cat.color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              // ── MAIN CONTENT (ITEMS LIST) ──
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                  children: [
                    // ── VISITING FEE TRANSPARENCY NOTICE ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield_outlined, color: Color(0xFF059669), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Doorstep Diagnostic: ₹${kVisitingFee.toInt()}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF065F46),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF059669),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'WAIVED > ₹199',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'If your repair total is ₹199 or more, the visiting fee is 100% waived or adjusted in your final bill.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    color: const Color(0xFF047857),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── SECTION TITLE ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Standard Job Estimates',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Tap + to calculate',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ── ITEM CARDS ──
                    ...currentCatItems.map((item) {
                      final qty = _quantities[item.id] ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: qty > 0 ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                            width: qty > 0 ? 1.5 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF94A3B8)),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.duration,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '₹${item.price.toInt()}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Quantity Selector Stepper
                            Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: qty > 0 ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: qty > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (qty > 0) ...[
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      color: const Color(0xFF065F46),
                                      onPressed: () => _decrement(item.id),
                                    ),
                                    Text(
                                      '$qty',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF065F46),
                                      ),
                                    ),
                                  ],
                                  IconButton(
                                    icon: Icon(Icons.add, size: 16, color: qty > 0 ? const Color(0xFF065F46) : const Color(0xFF334155)),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    onPressed: () => _increment(item.id),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // ── BOTTOM ESTIMATE BAR (STICKY) ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _totalSelectedItems > 0
                                  ? '$_totalSelectedItems items selected'
                                  : 'Diagnostic Visit',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '₹${_totalEstimated.toInt()}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (_isVisitingFeeWaived)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Visit Fee Waived',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),

                        // Action Button
                        ElevatedButton(
                          onPressed: _bookWithEstimate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Book with Estimate',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
