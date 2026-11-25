/// Holds the active 30-second diagnosis video clip recorded or selected
/// by the consumer so it automatically attaches to their next job booking
/// and surfaces in the Worker & Admin portals.
class VideoDiagnosisSession {
  VideoDiagnosisSession._();
  static final VideoDiagnosisSession instance = VideoDiagnosisSession._();

  String? activeVideoUrl;
  String? issueCategory;
  DateTime? recordedAt;

  bool get hasClip => activeVideoUrl != null && activeVideoUrl!.isNotEmpty;

  void attachClip({required String videoUrl, String? category}) {
    activeVideoUrl = videoUrl;
    issueCategory = category;
    recordedAt = DateTime.now();
  }

  void clear() {
    activeVideoUrl = null;
    issueCategory = null;
    recordedAt = null;
  }
}
