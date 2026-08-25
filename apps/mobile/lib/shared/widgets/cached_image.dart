import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A reusable widget that wraps [CachedNetworkImage] with
/// a shimmer placeholder and a graceful error fallback.
///
/// Usage:
/// ```dart
/// CachedImage(
///   imageUrl: 'https://example.com/avatar.jpg',
///   width: 48,
///   height: 48,
///   borderRadius: BorderRadius.circular(24),
/// )
/// ```
class CachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool isCircle;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ??
          _ShimmerPlaceholder(
            width: width,
            height: height,
            isCircle: isCircle,
            borderRadius: borderRadius,
          ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          _ErrorFallback(
            width: width,
            height: height,
            isCircle: isCircle,
            borderRadius: borderRadius,
          ),
    );

    if (isCircle) {
      return ClipOval(child: image);
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}

/// A cached [ImageProvider] wrapper for use in places like
/// [CircleAvatar.backgroundImage] or [DecorationImage].
///
/// Usage:
/// ```dart
/// CircleAvatar(
///   backgroundImage: cachedImageProvider('https://...'),
/// )
/// ```
ImageProvider cachedImageProvider(String url) {
  return CachedNetworkImageProvider(url);
}

// ─── Internal shimmer placeholder ──────────────────────────────

class _ShimmerPlaceholder extends StatefulWidget {
  final double? width;
  final double? height;
  final bool isCircle;
  final BorderRadius? borderRadius;

  const _ShimmerPlaceholder({
    this.width,
    this.height,
    this.isCircle = false,
    this.borderRadius,
  });

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius:
                widget.isCircle ? null : (widget.borderRadius ?? BorderRadius.circular(8)),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-1.0 + 2.0 * _controller.value + 1.0, 0),
              colors: const [
                Color(0xFFE8E8E8),
                Color(0xFFF5F5F5),
                Color(0xFFE8E8E8),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Internal error fallback ───────────────────────────────────

class _ErrorFallback extends StatelessWidget {
  final double? width;
  final double? height;
  final bool isCircle;
  final BorderRadius? borderRadius;

  const _ErrorFallback({
    this.width,
    this.height,
    this.isCircle = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF1EFE8),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : (borderRadius ?? BorderRadius.circular(8)),
      ),
      child: Icon(
        Icons.person_outline,
        color: const Color(0xFF5F5E5A),
        size: (width != null && width! < 40) ? 16 : 24,
      ),
    );
  }
}
