class AudioJob {
  AudioJob({
    required this.id,
    required this.status,
    required this.originalFilename,
    required this.createdAt,
    this.transcriptRaw,
    this.transcriptClean,
    this.analysis,
  });

  final String id;
  final String status;
  final String originalFilename;
  final DateTime createdAt;
  final String? transcriptRaw;
  final String? transcriptClean;
  final Map<String, dynamic>? analysis;

  factory AudioJob.fromJson(Map<String, dynamic> json) {
    return AudioJob(
      id: json['id'] as String,
      status: json['status'] as String,
      originalFilename: json['original_filename'] as String? ?? 'Áudio',
      createdAt: DateTime.parse(json['created_at'] as String),
      transcriptRaw: json['transcript_raw'] as String?,
      transcriptClean: json['transcript_clean'] as String?,
      analysis: json['analysis_json'] as Map<String, dynamic>?,
    );
  }
}
