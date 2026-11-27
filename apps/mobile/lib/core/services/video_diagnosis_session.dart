import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';

/// Holds the active 30-second diagnosis video clip recorded or selected
/// by the consumer so it automatically attaches to their next job booking
/// and surfaces in the Worker & Admin portals.
class VideoDiagnosisSession {
  VideoDiagnosisSession._();
  static final VideoDiagnosisSession instance = VideoDiagnosisSession._();

  String? activeVideoUrl;
  String? issueCategory;
  DateTime? recordedAt;
  bool isUploading = false;

  bool get hasClip => activeVideoUrl != null && activeVideoUrl!.isNotEmpty;

  void attachClip({required String videoUrl, String? category}) {
    activeVideoUrl = videoUrl;
    issueCategory = category;
    recordedAt = DateTime.now();
  }

  /// Uploads raw 30s video bytes to Supabase Storage (`diagnosis-videos` bucket)
  /// and falls back to [fallbackAssetPath] if Storage is unavailable.
  Future<String> uploadClipToSupabase({
    required Uint8List bytes,
    required String fileName,
    String? category,
    String fallbackAssetPath = 'assets/videos/ac.mp4',
  }) async {
    isUploading = true;
    try {
      final ext = fileName.contains('.') ? fileName.split('.').last : 'mp4';
      final path = 'clips/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await SupabaseConfig.client.storage
          .from('diagnosis-videos')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'video/mp4',
              upsert: true,
            ),
          );
      final publicUrl = SupabaseConfig.client.storage
          .from('diagnosis-videos')
          .getPublicUrl(path);
      attachClip(videoUrl: publicUrl, category: category);
      return publicUrl;
    } catch (_) {
      attachClip(videoUrl: fallbackAssetPath, category: category);
      return fallbackAssetPath;
    } finally {
      isUploading = false;
    }
  }

  void clear() {
    activeVideoUrl = null;
    issueCategory = null;
    recordedAt = null;
  }
}
