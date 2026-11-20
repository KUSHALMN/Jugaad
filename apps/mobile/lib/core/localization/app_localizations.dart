import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';

/// Complete Multi-Language Localization System for Jugaad Mobile.
/// Supports Kannada (ಕನ್ನಡ), Hindi (हिंदी), and English.
class AppTranslations {
  final AppLanguage language;

  const AppTranslations(this.language);

  static AppTranslations of(AppLanguage lang) => AppTranslations(lang);

  bool get isKannada => language == AppLanguage.kannada;
  bool get isHindi => language == AppLanguage.hindi;
  bool get isEnglish => language == AppLanguage.english;

  // ── APP & NAVIGATION ──
  String get appTitle => 'Jugaad';
  String get home => isKannada ? 'ಮುಖಪುಟ' : (isHindi ? 'होम' : 'Home');
  String get bookings => isKannada ? 'ಬುಕಿಂಗ್‌ಗಳು' : (isHindi ? 'बुकिंग्स' : 'Bookings');
  String get earnings => isKannada ? 'ಸಂಪಾದನೆ' : (isHindi ? 'कमाई' : 'Earnings');
  String get profile => isKannada ? 'ಪ್ರೊಫೈಲ್' : (isHindi ? 'प्रोफ़ाइल' : 'Profile');
  String get search => isKannada ? 'ಹುಡುಕಿ' : (isHindi ? 'खोजें' : 'Search');
  String get cancel => isKannada ? 'ರದ್ದುಮಾಡಿ' : (isHindi ? 'रद्द करें' : 'Cancel');
  String get confirm => isKannada ? 'ಖಚಿತಪಡಿಸಿ' : (isHindi ? 'पुष्टि करें' : 'Confirm');
  String get close => isKannada ? 'ಮುಚ್ಚಿ' : (isHindi ? 'बंद करें' : 'Close');
  String get viewAll => isKannada ? 'ಎಲ್ಲವನ್ನೂ ವೀಕ್ಷಿಸಿ' : (isHindi ? 'सभी देखें' : 'View All');

