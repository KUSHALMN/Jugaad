import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart';

class LiveSelfieResult {
  final Uint8List bytes;
  final String name;

  LiveSelfieResult({required this.bytes, required this.name});
}

/// Dedicated in-app Live Selfie Camera with real-time video stream,
/// oval face-framing guide, mirror preview, and zero gallery redirects.
class LiveSelfieCameraModal extends StatefulWidget {
  final CameraLensDirection preferredLensDirection;

  const LiveSelfieCameraModal({
    super.key,
    this.preferredLensDirection = CameraLensDirection.front,
  });

  static Future<LiveSelfieResult?> show(
    BuildContext context, {
    CameraLensDirection preferredLensDirection = CameraLensDirection.front,
  }) {
    return showDialog<LiveSelfieResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LiveSelfieCameraModal(
        preferredLensDirection: preferredLensDirection,
      ),
    );
  }

  @override
  State<LiveSelfieCameraModal> createState() => _LiveSelfieCameraModalState();
}

class _LiveSelfieCameraModalState extends State<LiveSelfieCameraModal> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;

  // Captured preview state
  Uint8List? _capturedBytes;
  String? _capturedName;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      // Check and request permission on mobile
      if (!kIsWeb) {
        final status = await Permission.camera.request();
        if (status.isPermanentlyDenied) {
          setState(() {
            _isInitializing = false;
            _errorMessage = 'Camera permission permanently denied. Please enable camera access in app settings.';
          });
          return;
        } else if (!status.isGranted) {
          setState(() {
            _isInitializing = false;
            _errorMessage = 'Camera access was not granted. Please allow camera access to take a live selfie.';
          });
          return;
        }
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'No camera device found on this system.';
        });
        return;
      }

      // Prefer front camera for selfie verification
      int targetIndex = _cameras.indexWhere(
        (c) => c.lensDirection == widget.preferredLensDirection,
      );
      if (targetIndex == -1) {
        targetIndex = 0;
      }
      _selectedCameraIndex = targetIndex;

      await _initController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('[LiveSelfie] Camera setup error: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Could not access camera: $e';
        });
      }
    }
  }

  Future<void> _initController(CameraDescription camera) async {
    final oldController = _controller;
    if (oldController != null) {
      _controller = null;
      await oldController.dispose();
    }

    final newController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await newController.initialize();
      if (mounted) {
        setState(() {
          _controller = newController;
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('[LiveSelfie] Controller initialize error: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Unable to start camera stream. Please ensure your camera is not in use by another app.';
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length <= 1 || _isCapturing) return;

    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _selectedCameraIndex = nextIndex;
    setState(() => _isInitializing = true);
    await _initController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final XFile file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _capturedBytes = bytes;
          _capturedName = file.name;
        });
      }
    } catch (e) {
      debugPrint('[LiveSelfie] Take picture error: $e');
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to snap photo: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedBytes = null;
      _capturedName = null;
    });
  }

  void _confirmPhoto() {
    if (_capturedBytes != null) {
      final result = LiveSelfieResult(
        bytes: _capturedBytes!,
        name: _capturedName ?? 'live_selfie_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      Navigator.of(context).pop(result);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header Bar ──────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.camera_front_rounded, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Live Selfie Verification',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  _capturedBytes == null ? 'Align face inside frame' : 'Review your photo',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  // ── Camera / Preview Viewport ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildBody(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_capturedBytes != null) {
      return _buildReviewState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_isInitializing || _controller == null || !_controller!.value.isInitialized) {
      return _buildLoadingState();
    }

    return _buildLiveCameraState();
  }

  Widget _buildLoadingState() {
    return Container(
      height: 340,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
            const SizedBox(height: 16),
            Text(
              'Starting camera...',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.videocam_off_rounded, color: Color(0xFFDC2626), size: 36),
          ),
          const SizedBox(height: 14),
          Text(
            'Camera Unavailable',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unable to start camera stream.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF7F1D1D),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _setupCamera,
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                  label: Text(
                    'Retry',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCameraState() {
    final controller = _controller!;
    final isFront = controller.description.lensDirection == CameraLensDirection.front;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Live camera viewport with oval guide
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 360,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.previewSize?.height ?? 360,
                    height: controller.value.previewSize?.width ?? 360,
                    child: Transform(
                      alignment: Alignment.center,
                      // Mirror front camera horizontally so it behaves like a natural mirror
                      transform: isFront ? Matrix4.rotationY(3.14159) : Matrix4.identity(),
                      child: CameraPreview(controller),
                    ),
                  ),
                ),
              ),
            ),

            // Oval face guide cutout overlay
            IgnorePointer(
              child: Container(
                width: 210,
                height: 270,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.elliptical(105, 135)),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.85),
                    width: 3.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),

            // Top Camera Switch button (if multiple cameras available)
            if (_cameras.length > 1)
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 20),
                    onPressed: _switchCamera,
                    tooltip: 'Switch Camera',
                  ),
                ),
              ),

            // Bottom guide badge
            Positioned(
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Center your face in the oval',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Shutter Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isCapturing ? null : _capturePhoto,
            icon: _isCapturing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.camera_alt_rounded, size: 22, color: Colors.white),
            label: Text(
              _isCapturing ? 'Capturing...' : 'Capture Selfie',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Photo preview inside oval
        Container(
          height: 340,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.elliptical(110, 140)),
              child: Image.memory(
                _capturedBytes!,
                width: 220,
                height: 280,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        Text(
          'Looking good! Is your face clear and centered?',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF475569),
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: _retakePhoto,
                icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF475569)),
                label: Text(
                  'Retake',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: const Color(0xFF475569),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: _confirmPhoto,
                icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                label: Text(
                  'Use This Selfie',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
