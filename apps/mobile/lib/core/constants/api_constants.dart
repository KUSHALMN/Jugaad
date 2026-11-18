import '../network/environment_config.dart';

class ApiConstants {
  static String get baseUrl => EnvironmentConfig.baseUrl;
  static String get apiV1 => EnvironmentConfig.apiV1;
  
  // Endpoints
  static String get health => '$baseUrl/health';
  static String get login => '$apiV1/auth/login';
  static String get sendOtp => '$apiV1/auth/send-otp';
  static String get verifyOtp => '$apiV1/auth/verify-otp';
  static String get searchWorkers => '$apiV1/workers/search';
  static String get createJob => '$apiV1/jobs/create';
  static String get workerResponse => '$apiV1/dispatch/respond';
}
