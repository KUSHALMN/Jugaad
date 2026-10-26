import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RateCardItem {
  final String id;
  final String title;
  final String titleKannada;
  final double price;
  final String skill;

  const RateCardItem({
    required this.id,
    required this.title,
    required this.titleKannada,
    required this.price,
    required this.skill,
  });
}

/// Standardized trade repair rate card designed to eliminate doorstep bargaining
/// and prevent off-app cash leakage in Tier-2/3 Indian markets.
class DigitalRateCardSheet extends StatefulWidget {
  final String skill;
  final double visitingFee;
  final Function(List<RateCardItem> selectedItems, double totalAmount) onConfirm;

  const DigitalRateCardSheet({
    super.key,
    required this.skill,
    this.visitingFee = 99.0,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required String skill,
    double visitingFee = 99.0,
    required Function(List<RateCardItem>, double) onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DigitalRateCardSheet(
        skill: skill,
        visitingFee: visitingFee,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<DigitalRateCardSheet> createState() => _DigitalRateCardSheetState();
}

class _DigitalRateCardSheetState extends State<DigitalRateCardSheet> {
  final Set<String> _selectedIds = {};

  final List<RateCardItem> _catalog = const [
    RateCardItem(id: 'sw_rep', title: 'Switch / Socket Replacement', titleKannada: 'ಸ್ವಿಚ್ ಬದಲಿ', price: 49, skill: 'electrician'),
    RateCardItem(id: 'fan_cap', title: 'Ceiling Fan Capacitor / Wiring', titleKannada: 'ಫ್ಯಾನ್ ಕೆಪಾಸಿಟರ್', price: 149, skill: 'electrician'),
    RateCardItem(id: 'mcb_fix', title: 'MCB / Fuse Box Repair', titleKannada: 'ಎಂಸಿಬಿ ರಿಪೇರಿ', price: 199, skill: 'electrician'),
    RateCardItem(id: 'tap_wash', title: 'Tap Leak / Washer Fix', titleKannada: 'ನಲ್ಲಿ ಸೋರಿಕೆ ಸರಿಪಡಿಸುವುದು', price: 79, skill: 'plumber'),
    RateCardItem(id: 'drain_unc', title: 'Sink / Drain Unclogging', titleKannada: 'ಸಿಂಕ್ ತೆರವುಗೊಳಿಸುವಿಕೆ', price: 129, skill: 'plumber'),
    RateCardItem(id: 'flush_rep', title: 'Toilet Flush Tank Overhaul', titleKannada: 'ಫ್ಲಶ್ ಟ್ಯಾಂಕ್ ದುರಸ್ತಿ', price: 189, skill: 'plumber'),
    RateCardItem(id: 'phone_scr', title: 'Screen Cleaning & Flex Fit', titleKannada: 'ಸ್ಕ್ರೀನ್ ಫ್ಲೆಕ್ಸ್ ಫಿಟ್ಟಿಂಗ್', price: 149, skill: 'phone_repair'),
    RateCardItem(id: 'phone_mic', title: 'Speaker / Mic Dust Extraction', titleKannada: 'ಸ್ಪೀಕರ್ / ಮೈಕ್ ಸ್ವಚ್ಛತೆ', price: 99, skill: 'phone_repair'),
    RateCardItem(id: 'lap_dust', title: 'Laptop Thermal Paste & De-dust', titleKannada: 'ಲ್ಯಾಪ್ಟಾಪ್ ಕ್ಲೀನಿಂಗ್', price: 299, skill: 'laptop_repair'),
    RateCardItem(id: 'ac_filter', title: 'AC Filter Deep Clean & Wash', titleKannada: 'ಎಸಿ ಫಿಲ್ಟರ್ ವಾಶ್', price: 249, skill: 'ac_service'),
  ];

  List<RateCardItem> get _relevantItems {
    final lower = widget.skill.toLowerCase();
    final items = _catalog.where((i) => i.skill.toLowerCase() == lower).toList();
    return items.isNotEmpty ? items : _catalog.take(6).toList();
  }

  double get _totalAmount {
    double sum = widget.visitingFee;
    for (var item in _catalog) {
      if (_selectedIds.contains(item.id)) {
        sum += item.price;
      }
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Standard Rate Card',
                    style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                  ),
                  Text(
                    'ಅಧಿಕೃತ ಸೇವಾ ದರ ಪಟ್ಟಿ',
                    style: GoogleFonts.notoSansKannada(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  'Base: ₹${widget.visitingFee.toInt()}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _relevantItems.length,
              separatorBuilder: (_, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _relevantItems[index];
                final isSelected = _selectedIds.contains(item.id);
                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedIds.remove(item.id);
                      } else {
                        _selectedIds.add(item.id);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                              ),
                              Text(
                                item.titleKannada,
                                style: GoogleFonts.notoSansKannada(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+₹${item.price.toInt()}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL REVISED PRICE',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 0.5),
                    ),
                    Text(
                      '₹${_totalAmount.toInt()}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    final selected = _catalog.where((i) => _selectedIds.contains(i.id)).toList();
                    widget.onConfirm(selected, _totalAmount);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Request Customer OTP',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
