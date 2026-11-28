class ArtifactMedia {
  const ArtifactMedia({
    required this.id,
    required this.type,
    required this.url,
    this.caption,
    this.languageId,
    this.languageCode,
  });

  final String id;
  final String type;
  final String url;
  final String? caption;

  /// ID ngôn ngữ của media (null = media dùng chung).
  final String? languageId;

  /// Mã ngôn ngữ của media này (vd: 'vi', 'en').
  /// null = media dùng chung (hoặc backend chưa trả về language_code).
  final String? languageCode;

  bool get isPlayable => type == 'audio' || type == 'video';

  /// Media này có thuộc ngôn ngữ [code] không?
  /// Nếu backend chưa trả `language_code`, bất kỳ media nào có `language_id != null`
  /// đều đã được endpoint `?lang=` lọc đúng cho ngôn ngữ hiện tại.
  bool isForLanguage(String code) =>
      languageCode == code || (languageCode == null && languageId != null);

  /// Media dùng chung cho mọi ngôn ngữ (không gắn `language_id` và `language_code`).
  bool get isShared => languageCode == null && languageId == null;

  factory ArtifactMedia.fromJson(Map<String, dynamic> json) {
    return ArtifactMedia(
      id: json['id'] as String,
      type: (json['media_type'] as String).toLowerCase(),
      url: json['url'] as String,
      caption: json['caption'] as String?,
      languageId: json['language_id'] as String?,
      languageCode: json['language_code'] as String?,
    );
  }
}
