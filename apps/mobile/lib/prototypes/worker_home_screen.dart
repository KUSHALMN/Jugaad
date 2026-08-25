import 'package:flutter/material.dart';
import 'theme.dart';
import 'components.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({Key? key}) : super(key: key);

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  // Toggle states
  bool _isOnline = true;
  final bool _hasActiveJob = true; // Toggle for preview

  @override
  Widget build(BuildContext context) {
    // We assume worker mode colors are active in the theme
    final colors = Theme.of(context).extension<AppColors>()!;
    
    // Explicit worker colors for precision in case theme is global
    final Color workerPrimary = const Color(0xFF0F6E56);
    final Color workerLightFill = const Color(0xFFE1F5EE);
    final Color workerBorder = const Color(0xFF5DCAA5);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header / Status Bar Area
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      // "Worker" Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: workerLightFill,
                          borderRadius: BorderRadius.circular(100.0),
                          border: Border.all(color: workerBorder, width: 1.0),
                        ),
                        child: Text(
                          'WORKER',
                          style: TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w700,
                            color: workerPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Text(
                        'Hi Arun',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Earnings today',
                        style: TextStyle(
                          fontSize: 11.0,
                          color: colors.neutralPrimary,
                        ),
                      ),
                      Text(
                        '₹450',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // DOMINANT ONLINE STATUS TOGGLE
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: colors.neutralFill.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: colors.neutralBorder, width: 0.5),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isOnline = !_isOnline;
                              });
                            },
                            borderRadius: BorderRadius.circular(8.0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              height: 52.0,
                              decoration: BoxDecoration(
                                color: _isOnline ? workerLightFill : colors.neutralFill,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: _isOnline ? workerPrimary : colors.neutralBorder,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 10.0,
                                    height: 10.0,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isOnline ? workerPrimary : colors.neutralPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 12.0),
                                  Text(
                                    _isOnline ? "You're online · Receiving jobs" : "You're offline",
                                    style: TextStyle(
                                      fontSize: 15.0,
                                      fontWeight: FontWeight.w700,
                                      color: _isOnline ? workerPrimary : colors.neutralPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          Text(
                            'Stay online to get more jobs. Workers online get priority.',
                            style: TextStyle(
                              fontSize: 10.0,
                              fontWeight: FontWeight.w600,
                              color: colors.warningPrimary, // amber
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24.0),
                    
                    // ACTIVE JOB BANNER
                    if (_hasActiveJob) ...[
                      InkWell(
                        onTap: () {
                          // Navigate to active job
                        },
                        child: Container(
                          width: double.infinity,
                          height: 56.0,
                          color: workerLightFill,
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6.0),
                                decoration: BoxDecoration(
                                  color: workerPrimary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.build, size: 14.0, color: Colors.white),
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Text(
                                  'Active job: Laptop repair · 2.1 km away',
                                  style: TextStyle(
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.w700,
                                    color: workerPrimary,
                                  ),
                                ),
                              ),
                              Icon(Icons.chevron_right, color: workerPrimary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24.0),
                    ],
                    
                    // EARNINGS SUMMARY CARD
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: colors.neutralFill.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: colors.neutralBorder, width: 0.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'THIS WEEK',
                              style: TextStyle(
                                fontSize: 9.0,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                color: colors.neutralPrimary,
                              ),
                            ),
                            const SizedBox(height: 12.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '₹1,840',
                                      style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w700, color: colors.textPrimary),
                                    ),
                                    const SizedBox(height: 2.0),
                                    Text('earned · 6 jobs', style: TextStyle(fontSize: 12.0, color: colors.neutralPrimary)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹600 pending payout',
                                      style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600, color: colors.warningPrimary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32.0),
                    
                    // RECENT JOBS LIST
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent jobs',
                            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700, color: colors.textPrimary),
                          ),
                          Text(
                            'See all →',
                            style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: colors.primary), // standard blue link
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Recent Jobs
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          _buildRecentJobTile('Rahul Kumar', 'Laptop repair', 'Yesterday', '₹450', 'completed', Icons.laptop_mac, colors),
                          const SizedBox(height: 12.0),
                          _buildRecentJobTile('Sneha V.', 'Phone screen', '12 May', '₹800', 'completed', Icons.phone_android, colors),
                          const SizedBox(height: 12.0),
                          _buildRecentJobTile('Karthik M.', 'AC Checkup', '10 May', '₹590', 'cancelled', Icons.ac_unit, colors),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 0,
        onTap: (index) {},
        mode: 'worker', // Will render Home, Active Job, Earnings, Profile
      ),
    );
  }

  Widget _buildRecentJobTile(String clientName, String service, String date, String price, String status, IconData icon, AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: colors.neutralBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: colors.neutralFill,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16.0, color: colors.neutralPrimary),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clientName, style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                const SizedBox(height: 2.0),
                Text('$service · $date', style: TextStyle(fontSize: 11.0, color: colors.neutralPrimary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w700, color: colors.textPrimary)),
              const SizedBox(height: 6.0),
              StatusPill(status: status), // Uses the pill from components.dart
            ],
          ),
        ],
      ),
    );
  }
}
