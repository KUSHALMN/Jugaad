import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:jugaad_mvp/core/theme/user_app_theme.dart';
import 'package:jugaad_mvp/shared/widgets/jugaad_card.dart';
import 'package:shimmer/shimmer.dart';
import 'package:jugaad_mvp/shared/widgets/status_badge.dart';

import 'user_account_settings_screen.dart';
import 'user_notification_settings_screen.dart';
import 'payment_history_screen.dart';
import 'bookings_history_screen.dart';
import 'edit_user_profile_screen.dart';
import 'saved_addresses_screen.dart';
import '../../shared/screens/help_support_screen.dart';

class UserPortalScreen extends StatefulWidget {
  final VoidCallback onSwitchMode;
  const UserPortalScreen({super.key, required this.onSwitchMode});

  @override
  State<UserPortalScreen> createState() => _UserPortalScreenState();
}

class _UserPortalScreenState extends State<UserPortalScreen> {
  String _getInitials(String name) {
    if (name.trim().isEmpty) return '??';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  String _formatMemberSince(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is String) {
      final date = DateTime.tryParse(timestamp);
      if (date == null) return 'N/A';
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[date.month - 1]} ${date.year}';
    }
    return 'N/A';
  }

  String _formatScheduledDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is String) {
      final date = DateTime.tryParse(timestamp)?.toLocal();
      if (date == null) return 'N/A';
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
    return 'N/A';
  }

  BadgeStatus _getBadgeStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return BadgeStatus.pending;
      case 'confirmed':
      case 'active':
      case 'searching':
        return BadgeStatus.active;
      case 'in_progress':
        return BadgeStatus.inProgress;
      case 'completed':
        return BadgeStatus.completed;
      case 'cancelled':
        return BadgeStatus.cancelled;
      case 'assigned':
        return BadgeStatus.assigned;
      default:
        return BadgeStatus.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseConfig.client.from('users').stream(primaryKey: ['id']).eq('id', uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData && !snapshot.hasError) {
          return Scaffold(
            backgroundColor: UserAppTheme.background,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _buildSkeleton(),
              ),
            ),
          );
        }

        final list = (snapshot.hasData && snapshot.data != null) ? snapshot.data! : <Map<String, dynamic>>[];
        final data = list.isNotEmpty ? list.first : <String, dynamic>{};
        String name = data['name'] as String? ?? '';
        if (name.trim().isEmpty || name == 'No Name') {
          final user = FirebaseAuth.instance.currentUser;
          final firebaseName = user?.displayName;
          if (firebaseName != null && firebaseName.trim().isNotEmpty) {
            name = firebaseName;
          } else {
            final email = user?.email;
            if (email != null && email.contains('@')) {
              name = email.split('@').first;
            } else {
              name = 'No Name';
            }
          }
        }
        final phone = data['phone'] as String? ?? '';
        final initials = _getInitials(name);

        return Scaffold(
          backgroundColor: UserAppTheme.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: UserAppTheme.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'User Account',
              style: UserAppTheme.heading(size: 20, weight: FontWeight.w800, color: UserAppTheme.textPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditUserProfileScreen(currentData: data),
                    ),
                  );
                },
                child: Text(
                  'Edit',
                  style: UserAppTheme.body(color: UserAppTheme.primaryBlue, weight: FontWeight.bold),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 16),
                
                // Profile Header Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: JugaadCard(
                    borderRadius: 24.0,
                    color: UserAppTheme.surface,
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4.0),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: UserAppTheme.primaryBlue.withValues(alpha: 0.2),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 36,
                                  backgroundColor: UserAppTheme.primaryBlue.withValues(alpha: 0.1),
                                  child: Text(
                                    initials,
                                    style: UserAppTheme.heading(size: 24, weight: FontWeight.w800, color: UserAppTheme.primaryBlue),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                name,
                                style: UserAppTheme.heading(size: 20, weight: FontWeight.w800, color: UserAppTheme.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                phone.isNotEmpty ? '$phone · Mysuru' : 'Mysuru',
                                style: UserAppTheme.body(color: UserAppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: UserAppTheme.primaryBlue.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    StreamBuilder<List<Map<String, dynamic>>>(
                                      stream: SupabaseConfig.client
                                          .from('jobs')
                                          .stream(primaryKey: ['id'])
                                          .eq('employer_id', uid),
                                      builder: (context, bookingsSnap) {
                                        final count = bookingsSnap.data?.length ?? 0;
                                        return Text(
                                          '$count',
                                          style: UserAppTheme.heading(size: 20, weight: FontWeight.w800, color: UserAppTheme.primaryBlue),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total Bookings',
                                      style: UserAppTheme.label(weight: FontWeight.w700, color: UserAppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: UserAppTheme.primaryBlue.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _formatMemberSince(data['created_at']),
                                      style: UserAppTheme.heading(size: 16, weight: FontWeight.w800, color: UserAppTheme.primaryBlue),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Member Since',
                                      style: UserAppTheme.label(weight: FontWeight.w700, color: UserAppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),

                // Portal Switcher
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: JugaadCard(
                    borderRadius: 20.0,
                    color: UserAppTheme.surface,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.swap_horizontal_circle_outlined,
                              color: UserAppTheme.primaryBlue,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'PORTAL SELECTOR',
                              style: UserAppTheme.label(
                                color: UserAppTheme.textSecondary,
                                weight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(5.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: UserAppTheme.primaryBlue,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: UserAppTheme.primaryBlue.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'User Portal',
                                    style: UserAppTheme.body(
                                      color: Colors.white,
                                      weight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: GestureDetector(
                                  onTap: widget.onSwitchMode,
                                  child: Container(
                                    height: 40,
                                    decoration: const BoxDecoration(
                                      color: Colors.transparent,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Worker Portal',
                                      style: UserAppTheme.body(
                                        color: UserAppTheme.textSecondary,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // My Bookings Section (Task U3)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'My Bookings',
                            style: UserAppTheme.heading(size: 18, weight: FontWeight.w800, color: UserAppTheme.textPrimary),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const BookingsHistoryScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'View all',
                              style: UserAppTheme.body(color: UserAppTheme.primaryBlue, weight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: SupabaseConfig.client
                            .from('jobs')
                            .stream(primaryKey: ['id'])
                            .eq('employer_id', uid),
                        builder: (context, bookingsSnap) {
                          if (bookingsSnap.hasError) {
                            return Center(
                              child: Text('Error loading bookings: ${bookingsSnap.error}'),
                            );
                          }
                          if (bookingsSnap.connectionState == ConnectionState.waiting) {
                            // BUG FIX
                            return Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Column(
                                children: List.generate(3, (_) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: _skeletonBox(double.infinity, 80),
                                )),
                              ),
                            );
                          }

                          final docs = bookingsSnap.data ?? [];
                          final sortedDocs = List<Map<String, dynamic>>.from(docs)
                            ..sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
                          final displayDocs = sortedDocs.take(5).toList();

                          if (displayDocs.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  Icon(Icons.bookmark_outline_rounded, color: UserAppTheme.textSecondary.withValues(alpha: 0.3), size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No bookings yet',
                                    style: UserAppTheme.body(size: 16, color: UserAppTheme.textSecondary, weight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Book highly rated hyperlocal professionals for all your needs.',
                                    style: UserAppTheme.body(size: 13, color: UserAppTheme.textSecondary),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                             shrinkWrap: true,
                             physics: const NeverScrollableScrollPhysics(),
                             itemCount: displayDocs.length,
                             itemBuilder: (context, index) {
                               final b = displayDocs[index];
                               final service = b['skill_required'] as String? ?? 'Service';
                               final status = b['status'] as String? ?? 'pending';
                               final dateStr = _formatScheduledDate(b['scheduled_at']);
                               final amount = (b['amount'] as num? ?? 0.0).toDouble();

                               return Card(
                                 margin: const EdgeInsets.only(bottom: 12.0),
                                 elevation: 0,
                                 shape: RoundedRectangleBorder(
                                   borderRadius: BorderRadius.circular(UserAppTheme.cardRadius),
                                   side: BorderSide(color: UserAppTheme.divider, width: 1.0),
                                 ),
                                 color: UserAppTheme.surface,
                                 child: Padding(
                                   padding: const EdgeInsets.all(16.0),
                                   child: Row(
                                     children: [
                                       Expanded(
                                         child: Column(
                                           crossAxisAlignment: CrossAxisAlignment.start,
                                           children: [
                                             Text(
                                               service,
                                               style: UserAppTheme.body(size: 16, weight: FontWeight.w700, color: UserAppTheme.textPrimary),
                                             ),
                                             const SizedBox(height: 4),
                                             Text(
                                               'Date: $dateStr',
                                               style: UserAppTheme.label(color: UserAppTheme.textSecondary),
                                             ),
                                             const SizedBox(height: 4),
                                             Text(
                                               '₹${amount.toStringAsFixed(0)}',
                                               style: UserAppTheme.body(weight: FontWeight.w800, color: UserAppTheme.primaryBlue),
                                             ),
                                           ],
                                         ),
                                       ),
                                       const SizedBox(width: 8),
                                       StatusBadge(
                                         status: _getBadgeStatus(status),
                                         color: status == 'completed' || status == 'in_progress' ? UserAppTheme.successGreen : UserAppTheme.primaryBlue,
                                       ),
                                     ],
                                   ),
                                 ),
                               );
                             },
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Saved Addresses & Settings
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: JugaadCard(
                    borderRadius: UserAppTheme.cardRadius,
                    color: UserAppTheme.surface,
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        _buildMenuListItem(
                          context,
                          Icons.location_on_outlined,
                          'Saved addresses',
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedAddressesScreen())),
                        ),
                        _buildMenuListItem(
                          context,
                          Icons.person_outline_rounded,
                          'Account settings',
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserAccountSettingsScreen(currentData: data))),
                        ),
                        _buildMenuListItem(
                          context,
                          Icons.notifications_none_rounded,
                          'Notification settings',
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => UserNotificationSettingsScreen(currentData: data))),
                        ),
                        _buildMenuListItem(
                          context,
                          Icons.history_rounded,
                          'Payment history',
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentHistoryScreen())),
                        ),
                        _buildMenuListItem(
                          context,
                          Icons.help_outline_rounded,
                          'Help & support',
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpSupportScreen())),
                        ),
                        InkWell(
                          onTap: () async {
                            await FirebaseAuth.instance.signOut();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6.0),
                                  decoration: BoxDecoration(
                                    color: UserAppTheme.urgentRed.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.logout_rounded,
                                    color: UserAppTheme.urgentRed,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Logout',
                                  style: UserAppTheme.body(
                                    color: UserAppTheme.urgentRed,
                                    weight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuListItem(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: UserAppTheme.divider,
              width: 0.8,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: UserAppTheme.primaryBlue.withValues(alpha: 0.7), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: UserAppTheme.body(
                  color: UserAppTheme.textPrimary,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: UserAppTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // BUG FIX
  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header skeleton
          Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 12),
          // Chips row skeleton
          Row(children: [
            _skeletonBox(120, 36),
            const SizedBox(width: 8),
            _skeletonBox(100, 36),
          ]),
          const SizedBox(height: 12),
          // List items skeleton
          ...List.generate(4, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _skeletonBox(double.infinity, 52),
          )),
        ],
      ),
    );
  }

  // BUG FIX
  Widget _skeletonBox(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
