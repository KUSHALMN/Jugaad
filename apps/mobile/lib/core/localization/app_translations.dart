import 'app_locale.dart';

/// Multilingual dictionary providing translations for English, Kannada, Hindi, and Tamil.
class AppTranslations {
  static final Map<AppLanguage, Map<String, String>> _localizedValues = {
    AppLanguage.english: {
      'app_name': 'Jugaad',
      'tagline': 'Hyperlocal On-Demand Skill Marketplace',
      'search_service': 'Search services, plumbers, electricians...',
      'emergency_title': 'Instant Emergency Dispatch',
      'emergency_subtitle': 'Verified trade expert at your doorstep in < 15 mins',
      'book_emergency': 'Book Emergency Now',
      'our_services': 'Our Services',
      'view_all': 'View All',
      'workers_nearby': 'Workers Nearby',
      'no_workers_found': 'No workers found in this radius',
      'recent_bookings': 'Recent Bookings',
      
      // Trade Categories
      'cat_electrician': 'Electrician',
      'cat_plumber': 'Plumber',
      'cat_carpenter': 'Carpenter',
      'cat_ac_repair': 'AC & Appliance',
      'cat_painter': 'House Painter',
      'cat_cleaner': 'Home Cleaning',
      'cat_mechanic': 'Auto Mechanic',

      // Worker Interface
      'worker_dashboard': 'Provider Dashboard',
      'status_online': 'Online & Receiving Jobs',
      'status_offline': 'Offline (Take a break)',
      'earnings_today': 'Today\'s Earnings',
      'completed_jobs': 'Completed Jobs',
      'incoming_request': 'Incoming Job Request',
      'accept_job': 'Accept Job',
      'decline_job': 'Pass / Decline',
      'confirm_on_the_way': 'Confirm I\'m On My Way',
      'slide_arrived': 'Slide to mark arrived →',
      'slide_completed': 'Slide to mark completed →',
      'job_in_progress': 'Job In Progress',
      'customer_call': 'Call Customer',
      'request_price_change': 'Request Price Change',
      
      // Offline Resilience
      'offline_banner_title': 'Offline Mode Active',
      'offline_banner_desc': 'Action saved locally. Will sync automatically.',
      'sync_now': 'Sync Now',

      // Audio Prompts
      'audio_job_incoming': 'New job available nearby! Tap to view.',
      'audio_job_accepted': 'Job accepted. Drive safely to location.',
      'audio_arrived': 'Arrival recorded. Please inspect the site.',
      'audio_completed': 'Job completed successfully! Payment incoming.',
    },

    AppLanguage.kannada: {
      'app_name': 'ಜುಗಾಡ್',
      'tagline': 'ಸ್ಥಳೀಯ ನುರಿತ ಕುಶಲಕರ್ಮಿಗಳ ವೇದಿಕೆ',
      'search_service': 'ಪ್ಲಂಬರ್, ಎಲೆಕ್ಟ್ರಿಷಿಯನ್ ಸೇವೆಗಳನ್ನು ಹುಡುಕಿ...',
      'emergency_title': 'ತ್ವರಿತ ತುರ್ತು ಸೇವಾ ನಿಯೋಜನೆ',
      'emergency_subtitle': '15 ನಿಮಿಷಗಳಲ್ಲಿ ನಿಮ್ಮ ಮನೆಬಾಗಿಲಿಗೆ ಪರಿಶೀಲಿತ ಕುಶಲಕರ್ಮಿ',
      'book_emergency': 'ತುರ್ತು ಸೇವೆ ಬುಕ್ ಮಾಡಿ',
      'our_services': 'ನಮ್ಮ ಸೇವೆಗಳು',
      'view_all': 'ಎಲ್ಲವನ್ನೂ ವೀಕ್ಷಿಸಿ',
      'workers_nearby': 'ಹತ್ತಿರದ ಕುಶಲಕರ್ಮಿಗಳು',
      'no_workers_found': 'ಈ ವ್ಯಾಪ್ತಿಯಲ್ಲಿ ಕೆಲಸಗಾರರು ಲಭ್ಯವಿಲ್ಲ',
      'recent_bookings': 'ಇತ್ತೀಚಿನ ಬುಕಿಂಗ್‌ಗಳು',

      // Trade Categories
      'cat_electrician': 'ಎಲೆಕ್ಟ್ರಿಷಿಯನ್',
      'cat_plumber': 'ಪ್ಲಂಬರ್',
      'cat_carpenter': 'ಬಡಗಿ / ಕಾರ್ಪೆಂಟರ್',
      'cat_ac_repair': 'ಎಸಿ ಮತ್ತು ಉಪಕರಣ ದುರಸ್ತಿ',
      'cat_painter': 'ಮನೆ ಪೇಂಟರ್',
      'cat_cleaner': 'ಮನೆ ಸ್ವಚ್ಛತೆ',
      'cat_mechanic': 'ಮೆಕ್ಯಾನಿಕ್',

      // Worker Interface
      'worker_dashboard': 'ಕೆಲಸಗಾರರ ಡ್ಯಾಶ್‌ಬೋರ್ಡ್',
      'status_online': 'ಆನ್‌ಲೈನ್ (ಕೆಲಸ ಸ್ವೀಕರಿಸಲು ಸಿದ್ಧ)',
      'status_offline': 'ಆಫ್‌ಲೈನ್',
      'earnings_today': 'ಇಂದಿನ ಸಂಪಾದನೆ',
      'completed_jobs': 'ಪೂರ್ಣಗೊಂಡ ಕೆಲಸಗಳು',
      'incoming_request': 'ಹೊಸ ಕೆಲಸದ ವಿನಂತಿ ಬಂದಿದೆ',
      'accept_job': 'ಕೆಲಸ ಸ್ವೀಕರಿಸಿ',
      'decline_job': 'ತಿರಸ್ಕರಿಸಿ',
      'confirm_on_the_way': 'ಹೊರಟಿದ್ದೇನೆ ಎಂದು ದೃಢೀಕರಿಸಿ',
      'slide_arrived': 'ತಲುಪಿದ್ದೇನೆ ಎಂದು ಸ್ಲೈಡ್ ಮಾಡಿ →',
      'slide_completed': 'ಕೆಲಸ ಮುಗಿದಿದೆ ಎಂದು ಸ್ಲೈಡ್ ಮಾಡಿ →',
      'job_in_progress': 'ಕೆಲಸ ಪ್ರಗತಿಯಲ್ಲಿದೆ',
      'customer_call': 'ಗ್ರಾಹಕರಿಗೆ ಕರೆ ಮಾಡಿ',
      'request_price_change': 'ದರ ಬದಲಾವಣೆಗೆ ವಿನಂತಿಸಿ',

      // Offline Resilience
      'offline_banner_title': 'ಆಫ್‌ಲೈನ್ ಮೋಡ್ ಸಕ್ರಿಯವಾಗಿದೆ',
      'offline_banner_desc': 'ಮಾಹಿತಿ ಸುರಕ್ಷಿತವಾಗಿದೆ. ನೆಟ್‌ವರ್ಕ್ ಬಂದಾಗ ಸಿಂಕ್ ಆಗುತ್ತದೆ.',
      'sync_now': 'ಈಗ ಸಿಂಕ್ ಮಾಡಿ',

      // Audio Prompts
      'audio_job_incoming': 'ಹೊಸ ಕೆಲಸ ಬಂದಿದೆ! ವೀಕ್ಷಿಸಲು ಟ್ಯಾಪ್ ಮಾಡಿ.',
      'audio_job_accepted': 'ಕೆಲಸ ಸ್ವೀಕರಿಸಲಾಗಿದೆ. ಜಾಗರೂಕರಾಗಿ ಚಾಲನೆ ಮಾಡಿ.',
      'audio_arrived': 'ಸ್ಥಳಕ್ಕೆ ತಲುಪಿದ್ದೀರಿ. ಕೆಲಸ ಪರಿಶೀಲಿಸಿ.',
      'audio_completed': 'ಕೆಲಸ ಯಶಸ್ವಿಯಾಗಿ ಪೂರ್ಣಗೊಂಡಿದೆ! ಹಣ ಜಮೆಯಾಗಲಿದೆ.',
    },

    AppLanguage.hindi: {
      'app_name': 'जुगाड़',
      'tagline': 'हाइपरलोकल ऑन-डिमांड सर्विस मार्केटप्लेस',
      'search_service': 'प्लंबर, इलेक्ट्रीशियन, बढ़ई खोजें...',
      'emergency_title': 'त्वरित आपातकालीन सेवा',
      'emergency_subtitle': '15 मिनट के अंदर सत्यापित कारीगर आपके द्वार पर',
      'book_emergency': 'तत्काल इमरजेंसी बुक करें',
      'our_services': 'हमारी सेवाएं',
      'view_all': 'सभी देखें',
      'workers_nearby': 'आस-पास के कारीगर',
      'no_workers_found': 'इस क्षेत्र में कोई कारीगर उपलब्ध नहीं है',
      'recent_bookings': 'हाल की बुकिंग',

      // Trade Categories
      'cat_electrician': 'इलेक्ट्रीशियन',
      'cat_plumber': 'प्लंबर',
      'cat_carpenter': 'बढ़ई / कारपेंटर',
      'cat_ac_repair': 'एसी व उपकरण मरम्मत',
      'cat_painter': 'घर का पेंटर',
      'cat_cleaner': 'घर की सफाई',
      'cat_mechanic': 'ऑटो मैकेनिक',

      // Worker Interface
      'worker_dashboard': 'कारीगर डैशबोर्ड',
      'status_online': 'ऑनलाइन (काम के लिए उपलब्ध)',
      'status_offline': 'ऑफलाइन',
      'earnings_today': 'आज की कमाई',
      'completed_jobs': 'पूरे किए गए काम',
      'incoming_request': 'नया काम उपलब्ध है',
      'accept_job': 'काम स्वीकार करें',
      'decline_job': 'अस्वीकार करें',
      'confirm_on_the_way': 'पुष्टि करें कि आप निकल चुके हैं',
      'slide_arrived': 'पहुंचने की पुष्टि के लिए स्लाइड करें →',
      'slide_completed': 'काम पूरा करने के लिए स्लाइड करें →',
      'job_in_progress': 'काम जारी है',
      'customer_call': 'ग्राहक को कॉल करें',
      'request_price_change': 'कीमत बदलने का अनुरोध करें',

      // Offline Resilience
      'offline_banner_title': 'ऑफलाइन मोड सक्रिय है',
      'offline_banner_desc': 'बदलाव सुरक्षित हैं। इंटरनेट मिलते ही सिंक हो जाएंगे।',
      'sync_now': 'अभी सिंक करें',

      // Audio Prompts
      'audio_job_incoming': 'नया काम उपलब्ध है! देखने के लिए टैप करें।',
      'audio_job_accepted': 'काम स्वीकार हुआ। ध्यान से स्थान पर पहुंचे।',
      'audio_arrived': 'आप पहुंच चुके हैं। कार्यस्थल का निरीक्षण करें।',
      'audio_completed': 'काम सफलतापूर्वक पूरा हुआ! भुगतान प्राप्त होगा।',
    },

    AppLanguage.tamil: {
      'app_name': 'ஜுகாட்',
      'tagline': 'உங்கள் பகுதிக்கான விரைவு சேவை தளம்',
      'search_service': 'பிளம்பர், எலக்ட்ரீஷியன் சேவைகளைத் தேடுங்கள்...',
      'emergency_title': 'அவசர உடனடி சேவை',
      'emergency_subtitle': '15 நிமிடங்களில் சரிபார்க்கப்பட்ட தொழிலாளி உங்கள் இல்லத்தில்',
      'book_emergency': 'உடனடி சேவை பதிவு செய்க',
      'our_services': 'எங்கள் சேவைகள்',
      'view_all': 'அனைத்தும் பார்க்க',
      'workers_nearby': 'அருகிலுள்ள தொழிலாளர்கள்',
      'no_workers_found': 'இப்பகுதியில் தொழிலாளர்கள் கிடைக்கவில்லை',
      'recent_bookings': 'சமீபத்திய முன்பதிவுகள்',

      // Trade Categories
      'cat_electrician': 'எலக்ட்ரீஷியன்',
      'cat_plumber': 'பிளம்பர்',
      'cat_carpenter': 'தச்சர் / கார்பெண்டர்',
      'cat_ac_repair': 'ஏசி & உபகரண பழுது',
      'cat_painter': 'வர்ணம் பூசுபவர்',
      'cat_cleaner': 'வீட்டு சுத்தம்',
      'cat_mechanic': 'வாகன மெக்கானிக்',

      // Worker Interface
      'worker_dashboard': 'தொழிலாளர் டாஷ்போர்டு',
      'status_online': 'ஆன்லைன் (வேலை பெற தயார்)',
      'status_offline': 'ஆஃப்லைன்',
      'earnings_today': 'இன்றைய வருமானம்',
      'completed_jobs': 'முடித்த வேலைகள்',
      'incoming_request': 'புதிய வேலை வாய்ப்பு',
      'accept_job': 'ஏற்றுக்கொள்',
      'decline_job': 'நிராகரி',
      'confirm_on_the_way': 'கிளம்பிவிட்டேன் என உறுதி செய்',
      'slide_arrived': 'வந்துவிட்டேன் என ஸ்லைடு செய் →',
      'slide_completed': 'வேலை முடிந்தது என ஸ்லைடு செய் →',
      'job_in_progress': 'வேலை நடக்கிறது',
      'customer_call': 'வாடிக்கையாளரை அழைக்கவும்',
      'request_price_change': 'கட்டண மாற்றம் கோரிக்கை',

      // Offline Resilience
      'offline_banner_title': 'ஆஃப்லைன் பயன்முறை செயலில் உள்ளது',
      'offline_banner_desc': 'தகவல்கள் சேமிக்கப்பட்டுள்ளன. இணையம் வந்ததும் பதிவேற்றப்படும்.',
      'sync_now': 'இப்போது பதிவேற்று',

      // Audio Prompts
      'audio_job_incoming': 'புதிய வேலை வந்துள்ளது! பார்க்க தட்டவும்.',
      'audio_job_accepted': 'வேலை ஏற்றுக்கொள்ளப்பட்டது. பாதுகாப்பாக செல்லவும்.',
      'audio_arrived': 'இடத்திற்கு வந்துவிட்டீர்கள். பணியை ஆய்வு செய்க.',
      'audio_completed': 'பணி வெற்றிகரமாக முடிந்தது! பணம் பெறப்படும்.',
    },
  };

  /// Translate key according to specified language with English fallback.
  static String get(String key, {AppLanguage language = AppLanguage.english}) {
    final langMap = _localizedValues[language] ?? _localizedValues[AppLanguage.english]!;
    return langMap[key] ?? _localizedValues[AppLanguage.english]?[key] ?? key;
  }
}
