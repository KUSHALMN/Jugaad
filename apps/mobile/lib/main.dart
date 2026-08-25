import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart' as pkg_provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/portal_mode.dart';
import 'core/services/notification_service.dart';
import 'core/services/heartbeat_service.dart';
import 'core/network/dio_client.dart';
import 'core/network/connectivity_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/services/platform_config_service.dart';
import 'app.dart';
import 'features/shared/widgets/offline_banner.dart';
import 'core/services/fcm_token_manager.dart';
import 'core/services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure full edge-to-edge display (removes top/bottom black letterboxing)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Track whether critical init succeeded
  bool initSuccess = false;
  String? initError;

  try {
    // ── PHASE 1: Critical init (Firebase + Supabase) ──
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize network layer (Dio + connectivity + server warm-up)
    DioClient.initialize();
    ConnectivityService.init(); // pings /health to warm Render

    // Assert that Supabase environment variables are securely injected
    const url = SupabaseConfig.url;
    const anonKey = SupabaseConfig.anonKey;

    if (url.isEmpty ||
        url == 'https://your-project.supabase.co' ||
        anonKey.isEmpty ||
        anonKey.startsWith('eyJ...your-anon-key')) {
      throw AssertionError(
        'CRITICAL: Supabase credentials are missing or set to placeholders!\n'
        'Please pass them securely at build/run time using --dart-define:\n'
        '  flutter run --dart-define=SUPABASE_URL=https://your-real-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key\n',
      );
    }

    // Initialize Supabase (replaces Firestore for data layer)
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      // Fix N3: disable verbose Supabase debug logs in release mode
      debug: kDebugMode,
    );

    // Fix C1: fetchConfig() relies on DioClient which is ready, but the backend
    // may need Supabase to be up. Move here so it runs after Supabase is initialized.
    PlatformConfigService().fetchConfig();

    // ── Critical init succeeded ──
    initSuccess = true;

    // ── PHASE 2: Non-critical init (safe to fail) ──

    // Initialize location on startup in the background (do not block app startup)
    try {
      final locationService = LocationService();
      locationService.getCurrentLocation().catchError((error) {
        print('[MAIN] Initial location request failed: $error');
        return null;
      });
    } catch (locationError) {
      print('[MAIN] Initial location request failed: $locationError');
    }

    // Crashlytics setup
    if (!kIsWeb) {
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } else {
      FlutterError.onError = (errorDetails) {
        FlutterError.presentError(errorDetails);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        print('[MAIN] Platform error on web: $error\n$stack');
        return true;
      };
    }

    try {
      if (kIsWeb) {
        // Fix M1: Check for placeholder reCAPTCHA key and warn instead of silently misconfiguring App Check
        const recaptchaKey = '6Ld_your-recaptcha-v3-key';
        if (recaptchaKey.contains('your-recaptcha')) {
          debugPrint('[MAIN] WARNING: Firebase App Check reCAPTCHA key is still a placeholder. '
              'Web App Check is disabled. Update it in main.dart before release.');
        } else {
          await FirebaseAppCheck.instance.activate(
            // ignore: deprecated_member_use
            webProvider: ReCaptchaV3Provider(recaptchaKey),
          );
        }
      } else {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: const AndroidPlayIntegrityProvider(),
        );
      }
    } catch (appCheckError) {
      debugPrint('[MAIN] Firebase App Check initialization skipped/failed: $appCheckError');
    }
    // Initialize non-critical background services asynchronously to prevent blocking runApp()
    HeartbeatService().init().catchError((e) => print('[MAIN] Heartbeat service init error: $e'));
    NotificationService().init(AppRouter.rootNavigatorKey).catchError((e) => print('[MAIN] Notification service init error: $e'));
    FCMTokenManager.refreshAndUploadToken();
  } catch (e) {
    initError = e.toString();
    print('[MAIN] Init error: $e');
  }

  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // ALWAYS run the app — show error UI if critical init failed
  if (!initSuccess) {
    runApp(_InitErrorApp(error: initError ?? 'Unknown initialization error'));
    return;
  }

  runApp(
    ProviderScope(
      child: pkg_provider.MultiProvider(
        providers: [
          pkg_provider.ChangeNotifierProvider(create: (_) => PortalModeProvider()),
        ],
        child: const JugaadApp(),
      ),
    ),
  );
}

class JugaadApp extends StatelessWidget {
  const JugaadApp({super.key});

  @override
  Widget build(BuildContext context) {
    final modeProvider = pkg_provider.Provider.of<PortalModeProvider>(context, listen: false);
    final container = ProviderScope.containerOf(context);
    final router = AppRouter.getRouter(modeProvider, container);

    return pkg_provider.Consumer<PortalModeProvider>(
      builder: (context, portalModeProvider, child) {
        final mode = portalModeProvider.mode;

        return MaterialApp.router(
          title: 'Jugaad App',
          theme: mode.theme,
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          builder: (context, child) {
            return OfflineBannerOverlay(child: child!);
          },
        );
      },
    );
  }
}

/// Fallback error app shown when critical initialization fails.
/// This prevents the dreaded white screen by giving users actionable feedback.
class _InitErrorApp extends StatelessWidget {
  final String error;
  const _InitErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF8F9FC),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFDC2626),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Startup Error',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The app could not start properly.\nPlease check your internet connection and restart.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
