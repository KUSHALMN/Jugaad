import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/theme/user_app_theme.dart';
import '../../../../core/widgets/jugaad_step_header.dart';
import '../../../../core/config/services_list.dart';
import '../../../../core/providers/services_provider.dart';
import '../../../../shared/widgets/cached_image.dart';
import 'post_job_state.dart';

class PostJobStep2Screen extends ConsumerStatefulWidget {
  const PostJobStep2Screen({super.key});

  @override
  ConsumerState<PostJobStep2Screen> createState() => _PostJobStep2ScreenState();
}

class _PostJobStep2ScreenState extends ConsumerState<PostJobStep2Screen> {
  final TextEditingController _descController = TextEditingController();
  final FocusNode _descFocusNode = FocusNode();
  bool _isInputFocused = false;
  bool _loadingLocation = false;
  bool _locationDenied = false;
  String _address = '';
  final List<String> _photos = [];

  @override
  void initState() {
    super.initState();
    final current = ref.read(postJobProvider);
    _address = current.address;
    _descController.text = current.description;
    _descFocusNode.addListener(() {
      setState(() {
        _isInputFocused = _descFocusNode.hasFocus;
      });
    });
    // Try fetching real location
    _fetchLocation();
  }

  @override
  void dispose() {
    _descController.dispose();
    _descFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() => _loadingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        print('[ERROR] Location denied. Using Bangalore Center fallback.');
        setState(() {
          _loadingLocation = false;
          _locationDenied = false;
          _address = 'Bangalore Center (Fallback)';
        });
        ref.read(postJobProvider.notifier).setLocation(12.9716, 77.5946, 'Bangalore Center (Fallback)');
        return;
      }

      setState(() => _locationDenied = false);

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      String addr = '';
      if (kIsWeb) {
        addr = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      } else {
        try {
          final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
          final place = placemarks.isNotEmpty ? placemarks.first : null;
          addr = place != null
              ? '${place.subLocality ?? place.locality}, ${place.administrativeArea}'
              : '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        } catch (geocodeErr) {
          print('[POST_JOB] Geocoding failed, falling back to coords: $geocodeErr');
          addr = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        }
      }

      setState(() {
        _address = addr;
        _loadingLocation = false;
      });

