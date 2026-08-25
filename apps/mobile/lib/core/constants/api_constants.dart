class ApiConstants {
  // LOCAL TESTING — Android Emulator uses 10.0.2.2 for host machine
  // Physical device — use your PC's local IP (e.g., 192.168.1.5)
  
  static const bool isLocal = true;
  
  static const String _localAndroidEmulator = 'http://10.0.2.2:8000';
  // ignore: unused_field
  static const String _localPhysicalDevice = 'http://192.168.1.X:8000'; // Change X
  static const String _production = 'https://your-render-url.onrender.com';
  
  static const String baseUrl = isLocal 
      ? _localAndroidEmulator  // Change to _localPhysicalDevice if real phone
      : _production;
  
  static const String apiV1 = '$baseUrl/api/v1';
  
  // Endpoints
  static const String health = '$baseUrl/health';
  static const String login = '$apiV1/auth/login';
  static const String sendOtp = '$apiV1/auth/send-otp';
  static const String verifyOtp = '$apiV1/auth/verify-otp';
  static const String searchWorkers = '$apiV1/workers/search';
  static const String createJob = '$apiV1/jobs/create';
  static const String workerResponse = '$apiV1/dispatch/respond';
}
