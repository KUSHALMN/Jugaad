import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'theme.dart'; // Assumes the theme.dart from Phase 1A is available

// ==========================================
// 1. BUTTONS
// ==========================================

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSuccess;

  const PrimaryButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isSuccess = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    Color bgColor = colors.primary;
    if (isSuccess) bgColor = colors.successPrimary;
    if (onPressed == null && !isLoading) bgColor = colors.neutralBorder;

    return SizedBox(
      width: double.infinity,
      height: 44.0,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        ),
        onPressed: (isLoading || isSuccess) ? null : onPressed,
        child: isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
            : isSuccess
                ? const Icon(Icons.check, color: Colors.white)
                : Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const SecondaryButton({Key? key, required this.text, this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return SizedBox(
      height: 38.0,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: onPressed == null ? colors.neutralBorder : colors.primary, width: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class DangerButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const DangerButton({Key? key, required this.text, this.onPressed, this.isLoading = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return SizedBox(
      height: 38.0,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.dangerPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
            : Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class SurfaceIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;

  const SurfaceIconButton({Key? key, required this.icon, required this.onPressed, this.isActive = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(22.0),
      child: Container(
        width: 44.0,
        height: 44.0,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? colors.lightFill : colors.neutralFill,
        ),
        child: Icon(icon, color: isActive ? colors.primary : colors.neutralPrimary),
      ),
    );
  }
}

// ==========================================
// 2. INPUTS
// ==========================================

class CustomTextInput extends StatelessWidget {
  final String hintText;
  final bool isMultiline;
  final bool isSearch;
  final bool hasError;
  final bool isDisabled;
  final TextEditingController? controller;

  const CustomTextInput({
    Key? key, required this.hintText, this.isMultiline = false, this.isSearch = false, 
    this.hasError = false, this.isDisabled = false, this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return SizedBox(
      height: isMultiline ? null : 48.0,
      child: TextField(
        controller: controller,
        enabled: !isDisabled,
        maxLines: isMultiline ? 3 : 1,
        minLines: isMultiline ? 3 : 1,
        decoration: InputDecoration(
          hintText: hintText,
          filled: true,
          fillColor: isDisabled ? colors.neutralFill : Colors.white,
          prefixIcon: isSearch ? Icon(Icons.search, color: colors.neutralPrimary) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: hasError ? colors.dangerPrimary : colors.neutralBorder, width: 0.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: hasError ? colors.dangerPrimary : colors.neutralBorder, width: 0.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: hasError ? colors.dangerPrimary : colors.primary, width: 1.5)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: colors.neutralBorder, width: 0.5)),
        ),
      ),
    );
  }
}

class CustomDropdown<T> extends StatelessWidget {
  final String hintText;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool isDisabled;

  const CustomDropdown({
    Key? key, required this.hintText, required this.items, this.value, this.onChanged, this.isDisabled = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return SizedBox(
      height: 48.0,
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: isDisabled ? null : onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          filled: true,
          fillColor: isDisabled ? colors.neutralFill : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: colors.neutralBorder, width: 0.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: colors.neutralBorder, width: 0.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: colors.primary, width: 1.5)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: colors.neutralBorder, width: 0.5)),
        ),
      ),
    );
  }
}

// ==========================================
// 3. CARDS
// ==========================================

class WorkerCard extends StatelessWidget {
  final String name;
  final String specialty;
  final double rating;
  final String distance;
  final bool isOnline;
  final bool isSkeleton;

  const WorkerCard({
    Key? key, required this.name, required this.specialty, required this.rating, required this.distance,
    this.isOnline = true, this.isSkeleton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    if (isSkeleton) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: colors.neutralBorder, width: 0.5), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: colors.neutralFill, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 100, height: 14, color: colors.neutralFill),
              const SizedBox(height: 6),
              Container(width: 60, height: 12, color: colors.neutralFill),
            ]),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.neutralBorder, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 16, backgroundImage: CachedNetworkImageProvider('https://via.placeholder.com/150')),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                const SizedBox(height: 2),
                Text('$specialty • $distance', style: TextStyle(color: colors.neutralPrimary, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.star, size: 14, color: Color(0xFFE5A023)),
                  const SizedBox(width: 4),
                  Text(rating.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 6),
              OnlinePill(status: isOnline ? 'online' : 'offline'),
            ],
          )
        ],
      ),
    );
  }
}

class JobCard extends StatelessWidget {
  final String title;
  final String date;
  final String price;
  final String status;
  final bool isAdminAssigned;

  const JobCard({
    Key? key, required this.title, required this.date, required this.price, required this.status, this.isAdminAssigned = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surface, border: Border.all(color: colors.neutralBorder, width: 0.5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [Icon(Icons.build, color: colors.primary, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16))]),
              Text('₹$price', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date, style: TextStyle(color: colors.neutralPrimary, fontSize: 12)),
              Row(
                children: [
                  if (isAdminAssigned) const AdminActionPill(),
                  if (isAdminAssigned) const SizedBox(width: 8),
                  StatusPill(status: status),
                ],
              )
            ],
          )
        ],
      ),
    );
  }
}

