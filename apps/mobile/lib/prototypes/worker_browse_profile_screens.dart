import 'package:flutter/material.dart';
import 'theme.dart';
import 'components.dart';

// ==========================================
// 1. WORKER BROWSE SCREEN
// ==========================================

class WorkerBrowseScreen extends StatelessWidget {
  const WorkerBrowseScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Scaffold(
      backgroundColor: colors.background,
      appBar: const CustomAppBar(title: '', showBack: true), // Minimal app bar
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Workers near you', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: colors.neutralFill,
                      borderRadius: BorderRadius.circular(100.0),
                    ),
                    child: Row(
                      children: [
                        Text('Nearest first', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: colors.neutralPrimary)),
                        const SizedBox(width: 4.0),
                        Icon(Icons.keyboard_arrow_down, size: 14.0, color: colors.neutralPrimary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                children: [
                  _buildFilterChip('All', true, colors),
                  _buildFilterChip('Laptop repair', false, colors),
                  _buildFilterChip('Electrician', false, colors),
                  _buildFilterChip('Plumber', false, colors),
                ],
              ),
            ),
            
            const SizedBox(height: 16.0),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                children: [
                  _buildWorkerCard(
                    name: 'Rajan Kumar',
                    specialty: 'Laptop repair',
                    rating: '4.9',
                    distance: '1.4 km',
                    rate: '₹200/hr',
                    isOnline: true,
                    colors: colors,
                    context: context,
                  ),
                  const SizedBox(height: 16.0),
                  _buildWorkerCard(
                    name: 'Sneha V.',
                    specialty: 'Laptop repair',
                    rating: '4.7',
                    distance: '2.1 km',
                    rate: '₹180/hr',
                    isOnline: true,
                    colors: colors,
                    context: context,
                  ),
                  const SizedBox(height: 16.0),
                  _buildWorkerCard(
                    name: 'Arun M.',
                    specialty: 'Laptop repair',
                    rating: '4.8',
                    distance: '0.8 km',
                    rate: '₹250/hr',
                    isOnline: false,
                    colors: colors,
                    context: context,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, AppColors colors) {
    return Container(
      margin: const EdgeInsets.only(right: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isSelected ? colors.primary : Colors.white,
        borderRadius: BorderRadius.circular(100.0),
        border: Border.all(color: isSelected ? colors.primary : colors.neutralBorder, width: 1.0),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.white : colors.neutralPrimary,
        ),
      ),
    );
  }

  Widget _buildWorkerCard({
    required String name,
    required String specialty,
    required String rating,
    required String distance,
    required String rate,
    required bool isOnline,
    required AppColors colors,
    required BuildContext context,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PublicWorkerProfileScreen(name: name, isOnline: isOnline)),
        );
      },
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: colors.neutralBorder, width: 0.5),
          boxShadow: [
            BoxShadow(color: colors.textPrimary.withValues(alpha: 0.02), blurRadius: 4.0, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 16.0,
              backgroundColor: colors.lightFill,
              child: Text(name[0], style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700, color: colors.primary)),
            ),
            const SizedBox(width: 12.0),
            
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                  const SizedBox(height: 2.0),
                  Text(specialty, style: TextStyle(fontSize: 12.0, color: colors.neutralPrimary)),
                  const SizedBox(height: 6.0),
                  Text('⭐ $rating · $distance · $rate', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500, color: colors.textPrimary)),
                ],
              ),
            ),
            
            // Right Side: Online Pill + Button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildOnlinePill(isOnline, colors),
                const SizedBox(height: 16.0),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: isOnline ? colors.primary : colors.neutralPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0.0),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {},
                  child: Text(
                    isOnline ? 'Book now' : 'Book for later',
                    style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: isOnline ? colors.primary : colors.neutralPrimary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlinePill(bool isOnline, AppColors colors) {
    if (isOnline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: colors.successPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(100.0),
          border: Border.all(color: colors.successPrimary.withValues(alpha: 0.5), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6.0, height: 6.0, decoration: BoxDecoration(color: colors.successPrimary, shape: BoxShape.circle)),
            const SizedBox(width: 4.0),
            Text('Online', style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.w600, color: colors.successPrimary)),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: colors.neutralFill,
          borderRadius: BorderRadius.circular(100.0),
        ),
        child: Text('Offline', style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.w600, color: colors.neutralPrimary)),
      );
    }
  }
}

