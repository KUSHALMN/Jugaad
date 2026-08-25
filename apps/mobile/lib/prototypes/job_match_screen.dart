import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'theme.dart';
import 'components.dart';

enum MatchState { searching, fallback, assigned, tracking }

class JobMatchScreen extends StatefulWidget {
  const JobMatchScreen({Key? key}) : super(key: key);

  @override
  State<JobMatchScreen> createState() => _JobMatchScreenState();
}

class _JobMatchScreenState extends State<JobMatchScreen> with TickerProviderStateMixin {
  // Toggle this to test different states manually
  MatchState _currentState = MatchState.searching;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late AnimationController _countdownController;

  @override
  void initState() {
    super.initState();
    
    // Pulsing Ring Animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Indeterminate Progress Bar Animation
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // 60s Countdown Bar
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..forward();
    
    // Simulate fallback state after a few seconds for testing purposes
    // In real app, this happens at 90s.
    if (_currentState == MatchState.searching) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _currentState == MatchState.searching) {
          setState(() {
            _currentState = MatchState.fallback;
            // Slower pulse for fallback
            _pulseController.duration = const Duration(milliseconds: 2500);
            _pulseController.repeat(reverse: true);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Scaffold(
      backgroundColor: colors.background,
      appBar: _currentState == MatchState.tracking 
        ? null // No nav bar for live tracking
        : CustomAppBar(
            title: 'Job Status',
            showBack: true,
            action: TextButton(
              onPressed: () {
                // Cycle states for dev testing
                setState(() {
                  int nextIndex = (_currentState.index + 1) % MatchState.values.length;
                  _currentState = MatchState.values[nextIndex];
                  if (_currentState == MatchState.assigned) {
                    _countdownController.reset();
                    _countdownController.forward();
                  }
                });
              },
              child: const Text('Dev: Next State'),
            ),
          ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: _buildStateContent(colors),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateContent(AppColors colors) {
    switch (_currentState) {
      case MatchState.searching:
        return _buildScreenA(colors);
      case MatchState.fallback:
        return _buildScreenA2(colors);
      case MatchState.assigned:
        return _buildScreenB(colors);
      case MatchState.tracking:
        return _buildScreenC(colors);
    }
  }

  // ==========================================
  // SCREEN A — SEARCHING
  // ==========================================
  Widget _buildScreenA(AppColors colors) {
    return Column(
      children: [
        // Indeterminate Progress Bar
        AnimatedBuilder(
          animation: _progressController,
          builder: (context, child) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: 3.0,
                color: colors.neutralFill,
                child: FractionallySizedBox(
                  widthFactor: 0.3,
                  alignment: Alignment(-1.0 + (_progressController.value * 2.0), 0),
                  child: Container(color: colors.primary),
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 64.0),
        
        // Pulsing Ring
        _buildPulsingRing(colors.primary, 44.0, 28.0),
        
        const SizedBox(height: 32.0),
        
        // Text
        Text(
          'Finding a worker nearby...',
          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700, color: colors.textPrimary),
        ),
        const SizedBox(height: 4.0),
        Text(
          'Usually takes under 2 minutes',
          style: TextStyle(fontSize: 13.0, color: colors.neutralPrimary),
        ),
        
        const SizedBox(height: 64.0),
        
        // Summary Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: colors.neutralFill.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: colors.neutralBorder, width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AC Repair', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4.0),
                    Text('Posted at 10:45 AM', style: TextStyle(fontSize: 11.0, color: colors.neutralPrimary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(color: colors.primary, width: 1.0),
                    borderRadius: BorderRadius.circular(100.0),
                  ),
                  child: Text('Right now', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w500, color: colors.primary)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SCREEN A2 — FALLBACK (REROUTE)
  // ==========================================
  Widget _buildScreenA2(AppColors colors) {
    return Column(
      children: [
        const SizedBox(height: 48.0),
        
        // Slower, Bigger Pulsing Ring
        _buildPulsingRing(colors.primary.withValues(alpha: 0.5), 64.0, 36.0),
        
        const SizedBox(height: 32.0),
        
        Text(
          'Still looking...',
          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700, color: colors.textPrimary),
        ),
        const SizedBox(height: 4.0),
        Text(
          "We've expanded your search radius.",
          style: TextStyle(fontSize: 13.0, color: colors.neutralPrimary),
        ),
        
        const SizedBox(height: 48.0),
        
        // Fallback Actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // CARD 1: Schedule instead (Amber)
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: colors.warningFill,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: colors.warningBorder, width: 1.0),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: colors.warningPrimary, size: 20.0),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Schedule for a specific time', style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4.0),
                          Text('We guarantee a worker for your preferred slot.', style: TextStyle(fontSize: 11.0, color: colors.neutralPrimary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12.0),
              SizedBox(
                height: 38.0,
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.warningPrimary,
                    side: BorderSide(color: colors.warningPrimary, width: 1.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  onPressed: () {},
                  child: const Text('Pick a time →', style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600)),
                ),
              ),
              
              const SizedBox(height: 24.0),
              
              // CARD 2: We'll call you back (Blue)
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: colors.lightFill,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: colors.neutralBorder, width: 1.0),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone, color: colors.primary, size: 20.0),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("We'll match you manually", style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4.0),
                          Text('Our team will call to confirm a worker.', style: TextStyle(fontSize: 11.0, color: colors.neutralPrimary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12.0),
              SizedBox(
                height: 38.0,
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary, width: 1.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                  onPressed: () {},
                  child: const Text('Request callback →', style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600)),
                ),
              ),
              
              const SizedBox(height: 32.0),
              
              TextButton(
                onPressed: () {},
                child: Text('Keep searching', style: TextStyle(fontSize: 12.0, color: colors.neutralPrimary, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SCREEN B — WORKER ASSIGNED
  // ==========================================
  Widget _buildScreenB(AppColors colors) {
    return Column(
      children: [
        // Green Banner
        Container(
          width: double.infinity,
          color: colors.successPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          child: Column(
            children: [
              const Text(
                'Worker found',
                style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 4.0),
              Text(
                'Accept within 60 seconds',
                style: TextStyle(fontSize: 13.0, color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
          ),
        ),
        
        // Red countdown bar
        AnimatedBuilder(
          animation: _countdownController,
          builder: (context, child) {
            return Container(
              width: MediaQuery.of(context).size.width,
              height: 4.0,
              alignment: Alignment.centerLeft,
              color: colors.neutralFill,
              child: FractionallySizedBox(
                widthFactor: 1.0 - _countdownController.value,
                child: Container(color: colors.dangerPrimary),
              ),
            );
          },
        ),
        
        const SizedBox(height: 32.0),
        
        // Lean Worker Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: colors.neutralBorder, width: 0.5),
              boxShadow: [
                BoxShadow(color: colors.textPrimary.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40.0,
                  backgroundColor: colors.neutralFill,
                  child: Icon(Icons.person, size: 40.0, color: colors.neutralPrimary),
                ),
                const SizedBox(height: 16.0),
                const Text('Arun K.', style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: Color(0xFFE5A023), size: 16.0),
                    const SizedBox(width: 4.0),
                    const Text('4.9', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12.0),
                    Container(width: 4.0, height: 4.0, decoration: BoxDecoration(color: colors.neutralBorder, shape: BoxShape.circle)),
                    const SizedBox(width: 12.0),
                    Text('12 min away', style: TextStyle(fontSize: 14.0, color: colors.neutralPrimary)),
                    const SizedBox(width: 12.0),
                    Container(width: 4.0, height: 4.0, decoration: BoxDecoration(color: colors.neutralBorder, shape: BoxShape.circle)),
                    const SizedBox(width: 12.0),
                    Text('2.1 km', style: TextStyle(fontSize: 14.0, color: colors.neutralPrimary)),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 48.0),
        
        // Button Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48.0,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.neutralPrimary,
                      side: BorderSide(color: colors.neutralBorder, width: 1.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                    ),
                    onPressed: () {},
                    child: const Text('Decline'),
                  ),
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: SizedBox(
                  height: 48.0,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.successPrimary, // Green
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                    ),
                    onPressed: () {},
                    child: const Text('Accept worker', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),
        Text('Declining resumes search.', style: TextStyle(fontSize: 12.0, color: colors.neutralPrimary)),
      ],
    );
  }

  // ==========================================
  // SCREEN C — LIVE TRACKING
  // ==========================================
  Widget _buildScreenC(AppColors colors) {
    return Column(
      children: [
        // Map Placeholder (100dp)
        Container(
          width: double.infinity,
          height: 100.0,
          color: const Color(0xFFE5E9EA), // Map background color mockup
          child: Stack(
            children: [
              // Fake routes
              Positioned.fill(
                child: CustomPaint(
                  painter: _MockRoutePainter(colors.primary),
                ),
              ),
              // Worker Pin
              Positioned(
                left: 80,
                top: 40,
                child: Icon(Icons.motorcycle, color: colors.primary, size: 24.0),
              ),
              // User Pin
              Positioned(
                right: 80,
                top: 60,
                child: Icon(Icons.location_on, color: colors.dangerPrimary, size: 24.0),
              ),
            ],
          ),
        ),
        
        // Status Bar
        Container(
          width: double.infinity,
          color: colors.warningFill,
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          alignment: Alignment.center,
          child: Text(
            'On the way · 8 mins',
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w700,
              color: colors.warningPrimary,
            ),
          ),
        ),
        
        // Compact Worker Card
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24.0,
                backgroundColor: colors.neutralFill,
                child: Icon(Icons.person, color: colors.neutralPrimary),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Arun K.', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2.0),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFE5A023), size: 12.0),
                        const SizedBox(width: 4.0),
                        Text('4.9 (120 jobs)', style: TextStyle(fontSize: 12.0, color: colors.neutralPrimary)),
                      ],
                    ),
                  ],
                ),
              ),
              SurfaceIconButton(
                icon: Icons.chat_bubble_outline,
                onPressed: () {},
              ),
              const SizedBox(width: 12.0),
              SurfaceIconButton(
                icon: Icons.phone_outlined,
                onPressed: () {},
                isActive: true, // green tint if worker mode color was active, else blue
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper for pulsing ring
  Widget _buildPulsingRing(Color color, double outerSize, double innerSize) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: outerSize + (_pulseController.value * 20.0),
          height: outerSize + (_pulseController.value * 20.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.1 + (0.1 * (1 - _pulseController.value))),
          ),
          alignment: Alignment.center,
          child: Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        );
      },
    );
  }
}

// Just a tiny custom painter to make the map placeholder look slightly better
class _MockRoutePainter extends CustomPainter {
  final Color routeColor;
  _MockRoutePainter(this.routeColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = routeColor.withValues(alpha: 0.5)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
      
    final path = Path()
      ..moveTo(90, 50)
      ..quadraticBezierTo(size.width / 2, 20, size.width - 70, 70);
      
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
