import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Shared playable 30-second customer diagnosis video modal for Worker screens.
class DiagnosisVideoPreviewDialog extends StatefulWidget {
  final String videoUrl;
  final String title;

  const DiagnosisVideoPreviewDialog({
    super.key,
    required this.videoUrl,
    this.title = '30s Customer Diagnosis Video',
  });

  static Future<void> show(
    BuildContext context, {
    required String videoUrl,
    String title = '30s Customer Diagnosis Video',
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => DiagnosisVideoPreviewDialog(
        videoUrl: videoUrl,
        title: title,
      ),
    );
  }

  @override
  State<DiagnosisVideoPreviewDialog> createState() =>
      _DiagnosisVideoPreviewDialogState();
}

class _DiagnosisVideoPreviewDialogState
    extends State<DiagnosisVideoPreviewDialog> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final url = widget.videoUrl.trim();
      final ctrl = url.startsWith('http')
          ? VideoPlayerController.networkUrl(Uri.parse(url))
          : VideoPlayerController.asset(url);
      _controller = ctrl;
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
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
      insetPadding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.videocam_rounded,
                        color: Color(0xFF4ADE80),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                AspectRatio(
                  aspectRatio: _ready && _controller != null
                      ? _controller!.value.aspectRatio
                      : 9 / 14,
                  child: _error
                      ? const Center(
                          child: Text(
                            'Unable to load diagnosis video',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        )
                      : !_ready || _controller == null
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF4ADE80),
                              ),
                            )
                          : GestureDetector(
                              onTap: () {
                                if (_controller!.value.isPlaying) {
                                  _controller!.pause();
                                } else {
                                  _controller!.play();
                                }
                                setState(() {});
                              },
                              child: VideoPlayer(_controller!),
                            ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
