import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../screens/user_home_screen.dart'; // Import ScaleOnTap

class RecentJobsList extends ConsumerWidget {
  final AsyncValue<List<Map<String, dynamic>>> recentAsync;

  const RecentJobsList({
    super.key,
    required this.recentAsync,
  });

  String _getDaysAgo(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays == 0) {
        return 'Today';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else {
        return '${diff.inDays} days ago';
      }
    } catch (_) {
      return '';
    }
  }

  Color _getAvatarColor(String skill) {
    switch (skill.toLowerCase().replaceAll(' ', '_')) {
      case 'electrician':
        return const Color(0xFFEAB308);
      case 'plumber':
        return const Color(0xFF2563EB);
      case 'laptop_repair':
        return const Color(0xFF16A34A);
      case 'phone_repair':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF4F46E5);
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.history_rounded,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'No completed bookings yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return recentAsync.when(
      data: (rows) {
        if (rows.isEmpty) {
          return _buildEmptyState(context);
        }

        return Column(
          children: rows.asMap().entries.map((entry) {
            final data = entry.value;
            final skill = data['service'] as String? ?? 'Unknown Booking';
            final created = data['created_at'] as String? ?? '';
            final amount = (data['amount'] as num? ?? 0.0).toDouble();

            final daysAgo = _getDaysAgo(created);
            final name = data['worker_name'] as String? ?? 'Rajan Kumar';
            final avatarColor = _getAvatarColor(skill);

            return Column(
              children: [
                ScaleOnTap(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/user/jobs');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: avatarColor.withValues(alpha: 0.1),
                          child: Text(
                            name.substring(0, min(2, name.length)).toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              color: avatarColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      skill,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFF1A56DB),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    daysAgo,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              amount.toStringAsFixed(0),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF64748B),
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (entry.key < rows.length - 1)
                  const Divider(
                    height: 1,
                    color: Color(0xFFE2E8F0),
                    thickness: 1,
                  ),
              ],
            );
          }).toList(),
        );
      },
      loading: () => Column(
        children: List.generate(
          2,
          (i) => Shimmer.fromColors(
            baseColor: const Color(0xFFF0F0F5),
            highlightColor: Colors.white,
            child: Container(
              height: 76,
              width: double.infinity,
              margin: EdgeInsets.only(bottom: i == 0 ? 12 : 0),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F5),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
      error: (err, stack) => _buildEmptyState(context),
    );
  }
}
