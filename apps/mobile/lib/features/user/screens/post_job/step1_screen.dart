import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/user_app_theme.dart';
import '../../../../core/widgets/jugaad_step_header.dart';
import '../../../../shared/widgets/jugaad_card.dart';
import '../../../../core/config/services_list.dart';
import '../../../../core/providers/services_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'post_job_state.dart';

class PostJobStep1Screen extends ConsumerStatefulWidget {
  const PostJobStep1Screen({super.key});

  @override
  ConsumerState<PostJobStep1Screen> createState() => _PostJobStep1ScreenState();
}

class _PostJobStep1ScreenState extends ConsumerState<PostJobStep1Screen> {
  String _urgency = 'now'; // 'now' | 'scheduled'
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  void _selectService(String skill) {
    final urgency = _urgency;
    DateTime? scheduledAt;

    if (urgency == 'scheduled') {
      if (_scheduledDate == null || _scheduledTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select a date and time before scheduling.',
              style: UserAppTheme.body(color: Colors.white, weight: FontWeight.w600),
            ),
            backgroundColor: UserAppTheme.urgentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }
      scheduledAt = DateTime(
        _scheduledDate!.year, _scheduledDate!.month, _scheduledDate!.day,
        _scheduledTime!.hour, _scheduledTime!.minute,
      );
    }

    ref.read(postJobProvider.notifier).setSkill(skill);
    ref.read(postJobProvider.notifier).setUrgency(urgency);
    ref.read(postJobProvider.notifier).setScheduledAt(scheduledAt);

    print('[POST_JOB] Step 1: skill=$skill, urgency=$urgency, scheduledAt=$scheduledAt');
    context.push('/user/post-job/step2');
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: UserAppTheme.primaryBlue,
              onPrimary: Colors.white,
              onSurface: UserAppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) setState(() => _scheduledDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: UserAppTheme.primaryBlue,
              onPrimary: Colors.white,
              onSurface: UserAppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) setState(() => _scheduledTime = time);
  }

  @override
  Widget build(BuildContext context) {
    final activeSkill = ref.watch(postJobProvider).skill;
    final servicesAsync = ref.watch(servicesProvider);

    return Scaffold(
      backgroundColor: UserAppTheme.background,
      body: Column(
        children: [
          JugaadStepHeader(
            title: 'What do you need help with?',
            currentStep: 1,
            totalSteps: 4,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Grid (12 services)
                  servicesAsync.when(
                    data: (servicesList) {
                      final isEmergency = ref.watch(postJobProvider).jobType == 'emergency';
                      final filteredList = servicesList.where((s) {
                        return isEmergency ? s.category == 'Emergency' : s.category != 'Emergency';
                      }).toList();
                      return _buildServicesGrid(filteredList, activeSkill);
                    },
                    loading: () => _buildShimmerGrid(),
                    error: (err, stack) {
                      final isEmergency = ref.watch(postJobProvider).jobType == 'emergency';
                      final filteredList = kAllServices.where((s) {
                        return isEmergency ? s.category == 'Emergency' : s.category != 'Emergency';
                      }).toList();
                      return _buildServicesGrid(filteredList, activeSkill);
                    },
                  ),

                  const SizedBox(height: 32),

                  // Urgency Label
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: UserAppTheme.primaryBlue, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'When do you need the service?',
                        style: UserAppTheme.body(
                          color: UserAppTheme.textPrimary,
                          weight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                  const SizedBox(height: 12),

                  // Pill Toggle (Modern design)
                  Container(
                    padding: const EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      color: UserAppTheme.surface,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: UserAppTheme.divider, width: 1.0),
                    ),
                    child: Row(
                      children: [
                        _buildUrgencyPill('Right Now (Fastest)', 'now'),
                        const SizedBox(width: 4),
                        _buildUrgencyPill('Schedule Later', 'scheduled'),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 250.ms),

                  // Date/time picker when scheduled
                  if (_urgency == 'scheduled') ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPickerTile(
                            label: _scheduledDate == null
                                ? 'Select Date'
                                : '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}',
                            icon: Icons.calendar_today_rounded,
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPickerTile(
                            label: _scheduledTime == null
                                ? 'Select Time'
                                : _scheduledTime!.format(context),
                            icon: Icons.access_time_rounded,
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 16,
                        color: UserAppTheme.textSecondary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tap any service card above to continue',
                        style: UserAppTheme.label(
                          color: UserAppTheme.textSecondary,
                          weight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgencyPill(String label, String value) {
    final selected = _urgency == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _urgency = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? UserAppTheme.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: UserAppTheme.primaryBlue.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Text(
            label,
            style: UserAppTheme.body(
              color: selected ? Colors.white : UserAppTheme.textSecondary,
              weight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickerTile({required String label, required IconData icon, required VoidCallback onTap}) {
    return JugaadCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 14.0,
      onTap: onTap,
      animate: false,
      child: Row(
        children: [
          Icon(icon, size: 18, color: UserAppTheme.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: UserAppTheme.body(
                color: UserAppTheme.textPrimary,
                weight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesGrid(List<ServiceDef> services, String activeSkill) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: services.asMap().entries.map((entry) {
        final index = entry.key;
        final s = entry.value;
        final title = s.title;
        final icon = s.icon;
        final isSelected = activeSkill == title;

        return JugaadCard(
          index: index,
          borderRadius: 16.0,
          color: isSelected ? UserAppTheme.primaryBlue.withValues(alpha: 0.08) : UserAppTheme.surface,
          padding: const EdgeInsets.all(16),
          onTap: () => _selectService(title),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : UserAppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Icon(
                      icon,
                      color: UserAppTheme.primaryBlue,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: UserAppTheme.body(
                      size: 15,
                      color: isSelected ? UserAppTheme.primaryBlue : UserAppTheme.textPrimary,
                      weight: isSelected ? FontWeight.bold : FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (isSelected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: UserAppTheme.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: List.generate(8, (index) {
        return Shimmer.fromColors(
          baseColor: const Color(0xFFE0E0E0),
          highlightColor: const Color(0xFFF5F5F5),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
            ),
          ),
        );
      }),
    );
  }
}
