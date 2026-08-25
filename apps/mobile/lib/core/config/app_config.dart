class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000', // Android emulator → host machine port 8000
  );
  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );
  static bool get isDebug => environment == 'development';
}
