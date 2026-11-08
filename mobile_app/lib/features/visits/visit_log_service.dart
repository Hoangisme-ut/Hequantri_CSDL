import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_service.dart';

class VisitLogException implements Exception {
  const VisitLogException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class VisitRecord {
  const VisitRecord({
    required this.id,
    required this.artifactId,
    this.beaconId,
    this.visitedAt,
  });

  final String id;
  final String artifactId;
  final String? beaconId;
  final DateTime? visitedAt;

  factory VisitRecord.fromJson(Map<String, dynamic> json) {
    final timestamp = json['visited_at'] as String?;
    // SQL Server can return UTC timestamps without a timezone suffix.
    final utcTimestamp =
        timestamp == null ||
            RegExp(
              r'(Z|[+-]\d{2}:\d{2})$',
              caseSensitive: false,
            ).hasMatch(timestamp)
        ? timestamp
        : '${timestamp}Z';

    return VisitRecord(
      id: json['id'] as String,
      artifactId: json['artifact_id'] as String,
      beaconId: json['beacon_id'] as String?,
      visitedAt: utcTimestamp == null ? null : DateTime.parse(utcTimestamp),
    );
  }
}

class VisitRecordResult {
  const VisitRecordResult({required this.visit, required this.alreadyRecorded});

  final VisitRecord visit;

  /// HTTP 200: server reused a visit from its 300-second deduplication window.
  final bool alreadyRecorded;
}

class VisitHistoryEntry {
  const VisitHistoryEntry({
    required this.visit,
    required this.code,
    this.title,
    this.era,
    this.languageCode,
    this.isFallback = false,
  });

  final VisitRecord visit;
  final String code;
  final String? title;
  final String? era;
  final String? languageCode;
  final bool isFallback;

  factory VisitHistoryEntry.fromJson(Map<String, dynamic> json) {
    final artifact = json['artifact'] as Map<String, dynamic>;
    return VisitHistoryEntry(
      visit: VisitRecord.fromJson(json),
      code: artifact['code'] as String,
      title: artifact['title'] as String?,
      era: artifact['era'] as String?,
      languageCode: artifact['language_code'] as String?,
      isFallback: artifact['is_fallback'] as bool? ?? false,
    );
  }
}

class VisitHistoryResult {
  const VisitHistoryResult({required this.entries, required this.count});

  final List<VisitHistoryEntry> entries;
  final int count;
}

/// Temporary VisitLog contract pending P2 confirmation; identity uses the token.
class VisitLogService {
  VisitLogService({required Uri baseUrl, http.Client? client})
    : _baseUrl = _validateBaseUrl(baseUrl),
      _client = client ?? http.Client(),
      _ownsClient = client == null;

  final Uri _baseUrl;
  final http.Client _client;
  final bool _ownsClient;

  static Uri _validateBaseUrl(Uri url) {
    if ((url.scheme != 'http' && url.scheme != 'https') ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment ||
        (url.path.isNotEmpty && url.path != '/')) {
      throw ArgumentError('baseUrl phải là địa chỉ gốc, không thêm /api/v1.');
    }
    return url;
  }

  Future<VisitRecordResult> record({
    required String artifactId,
    required String beaconId,
    required AuthToken token,
    int? rssi,
  }) async {
    final response = await _request(
      'POST',
      '/api/v1/visits/',
      token,
      payload: {
        'artifact_id': artifactId,
        'beacon_id': beaconId,
        'rssi': ?rssi,
        // language_id omitted: backend resolves user preference/default language.
        // duration_seconds omitted: no viewing duration has been measured.
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _responseError(response.statusCode);
    }

    return _decode(
      () => VisitRecordResult(
        visit: VisitRecord.fromJson(_json(response)),
        alreadyRecorded: response.statusCode == 200,
      ),
    );
  }

  Future<VisitHistoryResult> history({
    required AuthToken token,
    String languageCode = 'vi',
    int skip = 0,
    int limit = 20,
  }) async {
    if (skip < 0 || limit < 1 || limit > 100) {
      throw ArgumentError('Phân trang lịch sử không hợp lệ.');
    }

    final response = await _request(
      'GET',
      '/api/v1/visits/me',
      token,
      query: {'lang': languageCode, 'skip': '$skip', 'limit': '$limit'},
    );
    if (response.statusCode != 200) {
      throw _responseError(response.statusCode);
    }

    return _decode(() {
      final json = _json(response);
      return VisitHistoryResult(
        entries: List<VisitHistoryEntry>.unmodifiable(
          (json['data'] as List<dynamic>).map(
            (item) => VisitHistoryEntry.fromJson(item as Map<String, dynamic>),
          ),
        ),
        count: json['count'] as int,
      );
    });
  }

  Map<String, dynamic> _json(http.Response response) =>
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

  T _decode<T>(T Function() decode) {
    try {
      return decode();
    } on FormatException {
      throw const VisitLogException('Dữ liệu lịch sử trả về không hợp lệ.');
    } on TypeError {
      throw const VisitLogException('Cấu trúc dữ liệu lịch sử không hợp lệ.');
    }
  }

  Future<http.Response> _request(
    String method,
    String path,
    AuthToken token, {
    Map<String, dynamic>? payload,
    Map<String, String>? query,
  }) async {
    if (token.accessToken.trim().isEmpty) {
      throw const VisitLogException(
        'Cần đăng nhập để sử dụng lịch sử tham quan.',
        statusCode: 401,
      );
    }

    final request =
        http.Request(
            method,
            _baseUrl.replace(path: path, queryParameters: query),
          )
          ..followRedirects = false
          ..headers.addAll({
            'Accept': 'application/json',
            'Authorization': 'Bearer ${token.accessToken}',
          });
    if (payload != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(payload);
    }

    try {
      return await _send(request).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const VisitLogException(
        'Máy chủ phản hồi quá lâu. Vui lòng thử lại.',
      );
    } on http.ClientException {
      throw const VisitLogException('Không kết nối được máy chủ lịch sử.');
    }
  }

  Future<http.Response> _send(http.Request request) async =>
      http.Response.fromStream(await _client.send(request));

  VisitLogException _responseError(int statusCode) =>
      VisitLogException(switch (statusCode) {
        401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        403 => 'Tài khoản không có quyền sử dụng lịch sử tham quan.',
        404 => 'Không tìm thấy hiện vật, beacon hoặc API lịch sử.',
        400 || 422 => 'Thông tin lượt xem không hợp lệ.',
        429 => 'Quá nhiều yêu cầu. Vui lòng thử lại sau.',
        >= 500 => 'Máy chủ lịch sử đang gặp lỗi. Vui lòng thử lại.',
        _ => 'Không xử lý được lịch sử. Mã HTTP: $statusCode.',
      }, statusCode: statusCode);

  void close() {
    if (_ownsClient) _client.close();
  }
}
