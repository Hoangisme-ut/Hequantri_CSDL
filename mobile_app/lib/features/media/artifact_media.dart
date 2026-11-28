class ArtifactMedia {
  const ArtifactMedia({
    required this.id,
    required this.type,
    required this.url,
    this.caption,
    this.languageCode,
  });

  final String id;
  final String type;
  final String url;
  final String? caption;

  /// Mã ngôn ngữ của media này (vd: 'vi', 'en').
  /// null = media dùng chung cho mọi ngôn ngữ (ảnh thumbnail, v.v.)
  final String? languageCode;

  bool get isPlayable => type == 'audio' || type == 'video';

  /// Media này có thuộc ngôn ngữ [code] không, hoặc là shared (languageCode == null)?
  bool matchesLang(String code) =>
      languageCode == null || languageCode == code;

  factory ArtifactMedia.fromJson(Map<String, dynamic> json) {
    return ArtifactMedia(
      id: json['id'] as String,
      type: (json['media_type'] as String).toLowerCase(),
      url: json['url'] as String,
      caption: json['caption'] as String?,
      languageCode: json['language_code'] as String?,
    );
  }
}
