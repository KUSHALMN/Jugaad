import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

/// Memory-efficient, production-hardened network image widget for Jugaad.
///
/// Prevents Out-Of-Memory (OOM) crashes and frame drops on budget Android devices
/// by downsampling raw high-resolution images at decode time to exact widget dimensions
/// via [memCacheWidth] and [memCacheHeight].
class AppOptimizedNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final Widget? fallbackWidget;
  final String? fallbackInitials;

  const AppOptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.fit = BoxFit.cover,
    this.fallbackWidget,
    this.fallbackInitials,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.trim().isEmpty || !imageUrl!.startsWith('http')) {
      return _buildFallback();
    }

    // Downsample at decode time: limit buffer size to 2x logical dimensions
    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
    final targetMemWidth = (width * pixelRatio).round();
    final targetMemHeight = (height * pixelRatio).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: targetMemWidth,
        memCacheHeight: targetMemHeight,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildFallback(),
        fadeInDuration: const Duration(milliseconds: 180),
        fadeOutDuration: const Duration(milliseconds: 120),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    if (fallbackWidget != null) return fallbackWidget!;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: fallbackInitials != null && fallbackInitials!.isNotEmpty
            ? Text(
                fallbackInitials!.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: (height * 0.38).clamp(10.0, 22.0),
                  color: AppColors.textPrimary,
                ),
              )
            : Icon(
                Icons.person_rounded,
                size: (height * 0.5).clamp(14.0, 32.0),
                color: const Color(0xFF64748B),
              ),
      ),
    );
  }
}
