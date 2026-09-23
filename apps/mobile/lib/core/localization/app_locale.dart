/// Supported languages for the Jugaad platform across Indian states.
enum AppLanguage {
  english('en', 'English', 'English'),
  kannada('kn', 'ಕನ್ನಡ', 'Kannada'),
  hindi('hi', 'हिंदी', 'Hindi'),
  tamil('ta', 'தமிழ்', 'Tamil');

  final String code;
  final String nativeName;
  final String englishName;

  const AppLanguage(this.code, this.nativeName, this.englishName);

  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.english;
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code.toLowerCase(),
      orElse: () => AppLanguage.english,
    );
  }
}
