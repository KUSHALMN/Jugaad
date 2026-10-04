import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/widgets/jugaad_step_header.dart';
import 'package:jugaad_mvp/core/widgets/live_selfie_camera_modal.dart';
import 'worker_registration_state.dart';

class WorkerRegistrationStep2 extends ConsumerStatefulWidget {
  const WorkerRegistrationStep2({super.key});

  @override
  ConsumerState<WorkerRegistrationStep2> createState() => _WorkerRegistrationStep2State();
}

class _WorkerRegistrationStep2State extends ConsumerState<WorkerRegistrationStep2> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _takeLiveSelfie() async {
    final result = await LiveSelfieCameraModal.show(
      context,
      preferredLensDirection: CameraLensDirection.front,
    );

    if (result != null) {
      ref.read(workerRegistrationProvider.notifier).setProfilePhoto(result.bytes, result.name);
    }
  }

  Future<void> _pickImage(bool isProfile, ImageSource source, {CameraDevice preferredCamera = CameraDevice.rear}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        preferredCameraDevice: isProfile ? CameraDevice.front : preferredCamera,
        imageQuality: 85,
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
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick photo: $e'),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    isProfile ? 'Verify with Selfie' : 'Upload Aadhaar Card',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F5EE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isProfile ? Icons.face_rounded : Icons.camera_alt_rounded,
                      color: AppColors.kWorkerPrimary,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    isProfile ? 'Take Live Selfie (Front Camera)' : 'Take Photo (Camera)',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  subtitle: Text(
                    isProfile ? 'Open front camera to verify identity' : 'Take a clear photo of your ID',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  onTap: () {
                    context.pop();
                    if (isProfile) {
                      _takeLiveSelfie();
                    } else {
                      _pickImage(
                        false,
                        ImageSource.camera,
                        preferredCamera: CameraDevice.rear,
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF475569), size: 24),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  subtitle: const Text(
                    'Select existing photo from files',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  onTap: () {
                    context.pop();
                    _pickImage(isProfile, ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          JugaadStepHeader(
            title: 'Partner Verification',
            currentStep: 2,
            totalSteps: 3,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Verification Shield Header Banner
                  Container(
                    padding: const EdgeInsets.all(14.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F5EE),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: const BoxDecoration(
                            color: Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Official KYC & Identity Verification',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF065F46),
                                  fontSize: 13.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'A clear selfie and ID are required to issue your verified partner badge and unlock job dispatches.',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF047857)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── SECTION 1: LIVE SELFIE VERIFICATION ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '1. Live Verification Selfie',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      if (state.profilePhotoBytes != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
                              SizedBox(width: 4),
                              Text('Captured', style: TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Take a live selfie using your phone front camera. Ensure your face is centered with good lighting.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  // Interactive Selfie Frame Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: state.profilePhotoBytes != null ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                        width: state.profilePhotoBytes != null ? 2.0 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: state.profilePhotoBytes != null
                              ? const Color(0xFF16A34A).withValues(alpha: 0.10)
                              : Colors.black.withValues(alpha: 0.03),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Circular Face Preview
                        GestureDetector(
                          onTap: _takeLiveSelfie,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFF1F5F9),
                                  border: Border.all(
                                    color: state.profilePhotoBytes != null ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                                    width: 3.0,
                                  ),
                                  image: state.profilePhotoBytes != null
                                      ? DecorationImage(
                                          image: MemoryImage(state.profilePhotoBytes!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: state.profilePhotoBytes == null
                                    ? const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.face_retouching_natural_rounded, color: Color(0xFF94A3B8), size: 48),
                                          SizedBox(height: 4),
                                          Text('Face Frame', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600)),
                                        ],
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF16A34A),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x3316A34A),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Action Buttons: Take Selfie vs Gallery
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: ElevatedButton.icon(
                                onPressed: _takeLiveSelfie,
                                icon: const Icon(Icons.camera_front_rounded, size: 18, color: Colors.white),
                                label: Text(
                                  state.profilePhotoBytes == null ? 'Take Live Selfie' : 'Retake Selfie',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: OutlinedButton.icon(
                                onPressed: () => _pickImage(true, ImageSource.gallery),
                                icon: const Icon(Icons.photo_library_outlined, size: 16, color: Color(0xFF475569)),
                                label: const Text(
                                  'Gallery',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF334155)),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Selfie Rules Chips
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('💡 Good lighting', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            SizedBox(width: 12),
                            Text('🕶️ No sunglasses', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            SizedBox(width: 12),
                            Text('🧢 No caps', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── SECTION 2: AADHAAR CARD UPLOAD ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '2. Aadhaar Card Photo',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      if (state.aadhaarPhotoBytes != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
                              SizedBox(width: 4),
                              Text('Uploaded', style: TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Upload a clear photo of your government Aadhaar card. Kept 100% confidential for police & admin audit.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  // Aadhaar Card Box
                  GestureDetector(
                    onTap: () => _showImageSourceBottomSheet(false),
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: state.aadhaarPhotoBytes != null ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                          width: state.aadhaarPhotoBytes != null ? 2.0 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
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
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.badge_rounded, color: Color(0xFF16A34A), size: 36),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Tap to capture or upload Aadhaar card',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Camera (Rear) or Gallery document',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            )
                          : Container(
                              alignment: Alignment.bottomRight,
                              padding: const EdgeInsets.all(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text('Change Document', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Bottom Action
          Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: const Color(0xFFE2E8F0), width: 1.0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: isNextEnabled ? () => context.push('/worker/register/step3') : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                disabledBackgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.35),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'Next: Review Verification Details →',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
