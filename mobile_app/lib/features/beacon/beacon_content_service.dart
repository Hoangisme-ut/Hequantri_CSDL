import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_service.dart';

/// Lỗi khi lấy nội dung từ backend.
class BeaconApiException implements Exception {
  const BeaconApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isAuthenticationError => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

/// Hình ảnh, video hoặc audio của hiện vật.
class BeaconMedia {
  const BeaconMedia({
    required this.id,
    required this.type,
    required this.url,
    this.caption,
  });

  final String id;
  final String type;
  final String url;
  final String? caption;

  factory BeaconMedia.fromJson(Map<String, dynamic> json) {
    return BeaconMedia(
      id: json['id'] as String,
      type: json['media_type'] as String,
      url: json['url'] as String,
      caption: json['caption'] as String?,
    );
  }
}

/// Nội dung hiện vật trả về từ API resolve beacon.
class BeaconContent {
  const BeaconContent({
    required this.beaconId,
    required this.artifactId,
    required this.siteId,
    required this.code,
    this.title,
    this.description,
    this.historyContent,
    this.coverImageUrl,
    this.languageCode,
    this.isFallback = false,
    this.media = const [],
  });

  final String beaconId;
  final String artifactId;
  final String siteId;
  final String code;

  final String? title;
  final String? description;
  final String? historyContent;
  final String? coverImageUrl;
  final String? languageCode;

  /// True khi backend trả nội dung của ngôn ngữ thay thế.
  final bool isFallback;

  final List<BeaconMedia> media;

  factory BeaconContent.fromJson(Map<String, dynamic> json) {
    final beacon = json['beacon'] as Map<String, dynamic>;
    final artifact = json['artifact'] as Map<String, dynamic>;

    final mediaJson = artifact['media'] as List<dynamic>? ?? const <dynamic>[];

    return BeaconContent(
      beaconId: beacon['id'] as String,
      artifactId: artifact['id'] as String,
      siteId: artifact['site_id'] as String,
      code: artifact['code'] as String,
      title: artifact['title'] as String?,
      description: artifact['description'] as String?,
      historyContent: artifact['history_content'] as String?,
      coverImageUrl: artifact['cover_image_url'] as String?,
      languageCode: artifact['language_code'] as String?,
      isFallback: artifact['is_fallback'] as bool? ?? false,
      media: List<BeaconMedia>.unmodifiable(
        mediaJson.map(
          (item) => BeaconMedia.fromJson(item as Map<String, dynamic>),
        ),
      ),
    );
  }
}

/// Lớp gọi API dùng chung cho beacon thật và Simulation.
class BeaconContentService {
  BeaconContentService({required Uri baseUrl, http.Client? client})
    : _baseUrl = _validateBaseUrl(baseUrl),
      _client = client ?? http.Client(),
      _ownsClient = client == null;

  final Uri _baseUrl;
  final http.Client _client;
  final bool _ownsClient;

  static const _timeout = Duration(seconds: 20);

  static Uri _validateBaseUrl(Uri url) {
    if ((url.scheme != 'http' && url.scheme != 'https') ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment ||
        (url.path.isNotEmpty && url.path != '/')) {
      throw ArgumentError(
        'baseUrl phải gồm http/https, tên máy và cổng; '
        'không thêm /api/v1.',
      );
    }

    return url;
  }

  Future<BeaconContent> resolve({
    required String proximityUuid,
    required int major,
    required int minor,
    required AuthToken token,
    String? languageCode,
  }) async {
    if (token.accessToken.trim().isEmpty) {
      throw const BeaconApiException(
        'Cần đăng nhập để xem nội dung.',
        statusCode: 401,
      );
    }

    if (proximityUuid.trim().isEmpty ||
        major < 0 ||
        major > 65535 ||
        minor < 0 ||
        minor > 65535) {
      throw const BeaconApiException(
        'UUID, Major hoặc Minor không hợp lệ.',
        statusCode: 422,
      );
    }

    final language = languageCode?.trim();

    final uri = _baseUrl.replace(
      path: '/api/v1/beacons/resolve',
      queryParameters: {
        'proximity_uuid': proximityUuid.trim().toUpperCase(),
        'major': '$major',
        'minor': '$minor',
        if (language != null && language.isNotEmpty) 'lang': language,
      },
    );

    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer ${token.accessToken}',
      });

    try {
      final response = await _send(request).timeout(_timeout);

      if (response.statusCode != 200) {
        throw _responseError(response.statusCode);
      }

      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      return BeaconContent.fromJson(json);
    } on TimeoutException {
      throw const BeaconApiException(
        'Máy chủ phản hồi quá lâu. Vui lòng thử lại.',
      );
    } on http.ClientException {
      throw const BeaconApiException(
        'Không kết nối được máy chủ. Kiểm tra mạng '
        'và địa chỉ backend.',
      );
    } on FormatException {
      throw const BeaconApiException('Dữ liệu máy chủ trả về không hợp lệ.');
    } on TypeError {
      throw const BeaconApiException(
        'Cấu trúc dữ liệu máy chủ trả về không đúng.',
      );
    }
  }

  Future<http.Response> _send(http.Request request) async {
    final response = await _client.send(request);
    return http.Response.fromStream(response);
  }

  BeaconApiException _responseError(int statusCode) {
    final message = switch (statusCode) {
      401 => 'Cần đăng nhập lại để xem nội dung.',
      403 =>
        'Phiên đăng nhập không hợp lệ hoặc tài khoản '
            'không được phép xem nội dung.',
      404 => 'Không tìm thấy beacon hoặc nội dung tương ứng.',
      409 => 'Cấu hình beacon và hiện vật không khớp.',
      400 || 422 => 'Thông tin gửi lên không hợp lệ.',
      429 => 'Đang gửi quá nhiều yêu cầu. Vui lòng thử lại sau.',
      >= 500 => 'Máy chủ đang gặp lỗi. Vui lòng thử lại sau.',
      _ => 'Không lấy được nội dung. Mã HTTP: $statusCode.',
    };

    return BeaconApiException(message, statusCode: statusCode);
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
