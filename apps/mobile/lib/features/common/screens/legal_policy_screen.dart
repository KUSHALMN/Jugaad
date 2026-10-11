import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/user_app_theme.dart';

class LegalPolicyScreen extends StatefulWidget {
  final int initialTabIndex;
  const LegalPolicyScreen({super.key, this.initialTabIndex = 0});

  @override
  State<LegalPolicyScreen> createState() => _LegalPolicyScreenState();
}

class _LegalPolicyScreenState extends State<LegalPolicyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UserAppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: UserAppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Legal & Compliance Center',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: UserAppTheme.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: UserAppTheme.primaryGreen,
          unselectedLabelColor: UserAppTheme.textSecondary,
          indicatorColor: UserAppTheme.primaryGreen,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Privacy Policy'),
            Tab(text: 'Terms of Service'),
            Tab(text: 'Cancellation & Guarantee'),
            Tab(text: 'Grievance Officer'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPrivacyTab(),
          _buildTermsTab(),
          _buildGuaranteeTab(),
          _buildGrievanceTab(),
        ],
      ),
    );
  }

  Widget _buildPrivacyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badge('DPDP Act (2023) Compliant'),
          const SizedBox(height: 12),
          _heading('Privacy Policy & Data Protection'),
          _subtext('Effective Date: October 2026 • Jugaad Marketplace Pvt. Ltd.'),
          const Divider(height: 32),
          _sectionTitle('1. Information We Collect'),
          _body(
            'We collect minimal personal data essential to service delivery:\n'
            '• Identity Data: Name, mobile number verified via OTP.\n'
            '• Hyperlocal Geo-Coordinates: GPS coordinates for real-time worker dispatch and doorstep navigation.\n'
            '• Transaction Records: Service amounts, order IDs, and payment references (processed via PCI-DSS compliant payment rails).',
          ),
          _sectionTitle('2. Government ID & KYC Protection'),
          _body(
            'In strict compliance with Section 29 of the Aadhaar Act (2016) and UIDAI directives:\n'
            '• Unmasked Aadhaar numbers and raw government ID images are NEVER stored in public directories.\n'
            '• Worker onboarding employs secure masked verification tokens via authorized digital identity partners.\n'
            '• Identity records are protected with row-level security and accessible solely by verified compliance personnel.',
          ),
          _sectionTitle('3. Data Retention & Your Right to Erasure'),
          _body(
            'In accordance with Google Play Developer Policy and India’s Digital Personal Data Protection Act:\n'
            '• You retain full autonomy to erase your account and associated personal data at any time.\n'
            '• Initiating account deletion permanently anonymizes your telephone, address, and profile data.',
          ),
        ],
      ),
    );
  }

  Widget _buildTermsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badge('Marketplace Code of Conduct'),
          const SizedBox(height: 12),
          _heading('Terms of Service'),
          _subtext('Karnataka Jurisdiction • Platform User Agreement'),
          const Divider(height: 32),
          _sectionTitle('1. Platform Facilitator Model'),
          _body(
            'Jugaad operates as an on-demand technology matchmaking platform connecting independent skilled tradespeople ("Partners") with customers ("Employers").\n'
            '• Partners are independent service professionals, not direct employees of Jugaad.\n'
            '• All bookings, chat handshakes, and escrow releases must occur through the official Jugaad platform.',
          ),
          _sectionTitle('2. Verification & Safety Handshake (Zero-Leakage)'),
          _body(
            '• Arrival & Inspection PINs: Every booking requires a verified 4-digit doorstep PIN handshake.\n'
            '• Off-Platform Dealing Prohibition: Soliciting or settling payments outside the Jugaad application is strictly prohibited and immediately voids the ₹25,000 Jugaad Damage Guarantee.',
          ),
          _sectionTitle('3. Limitation of Liability'),
          _body(
            'While Jugaad enforces KYC identity verification, users must exercise standard precautions during home visits. Emergency support and instant 112 dialing are accessible in-app throughout active jobs.',
          ),
        ],
      ),
    );
  }

  Widget _buildGuaranteeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badge('₹25,000 Damage Cover'),
          const SizedBox(height: 12),
          _heading('Cancellation & Protection Guarantee'),
          _subtext('Transparent Pricing & Customer Protection'),
          const Divider(height: 32),
          _sectionTitle('1. Fair Cancellation Policy'),
          _body(
            '• Within 5 Minutes of Booking: 100% Free Cancellation with instant full refund.\n'
            '• After Worker Dispatch: If cancelled after the worker is en route (> 1 km traveled), a nominal ₹50 travel compensation fee is deducted to reimburse the partner fuel expenditure.\n'
            '• Worker No-Show: If the assigned worker fails to arrive within the scheduled window, the booking is automatically reassigned or refunded in full with bonus credits.',
          ),
          _sectionTitle('2. ₹25,000 Jugaad Damage Guarantee'),
          _body(
            'All services paid through the in-app payment escrow are protected up to ₹25,000 against accidental property damage occurring during service execution.\n'
            'Claims must be lodged within 24 hours of service completion via the in-app Help & Support desk with photographic evidence.',
          ),
        ],
      ),
    );
  }

  Widget _buildGrievanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badge('Rule 3(11) IT Rules 2021'),
          const SizedBox(height: 12),
          _heading('Grievance Officer & Escalations'),
          _subtext('Mandatory Grievance Redressal Mechanism'),
          const Divider(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UserAppTheme.divider),
              boxShadow: const [
                BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shield_outlined, color: UserAppTheme.primaryGreen, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Designated Grievance Officer',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: UserAppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Jugaad Platform Operations India',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: UserAppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _grievanceRow(Icons.person_outline, 'Officer Name', 'Grievance Redressal Officer'),
                _grievanceRow(Icons.email_outlined, 'Email', 'grievance@jugaad.app'),
                _grievanceRow(Icons.location_on_outlined, 'Office', 'Indiranagar, Bengaluru / Jayalakshmipuram, Mysuru, Karnataka'),
                _grievanceRow(Icons.timer_outlined, 'Response SLA', 'Within 48 hours as mandated by Indian Law'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: UserAppTheme.primaryGreen,
        ),
      ),
    );
  }

  Widget _heading(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: UserAppTheme.textPrimary,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _subtext(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        color: UserAppTheme.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: UserAppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _body(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        color: const Color(0xFF334155),
        height: 1.6,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _grievanceRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: UserAppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: UserAppTheme.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: UserAppTheme.textPrimary, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
