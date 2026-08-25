import 'package:flutter/material.dart';
import 'theme.dart';
import 'components.dart';

class UserJobsScreen extends StatefulWidget {
  const UserJobsScreen({Key? key}) : super(key: key);

  @override
  State<UserJobsScreen> createState() => _UserJobsScreenState();
}

class _UserJobsScreenState extends State<UserJobsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Toggle this for testing
  final bool _hasScheduledJobs = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('My jobs', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        backgroundColor: colors.surface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: colors.primary,
          unselectedLabelColor: colors.neutralPrimary,
          indicatorColor: colors.primary,
          labelStyle: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Scheduled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: ACTIVE JOBS (Mocked simple content)
          _buildActiveTab(colors),
          
          // TAB 2: SCHEDULED JOBS (The critical new feature)
          _buildScheduledTab(colors),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 2, // Jobs tab is active
        onTap: (index) {},
        mode: 'user',
      ),
    );
  }

  Widget _buildActiveTab(AppColors colors) {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        JobCard(
          title: 'AC Maintenance',
          date: 'Today, 2:30 PM',
          price: '850',
          status: 'in_progress',
        ),
        const SizedBox(height: 12.0),
        JobCard(
          title: 'Phone screen repair',
          date: '12 May, 2026',
          price: '1200',
          status: 'completed',
        ),
      ],
    );
  }

  Widget _buildScheduledTab(AppColors colors) {
    if (!_hasScheduledJobs) {
      // EMPTY STATE
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month, size: 48.0, color: colors.neutralBorder),
              const SizedBox(height: 16.0),
              Text(
                'No upcoming jobs.',
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
              const SizedBox(height: 8.0),
              Text(
                'Schedule tasks ahead of time and we guarantee a worker.',
                style: TextStyle(fontSize: 13.0, color: colors.neutralPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24.0),
              PrimaryButton(
                text: 'Schedule one',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
    }

    // POPULATED STATE
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        _buildScheduledCard(
          service: 'Plumber',
          date: 'Tomorrow, 3:00 PM',
          isConfirmed: true,
          colors: colors,
        ),
        const SizedBox(height: 16.0),
        _buildScheduledCard(
          service: 'Laptop repair',
          date: 'Saturday, 10:00 AM',
          isConfirmed: false, // Pending state
          colors: colors,
        ),
      ],
    );
  }

  Widget _buildScheduledCard({
    required String service, 
    required String date, 
    required bool isConfirmed,
    required AppColors colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: colors.neutralBorder, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service, style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                  const SizedBox(height: 4.0),
                  Text(date, style: TextStyle(fontSize: 13.0, color: colors.neutralPrimary)),
                ],
              ),
              
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: isConfirmed ? colors.successPrimary.withValues(alpha: 0.1) : colors.warningFill,
                  borderRadius: BorderRadius.circular(100.0),
                  border: Border.all(
                    color: isConfirmed ? colors.successPrimary : colors.warningBorder,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  isConfirmed ? 'Confirmed' : 'Pending',
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w600,
                    color: isConfirmed ? colors.successPrimary : colors.warningPrimary,
                  ),
                ),
              ),
            ],
          ),
          
          if (!isConfirmed) ...[
            const SizedBox(height: 16.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: colors.neutralFill.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16.0, color: colors.neutralPrimary),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      "We're confirming your worker. You'll get an SMS.",
                      style: TextStyle(fontSize: 11.0, color: colors.neutralPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Optionally show who the worker is if confirmed
            const SizedBox(height: 16.0),
            Row(
              children: [
                CircleAvatar(
                  radius: 12.0,
                  backgroundColor: colors.lightFill,
                  child: Icon(Icons.person, size: 14.0, color: colors.primary),
                ),
                const SizedBox(width: 8.0),
                Text('Worker assigned', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500, color: colors.successPrimary)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