// ==========================================
// 4. NAVIGATION
// ==========================================

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String mode; // 'user', 'worker', 'admin'

  const CustomBottomNav({Key? key, required this.currentIndex, required this.onTap, required this.mode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    List<BottomNavigationBarItem> items;
    if (mode == 'user') {
      items = const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Book'),
        BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Jobs'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ];
    } else if (mode == 'worker') {
      items = const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Active Job'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Earnings'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ];
    } else {
      items = const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Jobs'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Workers'),
        BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Ops'),
      ];
    }

    return SizedBox(
      height: 56.0,
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.neutralPrimary,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: items,
      ),
    );
  }
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final Widget? action;

  const CustomAppBar({Key? key, required this.title, this.showBack = false, this.action}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return AppBar(
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      backgroundColor: colors.surface,
      foregroundColor: Colors.black,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: colors.neutralBorder, height: 0.5),
      ),
      leading: showBack ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)) : null,
      actions: action != null ? [action!, const SizedBox(width: 8)] : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56.0);
}

// ==========================================
// 5. PILLS & BADGES
// ==========================================

class StatusPill extends StatelessWidget {
  final String status; // searching, assigned, in_progress, completed, cancelled, scheduled, manually_assigned, expired

  const StatusPill({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    Color bgColor; Color textColor; Color borderColor; IconData? icon;

    switch (status) {
      case 'searching': bgColor = colors.lightFill; textColor = colors.primary; borderColor = colors.neutralBorder; break;
      case 'assigned': bgColor = const Color(0xFFE1F5EE); textColor = const Color(0xFF0F6E56); borderColor = const Color(0xFF5DCAA5); break;
      case 'in_progress': bgColor = colors.warningFill; textColor = colors.warningPrimary; borderColor = colors.warningBorder; break;
      case 'completed': bgColor = colors.neutralFill; textColor = colors.neutralPrimary; borderColor = colors.neutralBorder; break;
      case 'cancelled': bgColor = colors.dangerFill; textColor = colors.dangerPrimary; borderColor = colors.dangerBorder; break;
      case 'scheduled': bgColor = Colors.transparent; textColor = colors.primary; borderColor = colors.primary; icon = Icons.access_time; break;
      case 'manually_assigned': bgColor = const Color(0xFFEDE8F7); textColor = const Color(0xFF3D1F7A); borderColor = const Color(0xFF9B82D4); icon = Icons.person; break;
      case 'expired': bgColor = Colors.transparent; textColor = colors.dangerPrimary; borderColor = colors.dangerPrimary; break;
      default: bgColor = colors.neutralFill; textColor = colors.neutralPrimary; borderColor = colors.neutralBorder;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(100), border: Border.all(color: borderColor, width: 1)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 10, color: textColor), const SizedBox(width: 4)],
          Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: textColor)),
        ],
      ),
    );
  }
}

class OnlinePill extends StatelessWidget {
  final String status;
  const OnlinePill({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color dotColor; String text;
    switch (status) {
      case 'online': dotColor = const Color(0xFF0F6E56); text = 'Online'; break;
      case 'busy': dotColor = const Color(0xFFBA7517); text = 'On a job'; break;
      case 'offline': default: dotColor = const Color(0xFF5F5E5A); text = 'Offline';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 10, color: dotColor, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class AdminActionPill extends StatelessWidget {
  const AdminActionPill({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF3D1F7A), borderRadius: BorderRadius.circular(100)),
      child: const Text('Assigned by Jugaad team', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.white)),
    );
  }
}

class AvailabilityBadge extends StatelessWidget {
  final String status; // available, busy, unavailable
  const AvailabilityBadge({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color bgColor; Color textColor; String text;
    switch (status) {
      case 'available': bgColor = const Color(0xFFE1F5EE); textColor = const Color(0xFF0F6E56); text = 'Available now'; break;
      case 'busy': bgColor = const Color(0xFFFAEEDA); textColor = const Color(0xFFBA7517); text = 'On a job — done soon'; break;
      case 'unavailable': default: bgColor = const Color(0xFFF1EFE8); textColor = const Color(0xFF5F5E5A); text = 'Unavailable';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(100)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textColor)),
    );
  }
}

// ==========================================
// 6. TOAST NOTIFICATION
// ==========================================

class ToastNotification extends StatelessWidget {
  final String message;
  final String type; // success, error, info, warning

  const ToastNotification({Key? key, required this.message, required this.type}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    Color bgColor; IconData icon;
    switch (type) {
      case 'success': bgColor = const Color(0xFF0F6E56); icon = Icons.check_circle; break;
      case 'error': bgColor = const Color(0xFFA32D2D); icon = Icons.error; break;
      case 'warning': bgColor = const Color(0xFFBA7517); icon = Icons.warning; break;
      case 'info': default: bgColor = const Color(0xFF5F5E5A); icon = Icons.info;
    }

    return Container(
      height: 32.0,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.surface, size: 14),
          const SizedBox(width: 8),
          Text(message, style: TextStyle(color: colors.surface, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
