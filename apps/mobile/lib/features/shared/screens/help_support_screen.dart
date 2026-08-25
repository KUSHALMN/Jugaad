import 'package:flutter/material.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/theme/app_text_styles.dart';
import 'package:jugaad_mvp/shared/widgets/jugaad_card.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I book a service?',
      'answer': 'Simply navigate to the User Home, select the service you need, specify details, select a date and time, and post the job. Our algorithm will match you with a nearby online professional instantly.'
    },
    {
      'question': 'How do payouts work for workers?',
      'answer': 'Once you mark a booking as completed, the earnings are added to your withdrawable balance. You can enter your UPI ID in Payout Settings and request a payout. The money is transferred to your account within 24 hours.'
    },
    {
      'question': 'Can I cancel a booking?',
      'answer': 'Yes, you can cancel a booking before it is started by the worker. For a smooth pilot experience, please avoid frequent cancellations.'
    },
    {
      'question': 'How do I contact customer support?',
      'answer': 'You can reach us directly via the Email Support or WhatsApp Support buttons below. Our response time is typically within 10 minutes.'
    }
  ];

  int _expandedIndex = -1;

  Future<void> _launchWhatsApp() async {
    final Uri whatsappUrl = Uri.parse('https://wa.me/918217507117?text=Hello%20Jugaad%20Support');
    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $whatsappUrl';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp. Please contact +91 8217507117 directly.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailUrl = Uri.parse('mailto:juggadsupport@gmail.com?subject=Jugaad%20App%20Support%20Request');
    try {
      if (await canLaunchUrl(emailUrl)) {
        await launchUrl(emailUrl);
      } else {
        throw 'Could not launch $emailUrl';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open email app. Please write to juggadsupport@gmail.com directly.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help & Support',
          style: AppTextStyles.heading3(color: AppColors.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Frequently Asked Questions',
              style: AppTextStyles.heading3(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _faqs.length,
              itemBuilder: (context, index) {
                final isExpanded = _expandedIndex == index;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  child: JugaadCard(
                    borderRadius: 16.0,
                    padding: EdgeInsets.zero,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _expandedIndex = isExpanded ? -1 : index;
                        });
                      },
                      borderRadius: BorderRadius.circular(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _faqs[index]['question']!,
                                    style: AppTextStyles.bodyLarge(
                                      color: AppColors.textPrimary,
                                      weight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Icon(
                                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                          if (isExpanded)
                            Padding(
                              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                              child: Text(
                                _faqs[index]['answer']!,
                                style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Still need help?',
              style: AppTextStyles.heading3(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Our team is available 24/7 during the pilot phase.',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _launchWhatsApp,
                    borderRadius: BorderRadius.circular(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.2), width: 1.2),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.chat_rounded, color: AppColors.success, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            'WhatsApp Support',
                            style: AppTextStyles.bodyMedium(color: AppColors.success, weight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _launchEmail,
                    borderRadius: BorderRadius.circular(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.2),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.email_rounded, color: AppColors.primary, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            'Email Support',
                            style: AppTextStyles.bodyMedium(color: AppColors.primary, weight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
