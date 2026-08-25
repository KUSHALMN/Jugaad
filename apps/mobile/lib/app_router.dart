import 'package:flutter/material.dart';

// ==========================================
// PROTOTYPE TRANSITION UTILITIES
// ==========================================

/// Forward: Slide left, 300ms ease-out
class SlideLeftRoute extends PageRouteBuilder {
  final Widget page;
  SlideLeftRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const curve = Curves.easeOut;
            var tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        );
}

/// Modal: Slide up, 280ms ease-out with 35% overlay
class SlideUpModalRoute extends PageRouteBuilder {
  final Widget page;
  SlideUpModalRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 280),
          opaque: false, 
          barrierColor: Colors.black.withValues(alpha: 0.35),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const curve = Curves.easeOut;
            var tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        );
}

/// Mode switch: Cross-fade, 350ms
class CrossFadeRoute extends PageRouteBuilder {
  final Widget page;
  CrossFadeRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
}

/// Error: Fade in/out, 200ms
class ErrorFadeRoute extends PageRouteBuilder {
  final Widget page;
  ErrorFadeRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
}

// ==========================================
// APP ROUTER (WIRING DEFINITIONS)
// ==========================================
// This class outlines the exact navigation flows and which transitions they use.
class AppRouter {
  
  // 1. ONBOARDING WIRING
  static void navigateToRoleSelect(BuildContext context, Widget roleSelectScreen) {
    Navigator.push(context, SlideLeftRoute(page: roleSelectScreen));
  }
  
  static void navigateToOtp(BuildContext context, Widget otpScreen) {
    Navigator.push(context, SlideLeftRoute(page: otpScreen));
  }
  
  // 2. MODE SWITCHING
  static void switchMode(BuildContext context, Widget targetHomeScreen) {
    // Cross-fade for 350ms as specified
    Navigator.pushReplacement(context, CrossFadeRoute(page: targetHomeScreen));
  }

  // 3. USER PORTAL WIRING
  static void navigateToJobPosting(BuildContext context, Widget step1Screen) {
    Navigator.push(context, SlideLeftRoute(page: step1Screen));
  }
  
  static void navigateToMatchingScreen(BuildContext context, Widget matchingScreen) {
    // No back animation allowed here ideally, replaces current flow
    Navigator.pushReplacement(context, SlideLeftRoute(page: matchingScreen));
  }
  
  // CRITICAL NEW PATH: Callback confirmed
  static void showCallbackConfirmedToast(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('We\'ll call you within 10 minutes'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
        backgroundColor: Color(0xFF0F6E56), // Success Green
      ),
    );
  }

  // 4. WORKER PORTAL WIRING
  static void showIncomingJobRequest(BuildContext context, Widget incomingJobOverlay) {
    // Uses the SlideUp Modal configuration (280ms, 35% overlay)
    Navigator.push(context, SlideUpModalRoute(page: incomingJobOverlay));
  }
  
  static void navigateToActiveJob(BuildContext context, Widget activeJobScreen) {
    Navigator.pushReplacement(context, SlideLeftRoute(page: activeJobScreen));
  }
  
  // 5. ERROR PATH WIRING
  static void showNetworkOffline(BuildContext context, Widget offlineSheet) {
    // Usually uses showModalBottomSheet natively, but can use Modal route
    Navigator.push(context, SlideUpModalRoute(page: offlineSheet));
  }

  static void handlePaymentFailed(BuildContext context, Widget paymentErrorScreen) {
    // Errors use the fast 200ms fade
    Navigator.push(context, ErrorFadeRoute(page: paymentErrorScreen));
  }
}
