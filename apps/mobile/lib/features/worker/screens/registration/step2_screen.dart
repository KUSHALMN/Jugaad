import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/widgets/jugaad_step_header.dart';
import 'worker_registration_state.dart';

class WorkerRegistrationStep2 extends ConsumerStatefulWidget {
  const WorkerRegistrationStep2({super.key});

  @override
  ConsumerState<WorkerRegistrationStep2> createState() => _WorkerRegistrationStep2State();
}

class _WorkerRegistrationStep2State extends ConsumerState<WorkerRegistrationStep2> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(bool isProfile, ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final name = pickedFile.name;

      if (isProfile) {
        ref.read(workerRegistrationProvider.notifier).setProfilePhoto(bytes, name);
      } else {
        ref.read(workerRegistrationProvider.notifier).setAadhaarPhoto(bytes, name);
      }
    } catch (e) {
      print('Error picking image: $e');
      if (source == ImageSource.camera) {
        // Fallback to gallery if camera fails (e.g. on web or simulator without camera)
        _pickImage(isProfile, ImageSource.gallery);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.kDanger,
          ),
        );
      }
    }
  }

  void _showImageSourceBottomSheet(bool isProfile) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: AppColors.kSurface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.kWorkerPrimary),
                title: const Text('Take Photo', style: TextStyle(color: AppColors.kTextPrimary)),
                onTap: () {
                  context.pop();
                  _pickImage(isProfile, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.kWorkerPrimary),
                title: const Text('Choose from Gallery', style: TextStyle(color: AppColors.kTextPrimary)),
                onTap: () {
                  context.pop();
                  _pickImage(isProfile, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workerRegistrationProvider);
    final isNextEnabled = state.profilePhotoBytes != null && state.aadhaarPhotoBytes != null;

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: Column(
        children: [
          JugaadStepHeader(
            title: 'Upload Photos',
            currentStep: 2,
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
                    'Profile Photo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Please upload a clear headshot. This will be shown to users.',
                    style: TextStyle(fontSize: 12, color: AppColors.kTextSecond),
                  ),
                  const SizedBox(height: 12),
                  
                  // Profile photo upload widget
                  Center(
                    child: GestureDetector(
                      onTap: () => _showImageSourceBottomSheet(true),
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppColors.kSurface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: state.profilePhotoBytes != null ? AppColors.kWorkerPrimary : AppColors.kBorder,
                                width: state.profilePhotoBytes != null ? 2 : 1,
                              ),
                              image: state.profilePhotoBytes != null
                                  ? DecorationImage(
                                      image: MemoryImage(state.profilePhotoBytes!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: state.profilePhotoBytes == null
                                ? const Icon(
                                    Icons.person_add_alt_1_rounded,
                                    color: AppColors.kTextTertiary,
                                    size: 40,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.kWorkerPrimary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    'Aadhaar Card Photo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Please upload a photo of your Aadhaar card for background verification. This is strictly confidential and visible only to admins.',
                    style: TextStyle(fontSize: 12, color: AppColors.kTextSecond),
                  ),
                  const SizedBox(height: 12),

                  // Aadhaar card upload widget
                  GestureDetector(
                    onTap: () => _showImageSourceBottomSheet(false),
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppColors.kSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: state.aadhaarPhotoBytes != null ? AppColors.kWorkerPrimary : AppColors.kBorder,
                          width: state.aadhaarPhotoBytes != null ? 2 : 1,
                        ),
                        image: state.aadhaarPhotoBytes != null
                            ? DecorationImage(
                                image: MemoryImage(state.aadhaarPhotoBytes!),
                                fit: BoxFit.contain,
                              )
                            : null,
                      ),
                      child: state.aadhaarPhotoBytes == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.badge_rounded,
                                  color: AppColors.kTextTertiary,
                                  size: 48,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Tap to upload Aadhaar card',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.kTextPrimary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Camera or Gallery',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.kTextTertiary,
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              alignment: Alignment.bottomRight,
                              padding: const EdgeInsets.all(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text('Change Photo', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: ElevatedButton(
              onPressed: isNextEnabled ? () => context.push('/worker/register/step3') : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kWorkerPrimary,
                disabledBackgroundColor: AppColors.kWorkerPrimary.withValues(alpha: 0.5),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Next: Review Details',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
