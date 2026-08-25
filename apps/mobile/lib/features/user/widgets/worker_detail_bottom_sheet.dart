import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/services/api_service.dart';

class WorkerDetailBottomSheet extends StatefulWidget {
  final String workerId;
  final String? initialName;

  const WorkerDetailBottomSheet({
    super.key,
    required this.workerId,
    this.initialName,
  });

  static Future<void> show(BuildContext context, {required String workerId, String? initialName}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WorkerDetailBottomSheet(
        workerId: workerId,
        initialName: initialName,
      ),
    );
  }

  @override
  State<WorkerDetailBottomSheet> createState() => _WorkerDetailBottomSheetState();
}

class _WorkerDetailBottomSheetState extends State<WorkerDetailBottomSheet> {
  late Future<Map<String, dynamic>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = ApiService().getWorkerPublicProfile(widget.workerId);
  }

  String _maskPhone(String phone) {
    if (phone.isEmpty) return 'Phone Available on Call';
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length >= 10) {
      final last4 = cleaned.substring(cleaned.length - 4);
      final first2 = cleaned.substring(0, 2);
      return '+91 $first2*** ***$last4';
    }
    return phone;
  }

  Future<void> _callWorker(String rawPhone) async {
    final clean = rawPhone.replaceAll(RegExp(r'\D'), '');
    final number = clean.length == 10 ? '+91$clean' : '+$clean';
    final uri = Uri.parse('tel:${number.isNotEmpty ? number : rawPhone}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open phone dialer'),
              backgroundColor: AppColors.kDanger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to make call: $e'),
            backgroundColor: AppColors.kDanger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.kUserPrimary),
              ),
            );
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.kDanger, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load worker profile',
                    style: TextStyle(color: AppColors.kTextPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: const TextStyle(color: AppColors.kTextSecond, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kUserPrimary,
                    ),
                    child: const Text('Close', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data ?? {};
          final name = data['name'] as String? ?? widget.initialName ?? 'Worker';
          final phone = data['phone'] as String? ?? '';
          final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
          final totalJobs = data['total_completed_jobs'] as int? ?? 0;
          final isVerified = data['is_verified'] as bool? ?? true;
          final isAvailable = data['is_available'] as bool? ?? true;
          final photoUrl = data['profile_photo'] as String?;
          final experience = data['experience'] as String? ?? '1+ years';
          final bio = data['bio'] as String? ?? 'Verified local service professional in Mysuru.';
          final skills = (data['skills'] as List?)?.cast<String>() ?? [];
          final reviews = (data['recent_reviews'] as List?) ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.kBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header Profile Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.kUserPrimary.withValues(alpha: 0.1),
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null || photoUrl.isEmpty
                          ? const Icon(Icons.person, size: 40, color: AppColors.kUserPrimary)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.kTextPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, color: AppColors.kSuccess, size: 20),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            skills.isNotEmpty ? skills.join(' • ') : 'Verified Service Provider',
                            style: const TextStyle(fontSize: 13, color: AppColors.kTextSecond),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isAvailable ? AppColors.kSuccess : AppColors.kTextTertiary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isAvailable ? 'Available Now' : 'Currently Busy',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isAvailable ? AppColors.kSuccess : AppColors.kTextTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(color: AppColors.kBorder),
                const SizedBox(height: 16),

                // Metrics Grid
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.star,
                        iconColor: Colors.amber,
                        label: 'Rating',
                        value: rating > 0 ? rating.toStringAsFixed(1) : 'New',
                      ),
                    ),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.check_circle_outline,
                        iconColor: AppColors.kUserPrimary,
                        label: 'Jobs Done',
                        value: '$totalJobs',
                      ),
                    ),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.work_history_outlined,
                        iconColor: Colors.purple,
                        label: 'Experience',
                        value: experience,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Bio
                const Text(
                  'About Worker',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  bio,
                  style: const TextStyle(fontSize: 13, color: AppColors.kTextSecond, height: 1.4),
                ),

                const SizedBox(height: 20),

                // Call Action Button
                ElevatedButton.icon(
                  onPressed: phone.isNotEmpty ? () => _callWorker(phone) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kSuccess,
                    disabledBackgroundColor: AppColors.kSuccess.withValues(alpha: 0.4),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.phone, color: Colors.white),
                  label: Text(
                    'Call Worker (${_maskPhone(phone)})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),

                const SizedBox(height: 24),

                // Customer Reviews Section
                const Text(
                  'Recent Customer Reviews',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary),
                ),
                const SizedBox(height: 12),

                if (reviews.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.kBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.kBorder, width: 0.5),
                    ),
                    child: const Text(
                      'No review comments written yet.',
                      style: TextStyle(fontSize: 13, color: AppColors.kTextTertiary),
                    ),
                  )
                else
                  Column(
                    children: reviews.map((rev) {
                      final rName = rev['reviewer_name'] ?? 'Customer';
                      final rRating = (rev['rating'] as num?)?.toDouble() ?? 5.0;
                      final rComment = rev['comment'] ?? 'Great service!';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.kBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.kBorder, width: 0.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  rName,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      rRating.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              rComment,
                              style: const TextStyle(fontSize: 12, color: AppColors.kTextSecond),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.kBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.kBorder, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.kTextTertiary),
          ),
        ],
      ),
    );
  }
}
