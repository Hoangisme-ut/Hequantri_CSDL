class ArtifactMedia {
  const ArtifactMedia({
    required this.id,
    required this.type,
    required this.url,
    this.caption,
  });

  final String id;
  final String type;
  final String url;
  final String? caption;

  bool get isPlayable => type == 'audio' || type == 'video';

  factory ArtifactMedia.fromJson(Map<String, dynamic> json) {
    return ArtifactMedia(
      id: json['id'] as String,
      type: (json['media_type'] as String).toLowerCase(),
      url: json['url'] as String,
      caption: json['caption'] as String?,
    );
  }
}
