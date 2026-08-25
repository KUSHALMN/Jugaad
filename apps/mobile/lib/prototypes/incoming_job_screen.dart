import 'package:flutter/material.dart';
import 'dart:async';
import 'theme.dart';
import 'components.dart';

/// Call this function to trigger the incoming job overlay
void showIncomingJobRequest(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const IncomingJobScreen(),
  );
}

class IncomingJobScreen extends StatefulWidget {
  const IncomingJobScreen({Key? key}) : super(key: key);

  @override
  State<IncomingJobScreen> createState() => _IncomingJobScreenState();
}

class _IncomingJobScreenState extends State<IncomingJobScreen> with SingleTickerProviderStateMixin {
  int _secondsLeft = 60;
  Timer? _timer;
  bool _isExpired = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _pulseController.reverse();
        } else if (status == AnimationStatus.dismissed && _secondsLeft < 15 && !_isExpired) {
          _pulseController.forward();
        }
      });

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
        // Start pulsing when under 15 seconds
        if (_secondsLeft == 14) {
          _pulseController.forward();
        }
      } else {
        _timer?.cancel();
        _handleExpiration();
      }
    });
  }

  void _handleExpiration() {
    setState(() {
      _isExpired = true;
    });
    
    // Brief red flash simulation before closing
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        Navigator.pop(context);
        // Show the expiration toast on the underlying screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request expired. Waiting for next job.'),
            backgroundColor: Color(0xFFA32D2D), // Danger color
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Color _getTimerColor(AppColors colors) {
    if (_secondsLeft > 30) return const Color(0xFF0F6E56); // Worker green
    if (_secondsLeft >= 15) return const Color(0xFFBA7517); // Warning amber
    return const Color(0xFFA32D2D); // Danger red
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final Color workerPrimary = const Color(0xFF0F6E56);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: _isExpired ? const Color(0xFFA32D2D).withValues(alpha: 0.3) : Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(top: 100.0), // Allow some black overlay to show above
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // URGENT HEADER BAR
            Container(
              width: double.infinity,
              height: 56.0,
              decoration: BoxDecoration(
                color: workerPrimary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'New job request!',
                    style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  Text(
                    'Tap accept to confirm',
                    style: TextStyle(fontSize: 12.0, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            
            // COUNTDOWN TIMER
            Padding(
              padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _secondsLeft < 15 ? _pulseAnimation.value : 1.0,
                        child: Text(
                          '$_secondsLeft',
                          style: TextStyle(
                            fontSize: 48.0,
                            fontWeight: FontWeight.w700,
                            color: _getTimerColor(colors),
                            height: 1.0,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'seconds to respond',
                    style: TextStyle(fontSize: 12.0, color: colors.neutralPrimary),
                  ),
                ],
              ),
            ),
            
            // JOB SUMMARY CARD
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: colors.neutralBorder, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: colors.textPrimary.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Laptop repair',
                        style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700, color: colors.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: colors.warningFill,
                          borderRadius: BorderRadius.circular(100.0),
                          border: Border.all(color: colors.warningBorder, width: 0.5),
                        ),
                        child: Text(
                          'Right now',
                          style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600, color: colors.warningPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    '2.1 km from you',
                    style: TextStyle(fontSize: 14.0, color: colors.neutralPrimary),
                  ),
                  const SizedBox(height: 16.0),
                  const Divider(height: 1.0),
                  const SizedBox(height: 16.0),
                  Row(
                    children: [
                      Text('Estimated pay: ', style: TextStyle(fontSize: 14.0, color: colors.textPrimary)),
                      Text('₹280–₹350 estimated', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700, color: workerPrimary)),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: colors.neutralFill.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Text(
                      '"Need my laptop screen fixed. I dropped it yesterday and there is a massive crack down the middle."',
                      style: TextStyle(fontSize: 12.0, fontStyle: FontStyle.italic, color: Color(0xFF5F5E5A)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32.0),
            
            // ACTION BUTTONS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // PASS BUTTON
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 44.0,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.neutralPrimary,
                          side: BorderSide(color: colors.neutralBorder, width: 1.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                        ),
                        onPressed: () {
                          _timer?.cancel();
                          Navigator.pop(context);
                        },
                        child: const Text('Pass', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  
                  // ACCEPT BUTTON
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 56.0, // Taller button to make it easy to tap
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: workerPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                        ),
                        onPressed: () {
                          _timer?.cancel();
                          // Handle accept logic, navigate to Active Job Tracking
                          Navigator.pop(context);
                        },
                        child: const Text('Accept', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // INCENTIVE TEXT
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 32.0),
              child: Text(
                'Passing too often reduces your job priority.',
                style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.w600, color: colors.warningPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
