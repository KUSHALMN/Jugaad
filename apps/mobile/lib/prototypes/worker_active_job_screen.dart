import 'package:flutter/material.dart';
import 'theme.dart';
import 'components.dart';
import 'dart:async';

enum ActiveJobState { enRoute, working, wrapUp }

class WorkerActiveJobScreen extends StatefulWidget {
  const WorkerActiveJobScreen({Key? key}) : super(key: key);

  @override
  State<WorkerActiveJobScreen> createState() => _WorkerActiveJobScreenState();
}

class _WorkerActiveJobScreenState extends State<WorkerActiveJobScreen> {
  ActiveJobState _currentState = ActiveJobState.enRoute;
  
  // Fake timer for working state
  int _secondsElapsed = 1440; // 24 minutes
  Timer? _timer;

  void _advanceState() {
    setState(() {
      if (_currentState == ActiveJobState.enRoute) {
        _currentState = ActiveJobState.working;
        _startTimer();
      } else if (_currentState == ActiveJobState.working) {
        _currentState = ActiveJobState.wrapUp;
        _timer?.cancel();
      } else if (_currentState == ActiveJobState.wrapUp) {
        // Pop to Home Screen after completion
        Navigator.pop(context);
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatElapsedTime() {
    int minutes = _secondsElapsed ~/ 60;
    int seconds = _secondsElapsed % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final Color workerPrimary = const Color(0xFF0F6E56);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: const CustomAppBar(
        title: 'Active Job',
        showBack: true, // Typically wouldn't be dismissible easily, but fine for prototype
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildStatusBanner(colors, workerPrimary),
                    const SizedBox(height: 16.0),
                    _buildMainContent(colors, workerPrimary),
                  ],
                ),
              ),
            ),
            
            // Bottom CTA Area
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.neutralBorder, width: 0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 44.0,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: workerPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                      ),
                      onPressed: _advanceState,
                      child: Text(
                        _currentState == ActiveJobState.enRoute
                            ? "I've arrived"
                            : _currentState == ActiveJobState.working
                                ? "Mark as completed"
                                : "Confirm completion",
                        style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (_currentState == ActiveJobState.wrapUp) ...[
                    const SizedBox(height: 12.0),
                    Text(
                      'Customer will be asked to confirm on their end.',
                      style: TextStyle(fontSize: 11.0, color: colors.neutralPrimary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STATUS BANNER
  // ==========================================
  Widget _buildStatusBanner(AppColors colors, Color workerPrimary) {
    if (_currentState == ActiveJobState.enRoute) {
      return Container(
        width: double.infinity,
        height: 48.0,
        color: colors.warningFill,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Head to the job',
              style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700, color: colors.warningPrimary),
            ),
            Text(
              '1.8 km remaining',
              style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w500, color: colors.warningPrimary),
            ),
          ],
        ),
      );
    } else if (_currentState == ActiveJobState.working) {
      return Container(
        width: double.infinity,
        color: const Color(0xFFE1F5EE), // worker light fill
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            Text(
              'Job in progress',
              style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700, color: workerPrimary),
            ),
            const SizedBox(height: 4.0),
            Text(
              'Started 10:32 AM · ${_formatElapsedTime()} elapsed',
              style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700, color: workerPrimary),
            ),
          ],
        ),
      );
    } else {
      // Wrap up
      return Container(
        width: double.infinity,
        height: 48.0,
        color: const Color(0xFFE1F5EE),
        alignment: Alignment.center,
        child: Text(
          'Almost done!',
          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700, color: workerPrimary),
        ),
      );
    }
  }

  // ==========================================
  // MAIN CONTENT BASED ON STATE
  // ==========================================
  Widget _buildMainContent(AppColors colors, Color workerPrimary) {
    switch (_currentState) {
      case ActiveJobState.enRoute:
        return _buildEnRouteContent(colors, workerPrimary);
      case ActiveJobState.working:
        return _buildWorkingContent(colors, workerPrimary);
      case ActiveJobState.wrapUp:
        return _buildWrapUpContent(colors, workerPrimary);
    }
  }

  // STATE 1 — En route
  Widget _buildEnRouteContent(AppColors colors, Color workerPrimary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Card
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: colors.neutralBorder, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20.0,
                      backgroundColor: colors.neutralFill,
                      child: Icon(Icons.person, color: colors.neutralPrimary),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Text('Rahul Kumar', style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700)),
                    ),
                    InkWell(
                      onTap: () {},
                      child: Text(
                        'Call customer',
                        style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600, color: colors.primary), // blue link
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                Text(
                  '452, 6th Main, Vijayanagar 1st Stage, Mysuru - 570017',
                  style: TextStyle(fontSize: 14.0, color: colors.neutralPrimary, height: 1.4),
                ),
                const SizedBox(height: 16.0),
                
                // Map Thumbnail Mockup
                Container(
                  width: double.infinity,
                  height: 80.0,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E9EA),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.map, color: colors.neutralBorder.withValues(alpha: 0.5), size: 40.0),
                      Positioned(
                        right: 20,
                        child: Icon(Icons.navigation, color: colors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32.0),
          
          // Job details
          const Text('Job details', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16.0),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: colors.neutralFill.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: colors.neutralBorder, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Laptop repair', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8.0),
                Text(
                  '"Need my laptop screen fixed. I dropped it yesterday and there is a massive crack down the middle."',
                  style: TextStyle(fontSize: 13.0, color: colors.neutralPrimary, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // STATE 2 — Working
  Widget _buildWorkingContent(AppColors colors, Color workerPrimary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact Customer Card
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: colors.neutralBorder, width: 1.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16.0,
                      backgroundColor: colors.neutralFill,
                      child: Icon(Icons.person, size: 16.0, color: colors.neutralPrimary),
                    ),
                    const SizedBox(width: 12.0),
                    const Text('Rahul Kumar', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700)),
                  ],
                ),
                InkWell(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: colors.lightFill,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.phone, size: 18.0, color: colors.primary),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32.0),
          
          const Text('Service', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4.0),
          const Text('Laptop repair', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24.0),
          
          const Text('Description', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4.0),
          Text(
            '"Need my laptop screen fixed. I dropped it yesterday and there is a massive crack down the middle."',
            style: TextStyle(fontSize: 14.0, color: colors.neutralPrimary),
          ),
        ],
      ),
    );
  }

  // STATE 3 — Wrap-up
  Widget _buildWrapUpContent(AppColors colors, Color workerPrimary) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 32.0),
          Container(
            width: 80.0,
            height: 80.0,
            decoration: const BoxDecoration(
              color: Color(0xFFE1F5EE),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.task_alt, size: 40.0, color: workerPrimary),
          ),
          const SizedBox(height: 32.0),
          
          Text(
            'You\'ll earn',
            style: TextStyle(fontSize: 14.0, color: colors.neutralPrimary),
          ),
          const SizedBox(height: 8.0),
          Text(
            '₹350 for this job',
            style: TextStyle(fontSize: 28.0, fontWeight: FontWeight.w700, color: workerPrimary),
          ),
          
          const SizedBox(height: 48.0),
          
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: colors.neutralFill.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: colors.neutralBorder, width: 0.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Service', style: TextStyle(fontSize: 14.0, color: colors.neutralPrimary)),
                    const Text('Laptop repair', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Time spent', style: TextStyle(fontSize: 14.0, color: colors.neutralPrimary)),
                    const Text('24 minutes', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
