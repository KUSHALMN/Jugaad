import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'theme.dart';
import 'components.dart';

// ==========================================
// SCREEN 1 — SPLASH SCREEN
// ==========================================

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // We assume the base theme handles the background color (Colors.white)
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              
              // App Icon
              Container(
                width: 56.0,
                height: 56.0,
                decoration: BoxDecoration(
                  color: colors.primary, // Blue tint background
                  borderRadius: BorderRadius.circular(14.0),
                ),
                child: Icon(Icons.check, color: colors.surface, size: 32.0),
              ),
              const SizedBox(height: 24.0),
              
              // App Name & Tagline
              Text(
                'Jugaad',
                style: TextStyle(
                  fontSize: 28.0,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                'Skills near you, fast.',
                style: TextStyle(
                  fontSize: 14.0,
                  color: colors.neutralPrimary,
                ),
              ),
              const SizedBox(height: 48.0),
              
              // Social Proof Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: colors.neutralFill,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: colors.neutralBorder, width: 1.0),
                ),
                child: Column(
                  children: [
                    Text(
                      'Live in Vijayanagar, Mysuru',
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'Laptop repair, electricians, plumbers — reach you in 20 mins',
                      style: TextStyle(
                        fontSize: 11.0,
                        color: colors.neutralPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Actions
              PrimaryButton(
                text: 'Get started',
                onPressed: () {
                  // Navigate to Role Select
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RoleSelectScreen()),
                  );
                },
              ),
              const SizedBox(height: 24.0),
              
              TextButton(
                onPressed: () {
                  // Navigate to Login
                },
                child: Text(
                  'Already have an account? Sign in',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                    color: colors.neutralPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SCREEN 2 — ROLE SELECT SCREEN
// ==========================================

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Scaffold(
      backgroundColor: colors.background,
      // No app bar for full onboarding feel
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32.0),
              
              // Headers
              Text(
                'How will you use Jugaad?',
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4.0),
              Text(
                'You can switch roles anytime from your profile',
                style: TextStyle(
                  fontSize: 13.0,
                  color: colors.neutralPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32.0),
              
              // Role Cards
              
              // Card 1 — User (Blue)
              _buildRoleCard(
                title: 'I need help',
                subtitle: 'Book trusted local workers',
                icon: Icons.person,
                titleColor: const Color(0xFF185FA5), // User Primary
                subtitleColor: const Color(0xFF185FA5).withValues(alpha: 0.8), // user blue-600 approx
                bgColor: const Color(0xFFE6F1FB), // User light fill
                borderColor: const Color(0xFF185FA5), // User border 1.5px
                iconBgColor: const Color(0xFFE6F1FB).withValues(alpha: 0.5), // blue-10 approx
                onTap: () {
                  // Handle user selection (advances to OTP)
                },
              ),
              
              const SizedBox(height: 12.0),
              
              // Card 2 — Worker (Green)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRoleCard(
                    title: 'I offer skills',
                    subtitle: 'Earn by doing jobs nearby',
                    icon: Icons.build,
                    titleColor: const Color(0xFF0F6E56), // Worker Primary
                    subtitleColor: const Color(0xFF0F6E56).withValues(alpha: 0.8), // worker green-600 approx
                    bgColor: const Color(0xFFE1F5EE), // Worker light fill
                    borderColor: const Color(0xFF0F6E56), // Worker border 1.5px
                    iconBgColor: const Color(0xFFE1F5EE).withValues(alpha: 0.5), // green-10 approx
                    onTap: () {
                      // Handle worker selection (advances to OTP)
                    },
                  ),
                  const SizedBox(height: 8.0),
                  // IMPORTANT Worker Priming Text
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      "You'll start receiving job requests immediately after approval.",
                      style: TextStyle(
                        fontSize: 10.0,
                        color: Color(0xFF0C5644), // Darker green (green-700 approx)
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Hint Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                margin: const EdgeInsets.only(top: 12.0, bottom: 24.0),
                decoration: BoxDecoration(
                  color: colors.neutralFill,
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: colors.neutralBorder, width: 0.5),
                ),
                child: Text(
                  'Not sure? Start as a user — you can always switch to worker from your profile.',
                  style: TextStyle(
                    fontSize: 11.0,
                    color: colors.neutralPrimary,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color titleColor,
    required Color subtitleColor,
    required Color bgColor,
    required Color borderColor,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: false, // Could be stateful if we had a "selected" state, but tapping advances immediately
      label: '$title role',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.0),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              // Left: icon circle
              Container(
                width: 32.0,
                height: 32.0,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: subtitleColor, size: 18.0),
              ),
              const SizedBox(width: 16.0),
              // Center: Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Right: Chevron
              Icon(Icons.chevron_right, color: titleColor, size: 20.0),
            ],
          ),
        ),
      ),
    );
  }
}
