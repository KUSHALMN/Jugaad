import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../../common/screens/legal_policy_screen.dart';

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

  User? _safeCurrentUser() {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  Stream<List<Map<String, dynamic>>> _safeUserStream(String uid) {
    try {
      if (uid.isEmpty) return Stream.value([]);
      return SupabaseConfig.client.from('users').stream(primaryKey: ['id']).eq('id', uid);
    } catch (_) {
      return Stream.value([]);
    }
  }

  Stream<List<Map<String, dynamic>>> _safeJobsStream(String uid) {
    try {
      if (uid.isEmpty) return Stream.value([]);
      return SupabaseConfig.client.from('jobs').stream(primaryKey: ['id']).eq('employer_id', uid);
    } catch (_) {
      return Stream.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _safeCurrentUser();
    final uid = user?.uid ?? '';

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _safeUserStream(uid),
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
          final firebaseName = user?.displayName;
          if (firebaseName != null && firebaseName.trim().isNotEmpty) {
            name = firebaseName;
          } else {
            final email = user?.email;
            if (email != null && email.contains('@')) {
              name = email.split('@').first;
            } else {
              name = 'nisha';
            }
          }
        }
        final phone = data['phone'] as String? ?? '';
        final city = (data['city'] as String?)?.trim().isNotEmpty == true ? data['city'] as String : 'Mysuru';
        final userRating = data['rating'];
        final ratingStr = userRating != null ? double.tryParse(userRating.toString())?.toStringAsFixed(1) ?? '—' : '—';
        final initials = _getInitials(name);
        final memberSinceStr = _formatMemberSince(data['created_at']);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
              onPressed: () {
                try {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/user/home');
                  }
                } catch (_) {
                  Navigator.maybePop(context);
                }
              },
            ),
            title: Text(
              'User Account',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditUserProfileScreen(currentData: data),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_rounded, color: Color(0xFF15803D), size: 15),
                          const SizedBox(width: 6),
                          Text(
                            'Edit Profile',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 12),

                // Redesigned Profile Hero Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.white, Color(0xFFF0FDF4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24.0),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Subtle Cityscape Watermark on Right
                        Positioned(
                          right: 16,
                          top: 18,
                          child: Icon(
                            Icons.location_city_rounded,
                            size: 110,
                            color: const Color(0xFF16A34A).withValues(alpha: 0.06),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(22.0),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 540;

                              final avatarWidget = GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditUserProfileScreen(currentData: data),
                                    ),
                                  );
                                },
                                child: Stack(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4.0),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        border: Border.all(color: const Color(0xFFDCFCE7), width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                            blurRadius: 14,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 42,
                                        backgroundColor: const Color(0xFFECFDF5),
                                        child: Text(
                                          initials,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF15803D),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 2,
                                      right: 2,
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF16A34A),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2.2),
                                        ),
                                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              final userDetailsBlock = Column(
                                crossAxisAlignment: isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 4,
                                    alignment: isWide ? WrapAlignment.start : WrapAlignment.center,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (phone.isNotEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.phone_rounded, color: Color(0xFF16A34A), size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              phone,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF475569),
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (phone.isNotEmpty)
                                        const Text('|', style: TextStyle(color: Color(0xFFCBD5E1))),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.location_on_rounded, color: Color(0xFF16A34A), size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            city,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF475569),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(50),
                                      border: Border.all(color: const Color(0xFFBBF7D0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, color: Color(0xFF15803D), size: 12),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Member since $memberSinceStr',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF15803D),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // 2 KPI Stat Cards: Total Bookings (Mint) + Your Rating (Amber)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0FDF4),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: const Color(0xFFDCFCE7)),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFDCFCE7),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.event_note_rounded, color: Color(0xFF16A34A), size: 18),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  StreamBuilder<List<Map<String, dynamic>>>(
                                                    stream: _safeJobsStream(uid),
                                                    builder: (context, bookingsSnap) {
                                                      final count = bookingsSnap.data?.length ?? 0;
                                                      return Text(
                                                        '$count',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.w800,
                                                          color: const Color(0xFF0F172A),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  Text(
                                                    'Total Bookings',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF475569),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFFBEB),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: const Color(0xFFFEF3C7)),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFFEF3C7),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 20),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    ratingStr,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w800,
                                                      color: const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  Text(
                                                    'Your Rating',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF475569),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );

                              if (isWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    avatarWidget,
                                    const SizedBox(width: 24),
                                    Expanded(child: userDetailsBlock),
                                  ],
                                );
                              }
                              return Column(
                                children: [
                                  avatarWidget,
                                  const SizedBox(height: 14),
                                  userDetailsBlock,
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Redesigned Portal Selector Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 620;

                        final headerBlock = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.layers_rounded, color: Color(0xFF16A34A), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Portal Selector',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Choose how you want to use Jugaad',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );

                        final userPortalCard = Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_rounded, color: Colors.white, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'User Portal',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'Book services, track jobs and more',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 15),
                              ),
                            ],
                          ),
                        );

                        final workerPortalCard = InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            widget.onSwitchMode();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.engineering_rounded, color: Color(0xFF16A34A), size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Worker Portal',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFF0F172A),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        'Offer your services and get jobs',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFF64748B),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );

                        if (isWide) {
                          return Row(
                            children: [
                              headerBlock,
                              const SizedBox(width: 20),
                              Expanded(child: userPortalCard),
                              const SizedBox(width: 12),
                              Expanded(child: workerPortalCard),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            headerBlock,
                            const SizedBox(height: 14),
                            userPortalCard,
                            const SizedBox(height: 10),
                            workerPortalCard,
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // My Bookings Section
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
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View all',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF16A34A),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded, color: Color(0xFF16A34A), size: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _safeJobsStream(uid),
                        builder: (context, bookingsSnap) {
                          if (bookingsSnap.hasError) {
                            return Center(
                              child: Text('Error loading bookings: ${bookingsSnap.error}'),
                            );
                          }
                          if (bookingsSnap.connectionState == ConnectionState.waiting && !bookingsSnap.hasData) {
                            return Shimmer.fromColors(
                              baseColor: const Color(0xFFF1F5F9),
                              highlightColor: Colors.white,
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
                              padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 20.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.event_note_rounded, color: Color(0xFF16A34A), size: 30),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No bookings yet',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Your booked services will appear here.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: const Color(0xFF64748B),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      try {
                                        context.go('/user/workers');
                                      } catch (_) {
                                        Navigator.maybePop(context);
                                      }
                                    },
                                    icon: const Icon(Icons.search_rounded, size: 18, color: Colors.white),
                                    label: Text(
                                      'Find & Book a Service',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF16A34A),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                    ),
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
                        _buildMenuListItem(
                          context,
                          Icons.shield_outlined,
                          'Privacy, Terms & Grievance',
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LegalPolicyScreen())),
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

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFF1F5F9),
      highlightColor: Colors.white,
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
