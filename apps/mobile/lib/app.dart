import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/portal_mode.dart';
import 'core/services/auth_service.dart';
import 'core/providers/auth_provider.dart';

import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/role_select_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/onboarding_screen.dart';

import 'features/user/user_shell.dart';
import 'features/user/screens/user_home_screen.dart';
import 'features/user/screens/post_job/step1_screen.dart';
import 'features/user/screens/post_job/step2_screen.dart';
import 'features/user/screens/post_job/step3_screen.dart';
import 'features/user/screens/matching/matching_screen.dart';
import 'features/user/screens/matching/worker_search_screen.dart';
import 'features/user/screens/tracking_screen.dart';
import 'features/user/screens/payment_screen.dart';
import 'features/user/screens/completion_screen.dart';
import 'features/user/screens/jobs/jobs_screen.dart';
import 'features/worker/worker_shell.dart';
import 'features/worker/screens/worker_home_screen.dart';
import 'features/worker/screens/registration/step1_screen.dart';
import 'features/worker/screens/registration/step2_screen.dart';
import 'features/worker/screens/registration/step3_screen.dart';
import 'features/worker/screens/registration/approval_submitted_screen.dart';
import 'features/worker/screens/incoming_request_screen.dart';
import 'features/worker/screens/active_job_screen.dart';
import 'features/worker/screens/earnings_screen.dart';
import 'features/user/screens/user_portal_screen.dart';
import 'features/user/screens/services_grid_screen.dart';
import 'features/worker/screens/worker_portal_screen.dart';
import 'features/shared/widgets/mode_switch_sheet.dart';
import 'features/user/screens/chat_screen.dart';
import 'features/user/screens/worker_list_screen.dart';
import 'features/admin/screens/admin_approvals_screen.dart';

// Placeholder Screens for Routing
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title, style: const TextStyle(fontSize: 24))),
    );
  }
}

// BUG FIX
class _AuthRefreshListenable extends ChangeNotifier {
  late final StreamSubscription<User?> _subscription;
  ProviderSubscription<UserSession>? _riverpodSubscription;