  // ── USER HOME & DISCOVERY ──
  String get serviceLocation => isKannada ? 'ನಿಮ್ಮ ಸೇವಾ ಸ್ಥಳ' : (isHindi ? 'आपका सेवा स्थान' : 'Your Service Location');
  String get locationSubtitle => isKannada 
      ? 'ಕರ್ನಾಟಕದಾದ್ಯಂತ ಲೈವ್ ತಂತ್ರಜ್ಞರ ಲಭ್ಯತೆ' 
      : (isHindi ? 'कर्नाटक में लाइव कारीगरों की सेवा' : 'Live on-demand worker coverage across Karnataka');
  String get searchPlaceholder => isKannada 
      ? 'ಪ್ಲಂಬರ್, ಎಲೆಕ್ಟ್ರಿಷಿಯನ್, ಕಾರ್ಪೆಂಟರ್ ಹುಡುಕಿ...' 
      : (isHindi ? 'प्लंबर, इलेक्ट्रीशियन, बढ़ई खोजें...' : 'Search Plumber, Electrician, Carpenter...');
  String get voiceBookingTitle => isKannada 
      ? 'ಧ್ವನಿ ಬುಕಿಂಗ್ 🎙️' 
      : (isHindi ? 'बोलकर बुक करें 🎙️' : 'Bol Ke Book Karo 🎙️');
  String get voiceBookingSubtitle => isKannada 
      ? 'ಕನ್ನಡ, ಹಿಂದಿ ಅಥವಾ ಇಂಗ್ಲಿಷ್‌ನಲ್ಲಿ ಮಾತನಾಡಿ' 
      : (isHindi ? 'हिंदी, कन्नड़ या अंग्रेजी में बोलें' : 'Speak in Kannada, Hindi, or English');
  String get voiceListening => isKannada 
      ? 'ಆಲಿಸಲಾಗುತ್ತಿದೆ... ಈಗ ಮಾತನಾಡಿ' 
      : (isHindi ? 'सुन रहे हैं... अब बोलें' : 'Listening... Speak now');
  String get voiceTapToSpeak => isKannada 
      ? 'ಮಾತನಾಡಲು ಮೈಕ್ ಟ್ಯಾಪ್ ಮಾಡಿ' 
      : (isHindi ? 'बोलने के लिए माइक दबाएं' : 'Tap mic to speak');
  String get expressVisitBadge => isKannada 
      ? '⚡ 15-ನಿಮಿಷ ಎಕ್ಸ್‌ಪ್ರೆಸ್ ಭೇಟಿ' 
      : (isHindi ? '⚡ 15-मिनट एक्सप्रेस विज़िट' : '⚡ 15-MIN EXPRESS VISIT');
  String get popularSearches => isKannada 
      ? 'ಜನಪ್ರಿಯ ಸೇವೆಗಳು' 
      : (isHindi ? 'लोकप्रिय सेवाएं' : 'Popular Searches');
  String get recentSearches => isKannada 
      ? 'ಇತ್ತೀಚಿನ ಹುಡುಕಾಟಗಳು' 
      : (isHindi ? 'हाल की खोजें' : 'Recent Searches');
  String get clearAll => isKannada 
      ? 'ಎಲ್ಲ ಅಳಿಸಿ' 
      : (isHindi ? 'सभी हटाएं' : 'Clear All');
  String get confirmAndMatch => isKannada 
      ? 'ಖಚಿತಪಡಿಸಿ & ತಂತ್ರಜ್ಞರ ಬುಕ್ ಮಾಡಿ' 
      : (isHindi ? 'पुष्टि करें और कारीगर बुक करें' : 'Confirm & Match Technician');
  String get priceLockGuarantee => isKannada 
      ? '🔒 ಬೆಲೆ ಲಾಕ್ ಭರವಸೆ: ಒಟಿಪಿ ಅನುಮೋದನೆ ಇಲ್ಲದೆ ಹೆಚ್ಚುವರಿ ಶುಲ್ಕವಿಲ್ಲ' 
      : (isHindi ? '🔒 प्राइस लॉक गारंटी: ओटीपी मंजूरी के बिना अतिरिक्त चार्ज नहीं' : '🔒 Price Lock Guarantee: No extra charge without your OTP approval');
  String get maneTechnicianTitle => isKannada 
      ? 'ನನ್ನ ಟೆಕ್ನಿಷಿಯನ್' 
      : (isHindi ? 'मेरे पसंदीदा कारीगर' : 'Mane Technician');
  String get maneTechnicianSubtitle => isKannada 
      ? 'ನಿಮ್ಮ ಮನೆಗೆ ಬಂದಿದ್ದ ವಿಶ್ವಾಸಾರ್ಹ ಕೆಲಸಗಾರರನ್ನು 1-ಟ್ಯಾಪ್‌ನಲ್ಲಿ ಮರುಬುಕ್ ಮಾಡಿ' 
      : (isHindi ? 'घर पर काम कर चुके कारीगरों को 1-टैप में दोबारा बुक करें' : '1-Tap Rebook trusted technicians who serviced your home');
  String get rateCardCalculatorTitle => isKannada 
      ? 'ದರ ಪಟ್ಟಿ & ವೆಚ್ಚ ಕ್ಯಾಲ್ಕುಲೇಟರ್' 
      : (isHindi ? 'रेट कार्ड और लागत कैलकुलेटर' : 'Rate Card & Cost Calculator');
  String get doorstepRadarTitle => isKannada 
      ? 'ಬಾಗಿಲ ಲೈವ್ ರಾಡಾರ್' 
      : (isHindi ? 'डोरस्टेप लाइव रडार' : 'Doorstep Live Radar');
  String get storiesTrayTitle => isKannada 
      ? 'ಜುಗಾಡ್ ಕಥೆಗಳು' 
      : (isHindi ? 'जुगाड़ स्टोरीज़' : 'Jugaad Stories');
  String get storiesTraySubtitle => isKannada 
      ? '30-ಸೆಕೆಂಡ್ ವಿಡಿಯೋ ಡಯಾಗ್ನೋಸಿಸ್' 
      : (isHindi ? '30-सेकंड वीडियो डायग्नोसिस' : '30s Video Diagnosis');

