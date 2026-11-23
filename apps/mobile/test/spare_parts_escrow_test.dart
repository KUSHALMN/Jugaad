import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jugaad_mvp/core/models/spare_part_quotation_item.dart';
import 'package:jugaad_mvp/core/services/mrp_proof_scanner_service.dart';
import 'package:jugaad_mvp/core/localization/app_localizations.dart';
import 'package:jugaad_mvp/core/providers/locale_provider.dart';
import 'package:jugaad_mvp/features/shared/widgets/material_escrow_bill_breakdown.dart';
import 'package:jugaad_mvp/features/shared/widgets/mrp_receipt_viewer_dialog.dart';
import 'package:jugaad_mvp/features/shared/widgets/spare_parts_quotation_sheet.dart';
import 'package:jugaad_mvp/features/user/widgets/spare_part_otp_approval_sheet.dart';

void main() {
  group('Spare Parts Escrow Model & Calculation Tests', () {
    test('SparePartQuotationItem correctly computes MRP savings & audit signature', () {
      final item = SparePartQuotationItem(
        id: 'sp_test_101',
        jobId: 'job_456',
        workerId: 'worker_789',
        itemName: 'Havells 2.5µF Motor Capacitor',
        mrpPrice: 85.0,
        billedPrice: 80.0,
        receiptPhotoUrl: 'https://example.com/receipt.jpg',
        createdAt: DateTime(2026, 11, 20, 10, 0, 0),
      );

      expect(item.savingsAmount, 5.0);
      expect(item.savingsPercentage, closeTo(5.88, 0.01));
      expect(item.isPending, isTrue);
      expect(item.isApproved, isFalse);
      expect(item.auditSignature.length, 16);

      final json = item.toJson();
      expect(json['id'], 'sp_test_101');
      expect(json['amount'], 80.0);
      expect(json['mrp_price'], 85.0);

      final fromJson = SparePartQuotationItem.fromJson(json);
      expect(fromJson.itemName, 'Havells 2.5µF Motor Capacitor');
      expect(fromJson.billedPrice, 80.0);
    });

    test('SparePartStatus state transitions', () {
      expect(SparePartStatus.fromString('approved'), SparePartStatus.approved);
      expect(SparePartStatus.fromString('declined'), SparePartStatus.rejected);
      expect(SparePartStatus.fromString('rejected'), SparePartStatus.rejected);
      expect(SparePartStatus.fromString('pending'), SparePartStatus.pending);
      expect(SparePartStatus.fromString(null), SparePartStatus.pending);
    });

    test('MrpProofScannerService contains verified Karnataka hardware store directory', () {
      expect(MrpProofScannerService.verifiedHardwarePartners.isNotEmpty, isTrue);
      final first = MrpProofScannerService.verifiedHardwarePartners.first;
      expect(first['name'], contains('Saraswathi Electricals'));
      expect(first['area'], contains('Mysuru'));
    });
  });

  group('Spare Parts Escrow Multilingual Localization Tests', () {
    test('Verifies Kannada, Hindi, and English spare parts translations', () {
      final kn = AppTranslations.of(AppLanguage.kannada);
      expect(kn.sparePartsTitle, contains('ಬಿಡಿಭಾಗಗಳ'));
      expect(kn.mrpProofGuarantee, contains('ಎಂಆರ್‌ಪಿ ರಶೀದಿ'));
      expect(kn.viewStoreBill, contains('ಅಂಗಡಿಯ ಬಿಲ್'));
      expect(kn.approveMaterialEscrow, contains('ಅನುಮೋದಿಸಿ'));

      final hi = AppTranslations.of(AppLanguage.hindi);
      expect(hi.sparePartsTitle, contains('स्पेयर पार्ट्स'));
      expect(hi.mrpProofGuarantee, contains('एमआरपी रसीद'));
      expect(hi.viewStoreBill, contains('दुकान की रसीद'));
      expect(hi.approveMaterialEscrow, contains('मंजूर करें'));

      final en = AppTranslations.of(AppLanguage.english);
      expect(en.sparePartsTitle, 'Spare Parts & Material Quotation');
      expect(en.mrpProofGuarantee, contains('Zero hidden markup'));
    });
  });

  group('Spare Parts Widget & UI Tests', () {
    final samplePart = SparePartQuotationItem(
      id: 'sp_1',
      jobId: 'job_test',
      workerId: 'worker_test',
      itemName: 'Havells 2.5µF Capacitor',
      hardwareStoreName: 'Saraswathi Electricals',
      mrpPrice: 85.0,
      billedPrice: 80.0,
      receiptPhotoUrl: '',
      createdAt: DateTime.now(),
    );

    testWidgets('MaterialEscrowBillBreakdown renders labor and pass-through parts cleanly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MaterialEscrowBillBreakdown(
                  serviceLaborAmount: 199.0,
                  approvedParts: [samplePart],
                  discount: 20.0,
                  isAnimated: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Digital Bill & Material Escrow'), findsOneWidget);
      expect(find.text('₹199'), findsOneWidget);
      expect(find.text('• Havells 2.5µF Capacitor'), findsOneWidget);
      expect(find.text('₹259'), findsOneWidget); // 199 + 80 - 20 = 259
      expect(find.text('You saved ₹5 below printed shop MRP!'), findsOneWidget);
    });

    testWidgets('MrpReceiptViewerDialog renders full-screen bill modal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MrpReceiptViewerDialog(
              item: samplePart,
              showActionButtons: true,
            ),
          ),
        ),
      );

      expect(find.text('Havells 2.5µF Capacitor'), findsOneWidget);
      expect(find.text('Saraswathi Electricals'), findsOneWidget);
      expect(find.text('₹85'), findsOneWidget);
      expect(find.text('₹80'), findsOneWidget);
      expect(find.text('Approve ₹80'), findsOneWidget);
    });

    testWidgets('SparePartsQuotationSheet displays itemized list and presets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SparePartsQuotationSheet(
              jobId: 'job_test_1',
              isWorker: false,
              initialItems: [samplePart],
            ),
          ),
        ),
      );

      expect(find.text('Digital Spare Parts & Material Bill'), findsOneWidget);
      expect(find.text('QUOTED REPLACEMENT PARTS (1)'), findsOneWidget);
      expect(find.text('Inspect Store Bill ↗'), findsOneWidget);
    });

    testWidgets('SparePartOtpApprovalSheet displays 4-digit PIN shield', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SparePartOtpApprovalSheet(
              item: samplePart,
              onVerified: () {},
            ),
          ),
        ),
      );

      expect(find.text('Secure Material Escrow Approval'), findsOneWidget);
      expect(find.text('Authorizing ₹80 for Havells 2.5µF Capacitor'), findsOneWidget);
      expect(find.text('Enter Approval PIN: 7429'), findsOneWidget);
    });
  });
}
