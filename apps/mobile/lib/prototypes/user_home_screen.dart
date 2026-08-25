import 'package:flutter/material.dart';
import 'theme.dart';
import 'components.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({Key? key}) : super(key: key);

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  // Toggle this to see the populated recent jobs state
  final bool _hasRecentJobs = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi Rahul 👋',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        'Ready to book?',
                        style: TextStyle(
                          fontSize: 12.0,
                          color: colors.neutralPrimary,
                        ),
                      ),
                    ],
                  ),
                  // "User" Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: colors.lightFill, // blue tint
                      borderRadius: BorderRadius.circular(100.0),
                      border: Border.all(color: colors.neutralBorder, width: 1.0),
                    ),
                    child: Text(
                      'USER',
                      style: TextStyle(
                        fontSize: 10.0,
                        fontWeight: FontWeight.w700,
                        color: colors.primary, // blue
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Container(
                        height: 44.0,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: colors.neutralBorder, width: 1.0),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12.0),
                            Icon(Icons.search, size: 20.0, color: colors.neutralPrimary),
                            const SizedBox(width: 8.0),
                            Text(
                              'What do you need help with?',
                              style: TextStyle(
                                fontSize: 13.0,
                                color: colors.neutralPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    
                    // SPEED SIGNAL BANNER
                    Container(
                      width: double.infinity,
                      height: 48.0,
                      color: colors.warningFill, // amber tint
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('⚡'),
                          const SizedBox(width: 8.0),
                          Text(
                            'Workers near you — avg arrival 18 mins',
                            style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w700,
                              color: colors.warningPrimary, // amber bold
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    
                    // Service Category Grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Categories',
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          Row(
                            children: [
                              Expanded(child: _buildCategoryCard('Laptop repair', Icons.laptop_mac, '12 nearby', colors)),
                              const SizedBox(width: 8.0),
                              Expanded(child: _buildCategoryCard('Phone repair', Icons.phone_android, '18 nearby', colors)),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          Row(
                            children: [
                              Expanded(child: _buildCategoryCard('Electrician', Icons.electrical_services, '8 nearby', colors)),
                              const SizedBox(width: 8.0),
                              Expanded(child: _buildCategoryCard('Plumber', Icons.plumbing, '5 nearby', colors)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32.0),
                    
                    // RECENT Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent',
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          
                          if (_hasRecentJobs) ...[
                            // Last 2 jobs mocked
                            JobCard(
                              title: 'Phone screen repair',
                              date: 'Yesterday',
                              price: '1200',
                              status: 'completed',
                            ),
                            const SizedBox(height: 8.0),
                            JobCard(
                              title: 'AC Maintenance',
                              date: '12 May',
                              price: '500',
                              status: 'cancelled',
                            ),
                          ] else ...[
                            // Empty State
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24.0),
                              decoration: BoxDecoration(
                                color: colors.neutralFill.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(color: colors.neutralBorder, width: 0.5),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.history, color: colors.neutralBorder, size: 32.0),
                                  const SizedBox(height: 12.0),
                                  Text(
                                    'No recent jobs',
                                    style: TextStyle(
                                      fontSize: 13.0,
                                      color: colors.neutralPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 16.0),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 48.0),
                                    child: SecondaryButton(
                                      text: 'Book your first job',
                                      onPressed: () {},
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
        currentIndex: 0, // Home is active
        onTap: (index) {},
        mode: 'user', // User mode nav
      ),
    );
  }

  Widget _buildCategoryCard(String name, IconData icon, String subtitle, AppColors colors) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(10.0),
      child: Container(
        height: 80.0,
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: colors.neutralBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 24.0, color: colors.primary), // 32dp visual footprint
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9.0,
                    color: colors.neutralPrimary, // tertiary
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              name,
              style: TextStyle(
                fontSize: 11.0,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
