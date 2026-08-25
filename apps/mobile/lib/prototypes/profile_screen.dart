import 'package:flutter/material.dart';
import 'theme.dart';
import 'components.dart';

class ProfileScreen extends StatelessWidget {
  final String role; // 'user' or 'worker'
  
  // Dummy data for the UI
  final String name = 'Rahul Kumar';
  final String phone = '+91 9876543210';
  final String city = 'Mysuru';
  final int jobsCount = 12;
  final double rating = 4.8;
  final bool isOnline = true; // Worker only

  const ProfileScreen({Key? key, required this.role}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final bool isWorker = role == 'worker';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: CustomAppBar(
        title: isWorker ? 'Worker profile' : 'User profile',
        action: TextButton(
          onPressed: () {
            // Edit profile action
          },
          child: Text(
            'Edit',
            style: TextStyle(
              color: colors.primary,
              fontSize: 14.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32.0),
            
            // Avatar
            CircleAvatar(
              radius: 24.0, // 48dp total diameter
              backgroundColor: colors.lightFill,
              child: Text(
                'RK',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            
            // Name
            Text(
              name,
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4.0),
            
            // Phone & City
            Text(
              '$phone • $city',
              style: TextStyle(
                fontSize: 13.0,
                color: colors.neutralPrimary,
              ),
            ),
            const SizedBox(height: 24.0),
            
            // Stats Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatColumn(
                      context,
                      isWorker ? 'Jobs done' : 'Jobs booked',
                      jobsCount.toString(),
                      colors,
                    ),
                  ),
                  Container(
                    width: 1.0,
                    height: 40.0,
                    color: colors.neutralBorder,
                  ),
                  Expanded(
                    child: _buildStatColumn(
                      context,
                      'Rating',
                      '$rating ★',
                      colors,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32.0),
            
            // Worker-only Online Status Section
            if (isWorker) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: colors.neutralFill.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: colors.neutralBorder, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8.0,
                                height: 8.0,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isOnline ? colors.primary : colors.neutralPrimary,
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                'Available for jobs',
                                style: TextStyle(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          // Disabled Switch for MVP
                          Switch(
                            value: isOnline,
                            onChanged: null, // Disabled in MVP
                            activeColor: colors.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        'Workers are expected to stay online during pilot. Contact support to go offline.',
                        style: TextStyle(
                          fontSize: 10.0,
                          color: colors.warningPrimary, // amber
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24.0),
            ],
            
            // Menu Items
            _buildMenuItem(context, Icons.person_outline, 'Account settings', colors),
            _buildMenuItem(context, Icons.payment, 'Payment', colors),
            if (isWorker) _buildMenuItem(context, Icons.account_balance_wallet_outlined, 'Payout settings', colors),
            _buildMenuItem(context, Icons.notifications_none, 'Notifications', colors),
            _buildMenuItem(context, Icons.help_outline, 'Help & support', colors),
            
            const Divider(),
            
            // Switch Role Action
            InkWell(
              onTap: () {
                _showRoleSwitchModal(context, colors);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, color: colors.primary),
                    const SizedBox(width: 16.0),
                    Text(
                      isWorker ? 'Switch to User mode' : 'Switch to Worker mode',
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Logout
            InkWell(
              onTap: () {
                // Handle logout
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Row(
                  children: [
                    Icon(Icons.logout, color: colors.dangerPrimary),
                    const SizedBox(width: 16.0),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: colors.dangerPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32.0),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 3, // Profile is usually last
        onTap: (index) {},
        mode: role,
      ),
    );
  }

  Widget _buildStatColumn(BuildContext context, String label, String value, AppColors colors) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.0,
            color: colors.neutralPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, AppColors colors) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Row(
          children: [
            Icon(icon, color: colors.neutralPrimary),
            const SizedBox(width: 16.0),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.0,
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: colors.neutralBorder),
          ],
        ),
      ),
    );
  }
  
  void _showRoleSwitchModal(BuildContext context, AppColors colors) {
    // Basic placeholder for the Role Switch Modal that was cut off in the prompt.
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Switch Roles',
                style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16.0),
              Text(
                'Are you sure you want to switch your active role?',
                style: TextStyle(fontSize: 14.0, color: colors.neutralPrimary),
              ),
              const SizedBox(height: 24.0),
              PrimaryButton(
                text: 'Switch Role',
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
