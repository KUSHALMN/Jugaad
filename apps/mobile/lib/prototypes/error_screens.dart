import 'package:flutter/material.dart';
import 'theme.dart';
import 'components.dart';
// Note: error screens are now handled inline in their respective feature screens.

// Note: ERROR 1 (No workers found) is already handled natively in job_match_screen.dart as SCREEN A2.

// ==========================================
// ERROR 2 — PAYMENT FAILED
// ==========================================

class PaymentFailedScreen extends StatelessWidget {
  const PaymentFailedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Scaffold(
      backgroundColor: colors.background,
      appBar: const CustomAppBar(
        title: 'Payment',
        showBack: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64.0,
                height: 64.0,
                decoration: BoxDecoration(
                  color: colors.dangerFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline, color: colors.dangerPrimary, size: 32.0),
              ),
              const SizedBox(height: 24.0),
              
              Text(
                'Payment unsuccessful',
                style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              const SizedBox(height: 8.0),
              
              Text(
                "Your UPI payment couldn't be processed.",
                style: TextStyle(fontSize: 14.0, color: colors.neutralPrimary),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32.0),
              
              // Information Pill (Amber)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: colors.warningFill,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: colors.warningBorder, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, color: colors.warningPrimary, size: 16.0),
                    const SizedBox(width: 8.0),
                    Text(
                      'Your job slot is held for 5 minutes.',
                      style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: colors.warningPrimary),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 48.0),
              
              PrimaryButton(
                text: 'Try again',
                onPressed: () {},
              ),
              const SizedBox(height: 16.0),
              SecondaryButton(
                text: 'Use a different payment method',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// ERROR 3 — WORKER CANCELLED (AUTO REROUTE)
// ==========================================

class WorkerCancelledScreen extends StatefulWidget {
  const WorkerCancelledScreen({Key? key}) : super(key: key);

  @override
  State<WorkerCancelledScreen> createState() => _WorkerCancelledScreenState();
}

class _WorkerCancelledScreenState extends State<WorkerCancelledScreen> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Auto-reroute amber banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
              color: colors.warningFill,
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colors.warningPrimary),
                  const SizedBox(width: 12.0),
                  Text(
                    'Worker had to cancel.',
                    style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700, color: colors.warningPrimary),
                  ),
                ],
              ),
            ),
            
            // Progress Bar Animation Restarts
            AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return Container(
                  width: MediaQuery.of(context).size.width,
                  height: 3.0,
                  color: colors.neutralFill,
                  child: FractionallySizedBox(
                    widthFactor: 0.3,
                    alignment: Alignment(-1.0 + (_progressController.value * 2.0), 0),
                    child: Container(color: colors.primary),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 64.0),
            
            const CircularProgressIndicator(),
            const SizedBox(height: 32.0),
            
            Text(
              "We're finding you another worker now.",
              style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
            const SizedBox(height: 8.0),
            Text(
              "Please wait. Priority matching enabled.",
              style: TextStyle(fontSize: 13.0, color: colors.neutralPrimary),
            ),
            
            // Note: If this fails in 60s, it transitions back to SCREEN A2 from job_match_screen.dart
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ERROR 4 — NETWORK OFFLINE
// ==========================================

void showNoInternetBottomSheet(BuildContext context) {
  final colors = Theme.of(context).extension<AppColors>()!;
  
  showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    barrierColor: Colors.black.withValues(alpha: 0.1), // Much lighter overlay
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
    ),
    builder: (BuildContext context) {
      return Container(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(color: colors.dangerFill, shape: BoxShape.circle),
              child: Icon(Icons.wifi_off, color: colors.dangerPrimary, size: 24.0),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('No internet connection.', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2.0),
                  Text('Some features may not work.', style: TextStyle(fontSize: 12.0, color: colors.neutralPrimary)),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                // Retry logic and dismiss if successful
                Navigator.pop(context);
              },
              child: Text('Retry', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: colors.primary)),
            )
          ],
        ),
      );
    },
  );
}

// ==========================================
// ERROR 5 — JOB EXPIRED TOAST
// ==========================================

void showJobExpiredToast(BuildContext context) {
  final colors = Theme.of(context).extension<AppColors>()!;
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text(
        'Your job request expired. Post again?',
        style: TextStyle(fontSize: 13.0, color: Colors.white),
      ),
      backgroundColor: const Color(0xFF323232),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Yes',
        textColor: colors.lightFill, // readable contrast
        onPressed: () {
          // Restart job posting flow
        },
      ),
    ),
  );
}

// ==========================================
// ERROR 6 — WORKER DIDN'T SHOW UP
// ==========================================

class WorkerNoShowScreen extends StatelessWidget {
  const WorkerNoShowScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Scaffold(
      backgroundColor: colors.background,
      appBar: const CustomAppBar(
        title: 'Report Issue',
        showBack: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(color: colors.warningFill, shape: BoxShape.circle),
                child: Icon(Icons.person_off, size: 32.0, color: colors.warningPrimary),
              ),
              const SizedBox(height: 24.0),
              
              Text(
                "Worker hasn't arrived? We'll help.",
                style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              const SizedBox(height: 8.0),
              Text(
                "It's past the estimated arrival time. You can try contacting the worker directly, or request an immediate replacement.",
                style: TextStyle(fontSize: 14.0, color: colors.neutralPrimary, height: 1.4),
              ),
              
              const SizedBox(height: 48.0),
              
              // Option 1
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: colors.neutralBorder, width: 1.0),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone, color: colors.primary),
                    const SizedBox(width: 16.0),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Contact worker', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600)),
                          SizedBox(height: 2.0),
                          Text('They might be stuck in traffic', style: TextStyle(fontSize: 12.0, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colors.neutralPrimary),
                  ],
                ),
              ),
              
              const SizedBox(height: 16.0),
              
              // Option 2 (Flags Admin)
              InkWell(
                onTap: () {
                  // Flags admin and returns to A2 searching
                },
                borderRadius: BorderRadius.circular(12.0),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: colors.dangerFill,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: colors.dangerBorder, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.autorenew, color: colors.dangerPrimary),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report issue — get a replacement',
                              style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w700, color: colors.dangerPrimary),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              'We will notify our admin team instantly.',
                              style: TextStyle(fontSize: 12.0, color: colors.dangerPrimary.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: colors.dangerPrimary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
