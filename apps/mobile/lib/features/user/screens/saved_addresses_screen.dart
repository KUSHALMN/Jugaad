import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:shimmer/shimmer.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/theme/app_text_styles.dart';
import 'package:jugaad_mvp/shared/widgets/jugaad_card.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  bool _isProcessing = false;

  // BUG FIX
  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: List.generate(4, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        )),
      ),
    );
  }

  Future<void> _addAddress(String label, String houseNo, String area, String city, String pincode) async {
    setState(() => _isProcessing = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final newAddr = {
        'label': label,
        'houseNo': houseNo,
        'area': area,
        'city': city,
        'pincode': pincode,
        'createdAt': DateTime.now().toIso8601String(),
      };

      final userDoc = await SupabaseConfig.client.from('users').select('saved_addresses').eq('id', uid).maybeSingle();
      final currentList = List<dynamic>.from(userDoc?['saved_addresses'] as List? ?? []);
      currentList.add(newAddr);

      await SupabaseConfig.client.from('users').upsert({
        'id': uid,
        'saved_addresses': currentList,
        'role': 'employer',
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address added successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding address: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteAddress(Map<String, dynamic> addr) async {
    setState(() => _isProcessing = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final userDoc = await SupabaseConfig.client.from('users').select('saved_addresses').eq('id', uid).maybeSingle();
      final currentList = List<dynamic>.from(userDoc?['saved_addresses'] as List? ?? []);
      
      currentList.removeWhere((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return map['label'] == addr['label'] &&
            map['houseNo'] == addr['houseNo'] &&
            map['area'] == addr['area'];
      });

      await SupabaseConfig.client.from('users').upsert({
        'id': uid,
        'saved_addresses': currentList,
        'role': 'employer',
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address deleted successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting address: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _setDefaultAddress(int index) async {
    setState(() => _isProcessing = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await SupabaseConfig.client.from('users').update({
        'default_address_index': index,
      }).eq('id', uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default address updated'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error setting default: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showAddAddressDialog() {
    final labelCtrl = TextEditingController();
    final houseNoCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Mysuru');
    final pincodeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Add New Address', style: AppTextStyles.heading3(color: AppColors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Label (e.g. Home, Work)'),
                ),
                TextField(
                  controller: houseNoCtrl,
                  decoration: const InputDecoration(labelText: 'Flat / House No / Block'),
                ),
                TextField(
                  controller: areaCtrl,
                  decoration: const InputDecoration(labelText: 'Area / Locality'),
                ),
                TextField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                TextField(
                  controller: pincodeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Pincode'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final label = labelCtrl.text.trim();
                final house = houseNoCtrl.text.trim();
                final area = areaCtrl.text.trim();
                final city = cityCtrl.text.trim();
                final pin = pincodeCtrl.text.trim();

                if (label.isEmpty || house.isEmpty || area.isEmpty || pin.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields'), backgroundColor: AppColors.danger),
                  );
                  return;
                }
                Navigator.pop(context);
                _addAddress(label, house, area, city, pin);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kUserPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add Address', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

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
          'Saved Addresses',
          style: AppTextStyles.heading3(color: AppColors.textPrimary),
        ),
        actions: [
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: AppColors.kUserPrimary, strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SupabaseConfig.client.from('users').stream(primaryKey: ['id']).eq('id', uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            // BUG FIX
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildSkeleton(),
            );
          }

          final listData = snapshot.data ?? [];
          final data = listData.isNotEmpty ? listData.first : <String, dynamic>{};
          final list = data['saved_addresses'] as List? ?? data['savedAddresses'] as List? ?? [];
          final defaultIndex = data['default_address_index'] as int? ?? data['defaultAddressIndex'] as int? ?? 0;

          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_rounded, color: AppColors.textSecondary.withValues(alpha: 0.3), size: 64),
                  const SizedBox(height: 16),
                  Text('No saved addresses yet', style: AppTextStyles.bodyLarge(color: AppColors.textSecondary, weight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Add your frequent addresses for a seamless booking experience.', style: AppTextStyles.bodySmall(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final addr = Map<String, dynamic>.from(list[index] as Map);
              final isDefault = defaultIndex == index;

              final label = addr['label'] as String? ?? 'Address';
              final houseNo = addr['houseNo'] as String? ?? '';
              final area = addr['area'] as String? ?? '';
              final city = addr['city'] as String? ?? 'Mysuru';
              final pincode = addr['pincode'] as String? ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                child: JugaadCard(
                  borderRadius: 16.0,
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  label,
                                  style: AppTextStyles.bodyLarge(color: AppColors.textPrimary, weight: FontWeight.bold),
                                ),
                                if (isDefault) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'DEFAULT',
                                      style: AppTextStyles.bodySmall(color: AppColors.success, weight: FontWeight.bold).copyWith(fontSize: 8),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$houseNo, $area',
                              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
                            ),
                            Text(
                              '$city - $pincode',
                              style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
                            ),
                            if (!isDefault) ...[
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: () => _setDefaultAddress(index),
                                child: Text(
                                  'Set as Default',
                                  style: AppTextStyles.bodySmall(color: AppColors.kUserPrimary, weight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                        onPressed: () => _deleteAddress(addr),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAddressDialog,
        backgroundColor: AppColors.kUserPrimary,
        label: const Text('Add Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}