  // ── CATEGORIES ──
  String get electrician => isKannada ? 'ಎಲೆಕ್ಟ್ರಿಷಿಯನ್' : (isHindi ? 'इलेक्ट्रीशियन' : 'Electrician');
  String get plumber => isKannada ? 'ಪ್ಲಂಬರ್' : (isHindi ? 'प्लंबर' : 'Plumber');
  String get carpenter => isKannada ? 'ಕಾರ್ಪೆಂಟರ್' : (isHindi ? 'बढ़ई' : 'Carpenter');
  String get painter => isKannada ? 'ಪೇಂಟರ್' : (isHindi ? 'पेंटर' : 'Painter');
  String get acService => isKannada ? 'ಎಸಿ ಸರ್ವಿಸ್' : (isHindi ? 'एसी सर्विस' : 'AC Service');
  String get cleaning => isKannada ? 'ಮನೆ ಸ್ವಚ್ಛತೆ' : (isHindi ? 'सफाई' : 'Home Cleaning');
  String get laptopRepair => isKannada ? 'ಲ್ಯಾಪ್ಟಾಪ್ ರಿಪೇರಿ' : (isHindi ? 'लैपटॉप रिपेयर' : 'Laptop Repair');
  String get phoneRepair => isKannada ? 'ಮೊಬೈಲ್ ರಿಪೇರಿ' : (isHindi ? 'मोबाइल रिपेयर' : 'Phone Repair');
  String get waterPurifier => isKannada ? 'ವಾಟರ್ ಪ್ಯೂರಿಫೈಯರ್' : (isHindi ? 'वाटर प्यूरीफायर' : 'Water Purifier (RO)');
  String get gasStove => isKannada ? 'ಗ್ಯಾಸ್ ಒಲೆ ರಿಪೇರಿ' : (isHindi ? 'गैस चूल्हा रिपेयर' : 'Stove Gas Repair');

  // ── SURAKSHA & SAFETY ──
  String get surakshaTitle => isKannada 
      ? 'ಜುಗಾಡ್ ಸುರಕ್ಷಾ ಕವಚ 🛡️' 
      : (isHindi ? 'जुगाड़ सुरक्षा शील्ड 🛡️' : 'Jugaad Suraksha Shield 🛡️');
  String get surakshaSubtitle => isKannada 
      ? '100% ಪರಿಶೀಲಿತ ಕೆಲಸಗಾರರು • ಕುಟುಂಬದ ಸುರಕ್ಷತಾ ಗ್ಯಾರಂಟಿ' 
      : (isHindi ? '100% सत्यापित पार्टनर • पारिवारिक सुरक्षा गारंटी' : '100% Verified Partner • Family Safety Guarantee');
  String get shareTripWhatsApp => isKannada 
      ? 'ವಾಟ್ಸಾಪ್‌ನಲ್ಲಿ ಲೈವ್ ಟ್ರಿಪ್ ಹಂಚಿಕೊಳ್ಳಿ' 
      : (isHindi ? 'व्हाट्सएप पर लाइव स्टेटस शेयर करें' : 'Share Live Trip on WhatsApp');
  String get emergencyPolice => isKannada ? 'ಪೊಲೀಸ್ ತುರ್ತು (112)' : (isHindi ? 'पुलिस आपातकाल (112)' : 'Police SOS (112)');
  String get safetyDesk => isKannada ? '24x7 ಸುರಕ್ಷತಾ ಡೆಸ್ಕ್' : (isHindi ? '24x7 सुरक्षा डेस्क' : '24x7 Safety Desk');

  // ── WARRANTY CARD ──
  String get warrantyTitle => isKannada 
      ? '30-ದಿನಗಳ ಸೇವಾ ವಾರಂಟಿ ಕಾರ್ಡ್' 
      : (isHindi ? '30-दिनों का सर्विस वारंटी कार्ड' : '30-Day Workmanship Warranty Card');
  String get downloadWarranty => isKannada 
      ? 'ವಾರಂಟಿ ಕಾರ್ಡ್ ಡೌನ್‌ಲೋಡ್ ಮಾಡಿ' 
      : (isHindi ? 'वारंटी कार्ड डाउनलोड करें' : 'Download Warranty Card');

