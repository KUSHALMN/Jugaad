import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:jugaad_mvp/core/network/environment_config.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/widgets/jugaad_step_header.dart';
import 'package:jugaad_mvp/core/services/auth_service.dart';
import 'worker_registration_state.dart';

class WorkerRegistrationStep3 extends ConsumerStatefulWidget {
  const WorkerRegistrationStep3({super.key});

  @override
  ConsumerState<WorkerRegistrationStep3> createState() => _WorkerRegistrationStep3State();
}

class _WorkerRegistrationStep3State extends ConsumerState<WorkerRegistrationStep3> {
  bool _isSubmitting = false;

  String _normalizeCategory(String category) {
    return category.toLowerCase().replaceAll(' ', '_');
  }

  Future<String> _uploadToSupabase(String bucketName, String path, Uint8List bytes) async {
    // 1. Try uploading via Backend API (bypasses Supabase Storage RLS)
    try {
      final uri = Uri.parse('${EnvironmentConfig.baseUrl}/api/v1/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['bucket'] = bucketName
        ..fields['path'] = path
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: path.split('/').last,
        ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['url'] != null) {
          print('[UPLOAD] Successfully uploaded $path via Backend API');
          return data['url'] as String;
        }
      }
      print('[UPLOAD] API returned status ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('[UPLOAD] Backend API upload exception, trying direct Supabase: $e');
    }

    // 2. Fallback to direct Supabase Storage upload
    try {
      await SupabaseConfig.client.storage
          .from(bucketName)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      final url = SupabaseConfig.client.storage.from(bucketName).getPublicUrl(path);
      return url;
    } catch (e) {
      print('Error uploading to $bucketName: $e');
      rethrow;
    }
  }

  Future<void> _submit() async {
    final state = ref.read(workerRegistrationProvider);
    final uid = AuthService().currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please log in again.'),
          backgroundColor: AppColors.kDanger,
        ),
      );
      return;
    }

    if (state.profilePhotoBytes == null || state.aadhaarPhotoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please make sure both photos are uploaded before submitting.'),
          backgroundColor: AppColors.kDanger,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Upload Profile Photo to worker-photos bucket
      final profilePath = '$uid/profile_$timestamp.jpg';
      final profilePhotoUrl = await _uploadToSupabase('worker-photos', profilePath, state.profilePhotoBytes!);

      // Upload Aadhaar Card Photo to worker-verification bucket
      final aadhaarPath = '$uid/aadhaar_$timestamp.jpg';
      final aadhaarPhotoUrl = await _uploadToSupabase('worker-verification', aadhaarPath, state.aadhaarPhotoBytes!);

      // Insert or update record in workers table
      await SupabaseConfig.client.from('workers').upsert({
        'id': uid,
        'worker_id': uid,
        'name': state.fullName,
        'phone': state.phoneNumber,
        'skills': [_normalizeCategory(state.workCategory)],
        'specialities': [state.workCategory],
        'status': 'pending',
        'approval_status': 'pending',
        'id_document_url': profilePhotoUrl, // maps to profile_photo in PostGIS views
        'documents': [
          {
            'name': 'profile_photo',
            'url': profilePhotoUrl,
            'uploaded_at': DateTime.now().toUtc().toIso8601String(),
            'status': 'pending_review'
          },
          {
            'name': 'aadhaar_card',
            'url': aadhaarPhotoUrl,
            'uploaded_at': DateTime.now().toUtc().toIso8601String(),
            'status': 'pending_review'
          }
        ],
      }, onConflict: 'id');

      if (!mounted) return;

      // Notify the worker with an in-app message
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: AppColors.kSurface,
            title: Row(
              children: const [
                Icon(Icons.info_outline, color: AppColors.kWorkerPrimary),
                SizedBox(width: 8),
                Text('Registration Submitted', style: TextStyle(color: AppColors.kTextPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'Your registration is under review. You will be notified once approved.',
              style: TextStyle(color: AppColors.kTextPrimary, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  context.pop();
                },
                child: const Text('OK', style: TextStyle(color: AppColors.kWorkerPrimary, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );

      ref.read(workerRegistrationProvider.notifier).reset();

      if (mounted) {
        context.go('/worker/register/success');
      }
    } catch (e) {
      print('Error during registration submission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit registration: $e'),
            backgroundColor: AppColors.kDanger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workerRegistrationProvider);

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: Stack(
        children: [
          Column(
            children: [
              JugaadStepHeader(
                title: 'Confirm Details',
                currentStep: 3,
                totalSteps: 3,
                onBack: () => context.pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Review Information',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Please verify your registration details before final submission.',
                        style: TextStyle(fontSize: 12, color: AppColors.kTextSecond),
                      ),
                      const SizedBox(height: 24),

                      // Card wrapper for details
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.kSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.kBorder, width: 0.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Full Name',
                              style: TextStyle(fontSize: 12, color: AppColors.kTextSecond, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              state.fullName,
                              style: const TextStyle(fontSize: 16, color: AppColors.kTextPrimary, fontWeight: FontWeight.bold),
                            ),
                            const Divider(height: 24, color: AppColors.kBorder, thickness: 0.5),

                            const Text(
                              'Work Category',
                              style: TextStyle(fontSize: 12, color: AppColors.kTextSecond, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              state.workCategory,
                              style: const TextStyle(fontSize: 16, color: AppColors.kTextPrimary, fontWeight: FontWeight.bold),
                            ),
                            const Divider(height: 24, color: AppColors.kBorder, thickness: 0.5),

                            const Text(
                              'Profile Photo Preview',
                              style: TextStyle(fontSize: 12, color: AppColors.kTextSecond, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            if (state.profilePhotoBytes != null)
                              Center(
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.kBorder, width: 1),
                                    image: DecorationImage(
                                      image: MemoryImage(state.profilePhotoBytes!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            const Divider(height: 24, color: AppColors.kBorder, thickness: 0.5),

                            const Text(
                              'Aadhaar Card Photo Preview',
                              style: TextStyle(fontSize: 12, color: AppColors.kTextSecond, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            if (state.aadhaarPhotoBytes != null)
                              Container(
                                width: double.infinity,
                                height: 140,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.kBorder, width: 1),
                                  image: DecorationImage(
                                    image: MemoryImage(state.aadhaarPhotoBytes!),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kSuccess,
                    disabledBackgroundColor: AppColors.kSuccess.withValues(alpha: 0.5),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Confirm & Submit',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.kWorkerPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
