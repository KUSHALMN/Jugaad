import '../network/environment_config.dart';

class ApiConstants {
  static const String baseUrl = EnvironmentConfig.baseUrl;
  static const String apiV1 = EnvironmentConfig.apiV1;
  
  // Endpoints
  static const String health = '$baseUrl/health';
  static const String login = '$apiV1/auth/login';
  static const String sendOtp = '$apiV1/auth/send-otp';
  static const String verifyOtp = '$apiV1/auth/verify-otp';
  static const String searchWorkers = '$apiV1/workers/search';
  static const String createJob = '$apiV1/jobs/create';
  static const String workerResponse = '$apiV1/dispatch/respond';
}