  _AuthRefreshListenable(ProviderContainer container) {
    _subscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });

    // Notify GoRouter when Riverpod user session resolves or updates
    _riverpodSubscription = container.listen<UserSession>(
      authProvider,
      (previous, next) {
        if (previous?.role != next.role || previous?.isLoading != next.isLoading) {
          notifyListeners();
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    _riverpodSubscription?.close();
    super.dispose();
  }
}

class AppRouter {
  static final _authService = AuthService();
  static final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
  static bool hasSeenSplash = false;

  static CustomTransitionPage _fadeTransition(BuildContext context, GoRouterState state, Widget child) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  static GoRouter? _router;

  /// Reset the router cache. Must be called when the app restarts
  /// to prevent stale auth state from causing white screens.
  static void reset() {
    _router?.dispose();
    _router = null;
    hasSeenSplash = false;
  }

  static GoRouter getRouter(PortalModeProvider modeProvider, ProviderContainer container) {
    // FIX: Always create a fresh router. The previous implementation cached
    // _router as a static singleton that survived hot restarts and re-runs.
    // This meant the GoRouter's refreshListenable and redirect closure
    // would hold references to stale PortalModeProvider and ProviderContainer
    // instances from a previous session, causing the redirect to malfunction
    // and render a white screen.
    if (_router != null) {
      _router!.dispose();
    }
    _router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/splash',
      refreshListenable: Listenable.merge([
        modeProvider,
        _AuthRefreshListenable(container),
      ]),
      redirect: (context, state) {
        final isLoggedIn = _authService.currentUser != null;
        final location = state.uri.toString();

        // 0. Force /splash animation on app launch before going anywhere else
        if (!hasSeenSplash) {
          if (location == '/splash') return null; // Already on splash — let animation play uninterrupted
          print('[ROUTER] Fresh launch detected -> directing to /splash animation first');
          return '/splash';
        }

        // 1. Handle root path
        if (location == '/' || location == '') {
          return '/splash';
        }

        // 2. Unauthenticated user guard:
        // Only allow splash, onboarding, and auth routes. Protect all /user/* and /worker/* routes.
        if (!isLoggedIn) {
          final isAuthOrSplashRoute = location == '/splash' ||
              location.startsWith('/auth') ||
              location == '/onboarding';
          if (!isAuthOrSplashRoute) {
            print('[ROUTER] Unauthenticated access blocked for $location -> redirecting to /splash');
            return '/splash';
          }
          return null;
        }

        // 3. Authenticated user logic:
        final userSession = container.read(authProvider);

        // While role is loading, allow current route (don't redirect prematurely)
        if (userSession.isLoading) {
          return null;
        }

        final isWorkerMode = modeProvider.mode == PortalMode.worker ||
            state.uri.queryParameters['role'] == 'worker';

        if (isWorkerMode && modeProvider.mode != PortalMode.worker) {
          modeProvider.setMode(PortalMode.worker);
        }

        // Logged-in users on auth or onboarding screens should be sent to their portal home.
        // Note: We DO NOT redirect /splash here so that the SplashScreen can render and play its opening animation!
        if (location.startsWith('/auth') || location == '/onboarding') {
          if (isWorkerMode) {
            print('[ROUTER] Worker logged in -> navigating to /worker/register/step1');
            return '/worker/register/step1';
          }
          return '/user/home';
        }

        // 4. Portal-mode route guards for logged-in users:
        final currentMode = modeProvider.mode;
        if (currentMode == PortalMode.worker && location.startsWith('/user')) {
          print('[ROUTER] Worker mode on user route -> redirecting to /worker/home');
          return '/worker/home';
        }
        if (currentMode == PortalMode.user && location.startsWith('/worker')) {
          // Exception: Always allow worker registration screens if registering
          if (location.startsWith('/worker/register')) {
            return null;
          }
          print('[ROUTER] User mode on worker route -> redirecting to /user/home');
          return '/user/home';
        }

        return null; // Allowed
      },
      routes: [
        GoRoute(
          path: '/worker/dashboard',
          redirect: (context, state) => '/worker/home',
        ),
        GoRoute(
          path: '/home',
          redirect: (context, state) => '/user/home',
        ),
        GoRoute(
          path: '/onboarding',
          redirect: (context, state) => '/auth/onboarding',
        ),
        GoRoute(
          path: '/splash',
          pageBuilder: (context, state) => _fadeTransition(context, state, const SplashScreen()),
        ),
        GoRoute(
          path: '/auth/onboarding',
          pageBuilder: (context, state) => _fadeTransition(context, state, const OnboardingScreen()),
        ),
        GoRoute(
          path: '/auth/role',
          pageBuilder: (context, state) => _fadeTransition(context, state, const RoleSelectScreen()),
        ),
        GoRoute(
          path: '/auth/otp',
          pageBuilder: (context, state) {
            final roleName = state.uri.queryParameters['role'] ?? 'user';
            final role = roleName == 'worker' ? PortalMode.worker : PortalMode.user;
            return _fadeTransition(context, state, LoginScreen(selectedRole: role));
          },
        ),

        // POST JOB WIZARD — outside shell (fullscreen flow)
        GoRoute(
          path: '/user/post-job/step1',
          pageBuilder: (context, state) => _fadeTransition(context, state, const PostJobStep1Screen()),
        ),
        GoRoute(
          path: '/user/post-job/step2',
          pageBuilder: (context, state) => _fadeTransition(context, state, const PostJobStep2Screen()),
        ),
        GoRoute(
          path: '/user/post-job/step3',
          pageBuilder: (context, state) => _fadeTransition(context, state, const PostJobStep3Screen()),
        ),
        GoRoute(
          path: '/user/matching',
          pageBuilder: (context, state) {
            final jobId = state.uri.queryParameters['job_id'] ?? '';
            return _fadeTransition(context, state, MatchingScreen(jobId: jobId));
          },
        ),
        GoRoute(
          path: '/user/worker-search',
          pageBuilder: (context, state) {
            final service = state.uri.queryParameters['service'] ?? '';
            return _fadeTransition(
              context,
              state,
              WorkerSearchScreen(initialService: service),
            );
          },
        ),
        GoRoute(
          path: '/user/tracking',
          pageBuilder: (context, state) {
            final jobId = state.uri.queryParameters['job_id'] ?? '';
            return _fadeTransition(context, state, TrackingScreen(jobId: jobId));
          },
        ),
        GoRoute(
          path: '/user/payment',
          pageBuilder: (context, state) {
            final jobId = state.uri.queryParameters['job_id'] ?? '';
            final amount = double.tryParse(state.uri.queryParameters['amount'] ?? '0') ?? 0;
            return _fadeTransition(context, state, PaymentScreen(jobId: jobId, amount: amount));
          },
        ),
        GoRoute(
          path: '/user/completion',
          pageBuilder: (context, state) {
            final jobId = state.uri.queryParameters['job_id'] ?? '';
            final workerName = state.uri.queryParameters['worker_name'] ?? 'Worker';
            final duration = int.tryParse(state.uri.queryParameters['duration'] ?? '0') ?? 0;
            return _fadeTransition(context, state, CompletionScreen(jobId: jobId, workerName: workerName, durationMinutes: duration));
          },
        ),
        GoRoute(
          path: '/user/chat/:jobId',
          pageBuilder: (context, state) {
            final jobId = state.pathParameters['jobId'] ?? '';
            return _fadeTransition(context, state, ChatScreen(jobId: jobId));
          },
        ),
        GoRoute(
          path: '/admin/approvals',
          pageBuilder: (context, state) => _fadeTransition(context, state, const AdminApprovalsScreen()),
        ),
        GoRoute(
          path: '/worker/chat',
          pageBuilder: (context, state) {
            final jobId = state.uri.queryParameters['job_id'] ?? '';
            return _fadeTransition(context, state, ChatScreen(jobId: jobId));
          },
        ),

        // WORKER REGISTRATION WIZARD — outside shell
        GoRoute(
          path: '/worker/register/step1',
          pageBuilder: (context, state) => _fadeTransition(context, state, const WorkerRegistrationStep1()),
        ),
        GoRoute(
          path: '/worker/register/step2',
          pageBuilder: (context, state) => _fadeTransition(context, state, const WorkerRegistrationStep2()),
        ),
        GoRoute(
          path: '/worker/register/step3',
          pageBuilder: (context, state) => _fadeTransition(context, state, const WorkerRegistrationStep3()),
        ),
        GoRoute(
          path: '/worker/register/success',
          pageBuilder: (context, state) => _fadeTransition(context, state, const ApprovalSubmittedScreen()),
        ),
        GoRoute(
          path: '/worker/incoming',
          pageBuilder: (context, state) {
            final jobId = state.uri.queryParameters['job_id'] ?? '';
            final skill = state.uri.queryParameters['skill'] ?? 'Service';
            final budget = double.tryParse(state.uri.queryParameters['budget'] ?? '0') ?? 0;
            final description = state.uri.queryParameters['description'] ?? '';
            final distance = double.tryParse(state.uri.queryParameters['distance'] ?? '0') ?? 0;
            final timeout = int.tryParse(state.uri.queryParameters['timeout'] ?? '300') ?? 300;
            final jobType = state.uri.queryParameters['job_type'] ?? 'normal';
            final surcharge = double.tryParse(state.uri.queryParameters['surcharge'] ?? '0') ?? 0;
            return CustomTransitionPage(
              key: state.pageKey,
              opaque: false, // Allows the black background overlay to be transparent
              child: IncomingRequestScreen(
                jobId: jobId,
                skill: skill,
                budget: budget,
                description: description,
                distanceKm: distance,
                timeoutSeconds: timeout,
                jobType: jobType,
                surchargeAmount: surcharge,
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return Row(
                  children: [
                    Expanded(child: FadeTransition(opacity: animation, child: child)),
                  ],
                );
              },
            );
          },
        ),

        // USER SHELL
        ShellRoute(
          builder: (context, state, child) {
            return UserShell(child: child);
          },
          routes: [
            GoRoute(
              path: '/user/home',
              pageBuilder: (context, state) => _fadeTransition(context, state, const UserHomeScreen()),
            ),
            GoRoute(
              path: '/user/book',
              pageBuilder: (context, state) => _fadeTransition(context, state, const ServicesGridScreen()),
            ),
            GoRoute(
              path: '/user/jobs',
              pageBuilder: (context, state) => _fadeTransition(context, state, const JobsScreen()),
            ),
            GoRoute(
              path: '/user/chat',
              pageBuilder: (context, state) => _fadeTransition(context, state, const ChatScreen()),
            ),
            GoRoute(
              path: '/user/workers',
              pageBuilder: (context, state) => _fadeTransition(context, state, const WorkerListScreen()),
            ),
            GoRoute(
              path: '/user/profile',
              pageBuilder: (context, state) => _fadeTransition(
                context,
                state,
                UserPortalScreen(
                  onSwitchMode: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => const ModeSwitchSheet(currentMode: PortalMode.user),
                    );
                  },
                ),
              ),
            ),
          ],
        ),

        // WORKER SHELL
        ShellRoute(
          builder: (context, state, child) {
            return WorkerShell(child: child);
          },
          routes: [
            GoRoute(
              path: '/worker/home',
              pageBuilder: (context, state) => _fadeTransition(context, state, const WorkerHomeScreen()),
            ),
            GoRoute(
              path: '/worker/active',
              pageBuilder: (context, state) {
                final jobId = state.uri.queryParameters['job_id'] ?? '';
                return _fadeTransition(context, state, ActiveJobScreen(jobId: jobId));
              },
            ),
            GoRoute(
              path: '/worker/earnings',
              pageBuilder: (context, state) => _fadeTransition(context, state, const EarningsScreen()),
            ),
            GoRoute(
              path: '/worker/profile',
              pageBuilder: (context, state) => _fadeTransition(
                context,
                state,
                WorkerPortalScreen(
                  onSwitchMode: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => const ModeSwitchSheet(currentMode: PortalMode.worker),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
    return _router!;
  }
}