  // ── SPARE PARTS & MATERIAL ESCROW ──
  String get sparePartsTitle => isKannada 
      ? 'ಬಿಡಿಭಾಗಗಳ ಅಧಿಕೃತ ಕೋಟೇಶನ್ & ಎಂಆರ್‌ಪಿ ಸ್ಲಿಪ್' 
      : (isHindi ? 'स्पेयर पार्ट्स डिजिटल कोटेशन और एमआरपी बिल' : 'Spare Parts & Material Quotation');
  String get mrpProofGuarantee => isKannada 
      ? 'ಅಂಗಡಿ ಎಂಆರ್‌ಪಿ ರಶೀದಿ ಗ್ಯಾರಂಟಿ: 1 ರೂಪಾಯಿ ಹೆಚ್ಚುವರಿ ಶುಲ್ಕವಿಲ್ಲ' 
      : (isHindi ? 'दुकान एमआरपी रसीद गारंटी: ₹1 भी अतिरिक्त शुल्क नहीं' : 'Store MRP Slip Guarantee: Zero hidden markup');
  String get viewStoreBill => isKannada 
      ? 'ಅಂಗಡಿಯ ಬಿಲ್ & ಎಂಆರ್‌ಪಿ ಪರಿಶೀಲಿಸಿ ↗' 
      : (isHindi ? 'दुकान की रसीद और एमआरपी जांचें ↗' : 'Inspect Store Bill & MRP ↗');
  String get approveMaterialEscrow => isKannada 
      ? 'ಬಿಡಿಭಾಗವನ್ನು ಅನುಮೋದಿಸಿ & ಬಿಲ್‌ಗೆ ಸೇರಿಸಿ' 
      : (isHindi ? 'सामग्री मंजूर करें और बिल में जोड़ें' : 'Approve & Lock into Digital Bill');
  String get declineMaterialEscrow => isKannada 
      ? 'ತಿರಸ್ಕರಿಸಿ' 
      : (isHindi ? 'अस्वीकार करें' : 'Decline');
  String get zeroMarkupAssurance => isKannada 
      ? '100% ವೆಚ್ಚ ಪಾಸ್‌-ಥ್ರೂ: ತಂತ್ರಜ್ಞರಿಗೆ ಅಂಗಡಿಯ ನಿಖರ ಮೊತ್ತವನ್ನು ಪಾವತಿಸಲಾಗುತ್ತದೆ' 
      : (isHindi ? '100% लागत पास-थ्रू: तकनीशियन को दुकान की सटीक कीमत मिलती है' : '100% Cost Pass-Through: Reimbursed at exact store cost');
  String get snapStoreBill => isKannada 
      ? '📸 ಅಂಗಡಿ ಬಿಲ್ ಫೋಟೋ ತೆಗೆಯಿರಿ' 
      : (isHindi ? '📸 दुकान बिल की फोटो खींचें' : '📸 Snap Store Bill / MRP Proof');

  // ── WORKER INTERFACE ──
  String get dutyOnline => isKannada 
      ? 'ಆನ್‌ಲೈನ್ · ಕೆಲಸಗಳನ್ನು ಸ್ವೀಕರಿಸಲಾಗುತ್ತಿದೆ' 
      : (isHindi ? 'ऑनलाइन · नए काम उपलब्ध' : 'Online · Receiving Requests');
  String get dutyOffline => isKannada 
      ? 'ಡ್ಯೂಟಿ ವಿರಾಮ · ಆಫ್‌ಲೈನ್' 
      : (isHindi ? 'ड्यूटी बंद · ऑफलाइन' : 'Duty Paused · Offline');
  String get streakBadge => isKannada ? '🔥 5-ದಿನಗಳ ಸ್ಟ್ರೀಕ್' : (isHindi ? '🔥 5-दिनों की स्ट्रीक' : '🔥 5-Day Streak');
  String get goldMasterTier => isKannada 
      ? '🥇 ಗೋಲ್ಡ್ ಮಾಸ್ಟರ್ ಪ್ರೊ' 
      : (isHindi ? '🥇 गोल्ड मास्टर प्रो' : '🥇 Gold Master Pro');
  String get zeroCommissionClub => isKannada 
      ? 'ಶೂನ್ಯ ಕಮಿಷನ್ ಕ್ಲಬ್: 100% ಗಳಿಕೆಯನ್ನು ಇರಿಸಿಕೊಳ್ಳಿ' 
      : (isHindi ? 'जीरो कमीशन क्लब: 100% कमाई आपकी' : 'Zero Commission Club: Keep 100% earnings');
  String get instantDailyCashout => isKannada 
      ? 'ತಕ್ಷಣದ ಯುಪಿಐ ವರ್ಗಾವಣೆ' 
      : (isHindi ? 'तुरंत यूपीआई ट्रांसफर' : 'Instant Transfer to UPI');
  String get sunlightOutdoorMode => isKannada 
      ? '☀️ ಬಿಸಿಲು ಮೋಡ್' 
      : (isHindi ? '☀️ आउटडोर मोड' : '☀️ Outdoor Mode');
  String get slideToAccept => isKannada 
      ? 'ಸ್ವೀಕರಿಸಲು ಸ್ಲೈಡ್ ಮಾಡಿ  ➔' 
      : (isHindi ? 'स्वीकार करने के लिए स्लाइड करें  ➔' : 'SLIDE TO ACCEPT  ➔');
  String get slideToStartWork => isKannada 
      ? 'ಕೆಲಸ ಪ್ರಾರಂಭಿಸಲು ಸ್ಲೈಡ್ ಮಾಡಿ  ➔' 
      : (isHindi ? 'काम शुरू करने के लिए स्लाइड करें  ➔' : 'SLIDE TO START WORK  ➔');
  String get slideToComplete => isKannada 
      ? 'ಕೆಲಸ ಮುಗಿಸಿ ಒಟಿಪಿ ಪಡೆಯಿರಿ  ➔' 
      : (isHindi ? 'काम पूरा कर ओटीपी मांगें  ➔' : 'SLIDE TO COMPLETE & REQUEST OTP  ➔');