// ==========================================
// 2. PUBLIC WORKER PROFILE SCREEN
// ==========================================

class PublicWorkerProfileScreen extends StatelessWidget {
  final String name;
  final bool isOnline;

  const PublicWorkerProfileScreen({Key? key, required this.name, this.isOnline = true}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.neutralPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(name, style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        actions: [
          IconButton(icon: Icon(Icons.ios_share, color: colors.neutralPrimary), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24.0),
                    
                    // Avatar & Basic Info
                    CircleAvatar(
                      radius: 24.0,
                      backgroundColor: colors.lightFill,
                      child: Text(name[0], style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w700, color: colors.primary)),
                    ),
                    const SizedBox(height: 12.0),
                    Text(name, style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                    const SizedBox(height: 4.0),
                    Text('Laptop repair · Mysuru', style: TextStyle(fontSize: 13.0, color: colors.neutralPrimary)),
                    const SizedBox(height: 16.0),
                    
                    _buildOnlinePillLarge(isOnline, colors),
                    
                    const SizedBox(height: 32.0),
                    
                    // Compact Stats (2 columns)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text('★ 4.9', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                                const SizedBox(height: 4.0),
                                Text('82 jobs done', style: TextStyle(fontSize: 12.0, color: colors.neutralPrimary)),
                              ],
                            ),
                          ),
                          Container(width: 1.0, height: 32.0, color: colors.neutralBorder),
                          Expanded(
                            child: Column(
                              children: [
                                Text('₹200/hr', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                                const SizedBox(height: 4.0),
                                Text('1.4 km away', style: TextStyle(fontSize: 12.0, color: colors.neutralPrimary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32.0),
                    
                    // Short Bio
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: colors.neutralFill.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: const Text(
                          'Certified technician with 5 years experience repairing all major laptop brands. Fast turnaround.',
                          style: TextStyle(fontSize: 13.0, color: Color(0xFF5F5E5A), height: 1.4),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24.0),
                    
                    // Schedule Note
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month, size: 14.0, color: colors.neutralPrimary),
                        const SizedBox(width: 8.0),
                        Text('Available: Mon–Sat, 9AM–7PM', style: TextStyle(fontSize: 12.0, color: colors.neutralPrimary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // CTA AREA
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.neutralBorder, width: 0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 44.0,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOnline ? colors.primary : colors.neutralFill,
                        foregroundColor: isOnline ? Colors.white : Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                      ),
                      onPressed: () {},
                      child: Text(
                        isOnline ? 'Book now' : 'Schedule for later',
                        style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSmallAction('Call', Icons.phone, colors),
                      const SizedBox(width: 16.0),
                      _buildSmallAction('Chat', Icons.chat_bubble_outline, colors),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlinePillLarge(bool isOnline, AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: isOnline ? colors.successPrimary.withValues(alpha: 0.1) : colors.neutralFill,
        borderRadius: BorderRadius.circular(100.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.0, 
            height: 8.0, 
            decoration: BoxDecoration(
              color: isOnline ? colors.successPrimary : colors.neutralPrimary, 
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6.0),
          Text(
            isOnline ? 'Available now' : 'Offline', 
            style: TextStyle(
              fontSize: 12.0, 
              fontWeight: FontWeight.w700, 
              color: isOnline ? colors.successPrimary : colors.neutralPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallAction(String label, IconData icon, AppColors colors) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.neutralPrimary,
        side: BorderSide(color: colors.neutralBorder, width: 1.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      ),
      onPressed: () {},
      icon: Icon(icon, size: 16.0),
      label: Text(label, style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600)),
    );
  }
}
