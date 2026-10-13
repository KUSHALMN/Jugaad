import 'app_locale.dart';

/// Spoken voice prompts and vernacular audio cues for blue-collar gig workers
/// driving in noisy traffic conditions without looking at the screen.
class VernacularVoiceCues {
  static final Map<AppLanguage, Map<String, String>> _cues = {
    AppLanguage.kannada: {
      'job_alert': 'ಹೊಸ ಗ್ರಾಹಕರ ಕರೆ ಬಂದಿದೆ! ಪರಿಶೀಲಿಸಿ.',
      'job_accepted': 'ಬುಕಿಂಗ್ ದೃಢೀಕರಿಸಲಾಗಿದೆ. ಸುರಕ್ಷಿತವಾಗಿ ಚಾಲನೆ ಮಾಡಿ.',
      'arrived_doorstep': 'ಗ್ರಾಹಕರ ಮನೆ ತಲುಪಿದ್ದೀರಿ. ಪ್ರಾರಂಭದ ಪಿನ್ ಕೇಳಿ.',
      'work_completed': 'ಕೆಲಸ ಪೂರ್ಣಗೊಂಡಿದೆ. ತಪಾಸಣಾ ಪಿನ್ ನಮೂದಿಸಿ.',
      'payout_settled': 'ಹಣ ನಿಮ್ಮ ಬ್ಯಾಂಕ್ ಖಾತೆಗೆ ಜಮೆಯಾಗಿದೆ! ಧನ್ಯವಾದಗಳು.',
    },
    AppLanguage.hindi: {
      'job_alert': 'नया काम उपलब्ध है! स्वीकार करने के लिए टैप करें।',
      'job_accepted': 'बुकिंग कन्फर्म हो गई है। ग्राहक के पते पर जाएं।',
      'arrived_doorstep': 'आप ग्राहक के पते पर पहुंच गए हैं। स्टार्ट पिन दर्ज करें।',
      'work_completed': 'काम पूरा हो गया है। कस्टमर से कम्प्लीशन पिन लें।',
      'payout_settled': 'भुगतान आपके खाते में जमा हो गया है! बधाई हो।',
    },
    AppLanguage.tamil: {
      'job_alert': 'புதிய வேலை வாய்ப்பு வந்துள்ளது! ஏற்க தட்டவும்.',
      'job_accepted': 'வேலை உறுதி செய்யப்பட்டது. முகவரிக்கு செல்லவும்.',
      'arrived_doorstep': 'நீங்கள் இருப்பிடத்தை அடைந்துவிட்டீர்கள். பின் குறியீட்டை உள்ளிடவும்.',
      'work_completed': 'வேலை வெற்றிகரமாக முடிந்தது.',
      'payout_settled': 'பணம் உங்கள் கணக்கில் வரவு வைக்கப்பட்டது!',
    },
    AppLanguage.english: {
      'job_alert': 'New job available nearby! Tap to view.',
      'job_accepted': 'Job accepted. Drive safely to customer location.',
      'arrived_doorstep': 'You have arrived. Ask customer for 4-digit start PIN.',
      'work_completed': 'Work complete. Ask customer for 4-digit completion PIN.',
      'payout_settled': 'Payment deposited to your bank account! Great job.',
    },
  };

  /// Retrieves the spoken cue for the current language.
  static String getPrompt(String cueKey, AppLanguage lang) {
    return _cues[lang]?[cueKey] ?? _cues[AppLanguage.english]?[cueKey] ?? '';
  }
}