  // ── DOORSTEP HANDSHAKE & SPARE PARTS ──
  String get doorstepHandshake => isKannada 
      ? 'ಬಾಗಿಲ ಭದ್ರತಾ ಪರಿಶೀಲನೆ' 
      : (isHindi ? 'डोरस्टेप सुरक्षा सत्यापन' : 'Doorstep Security Handshake');
  String get enterCustomerPin => isKannada 
      ? '4-ಅಂಕಿಯ ಗ್ರಾಹಕ ಪಿನ್ ನಮೂದಿಸಿ' 
      : (isHindi ? '4-अंकों का ग्राहक पिन दर्ज करें' : 'Enter 4-Digit Customer PIN');
  String get sparePartsQuotationTitle => isKannada 
      ? 'ಬಿಡಿಭಾಗಗಳು & ಸಾಮಗ್ರಿಗಳ ಬಿಲ್' 
      : (isHindi ? 'स्पेयर पार्ट्स और सामग्री कोटेशन' : 'Spare Parts & Material Quotation');
  String get customerApproved => isKannada 
      ? '✅ ಗ್ರಾಹಕರು ಅನುಮೋದಿಸಿದ್ದಾರೆ' 
      : (isHindi ? '✅ ग्राहक द्वारा स्वीकृत' : '✅ Customer Approved');
  String get pendingApproval => isKannada 
      ? '⏳ ಗ್ರಾಹಕರ ಅನುಮೋದನೆಗೆ ಬಾಕಿ ಇದೆ' 
      : (isHindi ? '⏳ ग्राहक की मंजूरी लंबित' : '⏳ Pending Customer Approval');
  String get sendQuoteToCustomer => isKannada 
      ? 'ಗ್ರಾಹಕರಿಗೆ ಡಿಜಿಟಲ್ ಬಿಲ್ ಕಳುಹಿಸಿ' 
      : (isHindi ? 'ग्राहक को डिजिटल कोटेशन भेजें' : 'Send Digital Quote to Customer');

  // ── GREETINGS ──
  String greeting(int hour) {
    if (isKannada) {
      if (hour >= 5 && hour < 12) return 'ಶುಭೋದಯ ';
      if (hour >= 12 && hour < 17) return 'ಶುಭ ಮಧ್ಯಾಹ್ನ ';
      if (hour >= 17 && hour < 22) return 'ಶುಭ ಸಂಜೆ ';
      return 'ಶುಭ ರಾತ್ರಿ ';
    } else if (isHindi) {
      if (hour >= 5 && hour < 12) return 'सुप्रभात ';
      if (hour >= 12 && hour < 17) return 'शुभ दोपहर ';
      if (hour >= 17 && hour < 22) return 'शुभ संध्या ';
      return 'शुभ रात्रि ';
    } else {
      if (hour >= 5 && hour < 12) return 'Good morning ';
      if (hour >= 12 && hour < 17) return 'Good afternoon ';
      if (hour >= 17 && hour < 22) return 'Good evening ';
      return 'Good night ';
    }
  }
}

/// Centralized Riverpod Provider for AppTranslations
final translationsProvider = Provider<AppTranslations>((ref) {
  final lang = ref.watch(localeProvider);
  return AppTranslations.of(lang);
});
