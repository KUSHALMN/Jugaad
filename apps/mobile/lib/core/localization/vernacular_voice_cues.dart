import 'app_locale.dart';

/// Spoken voice prompts and vernacular audio cues for blue-collar gig workers
/// driving in noisy traffic conditions without looking at the screen.
class VernacularVoiceCues {
  static final Map<AppLanguage, Map<String, String>> _cues = {
    AppLanguage.kannada: {
      'job_alert': 'ಹೊಸ ಗ್ರಾಹಕರ ಕರೆ ಬಂದಿದೆ! ಪರಿಶೀಲಿಸಿ.',
      'job_accepted': 'ಬುಕಿಂಗ್ ದೃಢೀಕರಿಸಲಾಗಿದೆ. ಸುರಕ್ಷಿತವಾಗಿ ಚಾಲನೆ ಮಾಡಿ.',
      'arrived_doorstep': 'ಗ್ರಾಹಕರ ಮನೆ ತಲುಪಿದ್ದೀರಿ. ಪ್ರಾರಂಭದ ಪಿನ್ ಕೇಳಿ.',
      'pin_verified': 'ಪಿನ್ ದೃಢೀಕರಿಸಲಾಗಿದೆ. ಕೆಲಸ ಪ್ರಾರಂಭಿಸಿ.',
      'navigation_started': 'ಮಾರ್ಗಸೂಚಿ ಪ್ರಾರಂಭವಾಗಿದೆ. ಸುರಕ್ಷಿತವಾಗಿ ಚಾಲನೆ ಮಾಡಿ.',
      'work_completed': 'ಕೆಲಸ ಪೂರ್ಣಗೊಂಡಿದೆ. ತಪಾಸಣಾ ಪಿನ್ ನಮೂದಿಸಿ.',
      'payout_settled': 'ಹಣ ನಿಮ್ಮ ಬ್ಯಾಂಕ್ ಖಾತೆಗೆ ಜಮೆಯಾಗಿದೆ! ಧನ್ಯವಾದಗಳು.',
      'job_cancelled': 'ಗ್ರಾಹಕರು ಬುಕಿಂಗ್ ರದ್ದುಗೊಳಿಸಿದ್ದಾರೆ.',
    },
    AppLanguage.hindi: {
      'job_alert': 'नया काम उपलब्ध है! स्वीकार करने के लिए टैप करें।',
      'job_accepted': 'बुकिंग कन्फर्म हो गई है। ग्राहक के पते पर जाएं।',
      'arrived_doorstep': 'आप ग्राहक के पते पर पहुंच गए हैं। स्टार्ट पिन दर्ज करें।',
      'pin_verified': 'पिन सत्यापित हो गया है। काम शुरू करें।',
      'navigation_started': 'नेविगेशन शुरू हो गया है। सुरक्षित ड्राइव करें।',
      'work_completed': 'काम पूरा हो गया है। कस्टमर से कम्प्लीशन पिन लें।',
      'payout_settled': 'भुगतान आपके खाते में जमा हो गया है! बधाई हो।',
      'job_cancelled': 'ग्राहक द्वारा बुकिंग रद्द कर दी गई है।',
    },
    AppLanguage.tamil: {
      'job_alert': 'புதிய வேலை வாய்ப்பு வந்துள்ளது! ஏற்க தட்டவும்.',
      'job_accepted': 'வேலை உறுதி செய்யப்பட்டது. முகவரிக்கு செல்லவும்.',
      'arrived_doorstep': 'நீங்கள் இருப்பிடத்தை அடைந்துவிட்டீர்கள். பின் குறியீட்டை உள்ளிடவும்.',
      'pin_verified': 'பின் சரிபார்க்கப்பட்டது. வேலையைத் தொடங்குங்கள்.',
      'navigation_started': 'வழிசெலுத்தல் தொடங்கப்பட்டது. பாதுகாப்பாக ஓட்டுங்கள்.',
      'work_completed': 'வேலை வெற்றிகரமாக முடிந்தது.',
      'payout_settled': 'பணம் உங்கள் கணக்கில் வரவு வைக்கப்பட்டது!',
      'job_cancelled': 'வாடிக்கையாளர் முன்பதிவை ரத்து செய்துவிட்டார்.',
    },
    AppLanguage.english: {
      'job_alert': 'New job available nearby! Tap to view.',
      'job_accepted': 'Job accepted. Drive safely to customer location.',
      'arrived_doorstep': 'You have arrived. Ask customer for 4-digit start PIN.',
      'pin_verified': 'PIN verified successfully. You may begin the work.',
      'navigation_started': 'Navigation started. Follow route to destination.',
      'work_completed': 'Work complete. Ask customer for 4-digit completion PIN.',
      'payout_settled': 'Payment deposited to your bank account! Great job.',
      'job_cancelled': 'Job cancelled by customer. Return to standby mode.',
    },
  };

  /// Retrieves the spoken cue for the current language.
  static String getPrompt(String cueKey, AppLanguage lang) {
    return _cues[lang]?[cueKey] ?? _cues[AppLanguage.english]?[cueKey] ?? '';
  }
}