      ref.read(postJobProvider.notifier).setLocation(pos.latitude, pos.longitude, addr);
    } catch (e) {
      print('[POST_JOB] Location fetch failed: $e — using default Bangalore Center');
      setState(() {
        _loadingLocation = false;
        _locationDenied = false;
        _address = 'Bangalore Center (Fallback)';
      });
      ref.read(postJobProvider.notifier).setLocation(12.9716, 77.5946, 'Bangalore Center (Fallback)');
    }
  }

  void _showPhotoBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: UserAppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Add Photo',
                  style: UserAppTheme.heading(size: 18, weight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: UserAppTheme.primaryBlue),
                title: Text('Take a Photo', style: UserAppTheme.body(weight: FontWeight.w600)),
                onTap: () {
                  context.pop();
                  setState(() {
                    _photos.add('https://images.unsplash.com/photo-1581092921461-eab62e97a780?auto=format&fit=crop&w=150&q=80');
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: UserAppTheme.primaryBlue),
                title: Text('Choose from Gallery', style: UserAppTheme.body(weight: FontWeight.w600)),
                onTap: () {
                  context.pop();
                  setState(() {
                    _photos.add('https://images.unsplash.com/photo-1595787143151-e601da948ea8?auto=format&fit=crop&w=150&q=80');
                  });
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _next() {
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Please describe what you need help with',
                  style: UserAppTheme.body(color: Colors.white, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: UserAppTheme.urgentRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    if (desc.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Please describe the issue in at least 10 characters',
                  style: UserAppTheme.body(color: Colors.white, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: UserAppTheme.urgentRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    ref.read(postJobProvider.notifier).setDescription(desc);
    if (_address.trim().isNotEmpty) {
      final state = ref.read(postJobProvider);
      ref.read(postJobProvider.notifier).setLocation(state.lat, state.lng, _address.trim());
    }
    context.push('/user/post-job/step3');
  }

  @override
  Widget build(BuildContext context) {
    final jobState = ref.watch(postJobProvider);
    final servicesAsync = ref.watch(servicesProvider);
    final service = servicesAsync.maybeWhen(
      data: (list) => list.firstWhere(
        (s) => s.title.toLowerCase() == jobState.skill.toLowerCase() || s.id == jobState.skill.toLowerCase().replaceAll(' ', '_'),
        orElse: () => kAllServices.firstWhere(
          (s) => s.title.toLowerCase() == jobState.skill.toLowerCase(),
          orElse: () => kAllServices.first,
        ),
      ),
      orElse: () => kAllServices.firstWhere(
        (s) => s.title.toLowerCase() == jobState.skill.toLowerCase(),
        orElse: () => kAllServices.first,
      ),
    );
    final priceMinStr = service.priceMin.toStringAsFixed(0);
    final priceMaxStr = service.priceMax.toStringAsFixed(0);

    final bool isLocationEmpty = _address.trim().isEmpty;

    return Scaffold(
      backgroundColor: UserAppTheme.background,
      body: Column(
        children: [
          JugaadStepHeader(
            title: "Tell us more",
            currentStep: 2,
            totalSteps: 4,
            onBack: () => context.pop(),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SERVICE CHIP
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: UserAppTheme.primaryBlue.withValues(alpha: 0.15), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: UserAppTheme.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          jobState.skill,
                          style: UserAppTheme.body(
                            color: UserAppTheme.primaryBlue,
                            weight: FontWeight.bold,
                            size: 13,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
                  
                  const SizedBox(height: 24),

                  // --- ISSUE DESCRIPTION INPUT
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Describe the issue",
                            style: UserAppTheme.body(
                              size: 14,
                              weight: FontWeight.w600,
                              color: UserAppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            "Details matter",
                            style: UserAppTheme.label(
                              size: 13,
                              color: UserAppTheme.primaryBlue,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        constraints: const BoxConstraints(minHeight: 120),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isInputFocused 
                                ? UserAppTheme.primaryBlue 
                                : const Color(0xFFE2E8F0), 
                            width: _isInputFocused ? 2.0 : 1.5,
                          ),
                          boxShadow: _isInputFocused
                              ? [
                                  BoxShadow(
                                    color: UserAppTheme.primaryBlue.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: TextField(
                          focusNode: _descFocusNode,
                          controller: _descController,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          style: UserAppTheme.body(
                            size: 14,
                            color: UserAppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: "e.g. Switchboard sparking in kitchen...",
                            hintStyle: UserAppTheme.body(
                              size: 14,
                              color: UserAppTheme.textSecondary,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Suggestion chips helper text
                          Text(
                            "Tap suggestions to append",
                            style: UserAppTheme.label(
                              size: 11,
                              color: UserAppTheme.textSecondary,
                            ),
                          ),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _descController,
                            builder: (context, value, child) {
                              return Text(
                                "${value.text.length} chars",
                                style: UserAppTheme.label(
                                  size: 12,
                                  color: UserAppTheme.textSecondary,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // AI Suggestion Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            'Screen flickering',
                            'Battery drains fast',
                            "Won't turn on",
                            'Charging issue',
                          ].map((suggestion) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ActionChip(
                                label: Text(
                                  suggestion,
                                  style: UserAppTheme.label(
                                    size: 12,
                                    color: UserAppTheme.primaryBlue,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                backgroundColor: UserAppTheme.primaryBlue.withValues(alpha: 0.05),
                                side: BorderSide(
                                  color: UserAppTheme.primaryBlue.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                onPressed: () {
                                  final currentText = _descController.text;
                                  if (currentText.isEmpty) {
                                    _descController.text = suggestion;
                                  } else {
                                    _descController.text = '$currentText, $suggestion';
                                  }
                                  // Move cursor to the end
                                  _descController.selection = TextSelection.fromPosition(
                                    TextPosition(offset: _descController.text.length),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.05),

                  const SizedBox(height: 24),

                  // --- PHOTOS SECTION
                  Text(
                    'Photos',
                    style: UserAppTheme.body(
                      size: 15,
                      weight: FontWeight.bold,
                      color: UserAppTheme.textPrimary,
                    ),
                  ).animate().fadeIn(delay: 130.ms),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Dashed upload card
                      GestureDetector(
                        onTap: _showPhotoBottomSheet,
                        child: CustomPaint(
                          painter: DashedRectPainter(
                            color: UserAppTheme.primaryBlue.withValues(alpha: 0.3),
                            strokeWidth: 1.5,
                            radius: 12,
                          ),
                          child: Container(
                            width: 80,
                            height: 80,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.camera_alt_outlined,
                                  color: UserAppTheme.primaryBlue,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Add Photo',
                                  style: UserAppTheme.label(
                                    size: 10,
                                    color: UserAppTheme.primaryBlue,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // List of uploaded photos
                      Expanded(
                        child: SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _photos.length,
                            itemBuilder: (context, index) {
                              final photoUrl = _photos[index];
                              return Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 80,
                                height: 80,
                                child: Stack(
                                  children: [
                                    CachedImage(
                                      imageUrl: photoUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _photos.removeAt(index);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 24),

                  // --- YOUR LOCATION CARD
                  Text(
                    'Your location',
                    style: UserAppTheme.body(
                      size: 15,
                      weight: FontWeight.bold,
                      color: UserAppTheme.textPrimary,
                    ),
                  ).animate().fadeIn(delay: 170.ms),
                  const SizedBox(height: 10),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: UserAppTheme.cardShadow,
                      border: Border.all(color: UserAppTheme.divider, width: 1.0),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: UserAppTheme.primaryBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: UserAppTheme.primaryBlue,
                            size: 20,
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.15, 1.15), duration: 800.ms),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Mysuru Pilot Area",
                                style: UserAppTheme.body(
                                  color: UserAppTheme.primaryBlue,
                                  weight: FontWeight.bold,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (_loadingLocation)
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(UserAppTheme.primaryBlue),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Detecting location...",
                                      style: UserAppTheme.body(
                                        size: 13,
                                        color: UserAppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                )
                              else if (_locationDenied && _address.isEmpty)
                                Text(
                                  "Location permission denied. Please allow location.",
                                  style: UserAppTheme.body(
                                    size: 13,
                                    color: UserAppTheme.urgentRed,
                                  ),
                                )
                              else
                                Text(
                                  _address.isEmpty ? "Tap Detect Location" : _address,
                                  style: UserAppTheme.body(
                                    size: 13,
                                    color: UserAppTheme.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_loadingLocation)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: UserAppTheme.primaryBlue, width: 1),
                            ),
                            child: Text(
                              "Detecting",
                              style: UserAppTheme.label(
                                color: UserAppTheme.primaryBlue,
                                size: 12,
                                weight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          TextButton(
                            onPressed: _fetchLocation,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _address.isEmpty ? "Detect" : "Change",
                              style: UserAppTheme.label(
                                color: UserAppTheme.primaryBlue,
                                weight: FontWeight.bold,
                                size: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
                  
                  const SizedBox(height: 24),

                  // --- SMART PRICING TIP
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      border: const Border(
                        left: BorderSide(color: UserAppTheme.primaryBlue, width: 3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          color: UserAppTheme.primaryBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Mysuru Smart Pricing Tip",
                                style: UserAppTheme.body(
                                  weight: FontWeight.bold,
                                  size: 14,
                                  color: UserAppTheme.primaryBlue,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Average charge in your area is ₹$priceMinStr–₹$priceMaxStr for ${jobState.skill.isNotEmpty ? jobState.skill.toLowerCase() : 'this service'}. Pay worker directly after satisfactory completion.",
                                style: UserAppTheme.body(
                                  size: 13,
                                  color: UserAppTheme.textSecondary,
                                ).copyWith(height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // --- Pinned Bottom Action Bar with CTA Button
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
              border: Border.all(color: UserAppTheme.divider, width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ScaleButton(
                    onPressed: isLocationEmpty ? null : _next,
                    text: isLocationEmpty ? "Provide location" : "Next: Confirm Job",
                    disabled: isLocationEmpty,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }
}

// --- HELPER WIDGETS
class ScaleButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool disabled;

  const ScaleButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.disabled = false,
  });

  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton> with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  late AnimationController _arrowController;

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _arrowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isReallyDisabled = widget.disabled || widget.onPressed == null;
    return GestureDetector(
      onTapDown: isReallyDisabled ? null : (_) => setState(() => _scale = 0.97),
      onTapUp: isReallyDisabled ? null : (_) => setState(() => _scale = 1.0),
      onTapCancel: isReallyDisabled ? null : () => setState(() => _scale = 1.0),
      onTap: isReallyDisabled ? null : () {
        HapticFeedback.mediumImpact();
        widget.onPressed!();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: UserAppTheme.buttonHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: isReallyDisabled ? null : UserAppTheme.primaryGradient,
            color: isReallyDisabled ? const Color(0xFFE2E8F0) : null,
            borderRadius: UserAppTheme.buttonBorderRadius,
            boxShadow: isReallyDisabled
                ? []
                : [
                    BoxShadow(
                      color: UserAppTheme.primaryBlue.withValues(alpha: 0.25),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.text,
                style: UserAppTheme.body(
                  color: isReallyDisabled ? UserAppTheme.textSecondary : Colors.white,
                  weight: FontWeight.bold,
                ),
              ),
              if (!isReallyDisabled) ...[
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _arrowController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_arrowController.value * 4, 0),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Painter for dashed border card
class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double radius;

  DashedRectPainter({
    this.color = const Color(0xFFB0BEC5),
    this.strokeWidth = 1.5,
    this.gap = 5.0,
    this.radius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    final dashPath = Path();
    double distance = 0.0;
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + gap),
          Offset.zero,
        );
        distance += gap * 2;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
