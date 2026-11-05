import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_service.dart';

class VisitorApiException implements Exception {
  const VisitorApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isAuthenticationError => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

class VisitorArtifactSummary {
  const VisitorArtifactSummary({
    required this.id,
    required this.siteId,
    required this.code,
    required this.isActive,
    this.era,
    this.latitude,
    this.longitude,
    this.coverImageUrl,
    this.title,
    this.languageCode,
    this.isFallback = false,
  });

  final String id;
  final String siteId;
  final String code;
  final String? era;
  final double? latitude;
  final double? longitude;
  final String? coverImageUrl;
  final bool isActive;
  final String? title;
  final String? languageCode;
  final bool isFallback;

  factory VisitorArtifactSummary.fromJson(Map<String, dynamic> json) =>
      VisitorArtifactSummary(
        id: _responseUuid(json, 'id'),
        siteId: _responseUuid(json, 'site_id'),
        code: json['code'] as String,
        era: json['era'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        coverImageUrl: json['cover_image_url'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        title: json['title'] as String?,
        languageCode: json['language_code'] as String?,
        isFallback: json['is_fallback'] as bool? ?? false,
      );
}

class VisitorArtifactContent {
  const VisitorArtifactContent({
    required this.id,
    required this.siteId,
    required this.code,
    this.era,
    this.coverImageUrl,
    this.title,
    this.description,
    this.historyContent,
    this.languageCode,
    this.isFallback = false,
  });

  final String id;
  final String siteId;
  final String code;
  final String? era;
  final String? coverImageUrl;
  final String? title;
  final String? description;
  final String? historyContent;
  final String? languageCode;
  final bool isFallback;

  factory VisitorArtifactContent.fromJson(Map<String, dynamic> json) =>
      VisitorArtifactContent(
        id: _responseUuid(json, 'id'),
        siteId: _responseUuid(json, 'site_id'),
        code: json['code'] as String,
        era: json['era'] as String?,
        coverImageUrl: json['cover_image_url'] as String?,
        title: json['title'] as String?,
        description: json['description'] as String?,
        historyContent: json['history_content'] as String?,
        languageCode: json['language_code'] as String?,
        isFallback: json['is_fallback'] as bool? ?? false,
      );
}

class VisitorSite {
  const VisitorSite({
    required this.id,
    required this.name,
    this.description,
    this.address,
    this.latitude,
    this.longitude,
    this.coverImageUrl,
    this.isActive = true,
    this.languageCode,
    this.isFallback = false,
  });

  final String id;
  final String name;
  final String? description;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? coverImageUrl;
  final bool isActive;
  final String? languageCode;
  final bool isFallback;

  factory VisitorSite.fromJson(Map<String, dynamic> json) => VisitorSite(
    id: _responseUuid(json, 'id'),
    name: json['name'] as String,
    description: json['description'] as String?,
    address: json['address'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    coverImageUrl: json['cover_image_url'] as String?,
    isActive: json['is_active'] as bool? ?? true,
    languageCode: json['language_code'] as String?,
    isFallback: json['is_fallback'] as bool? ?? false,
  );
}

class VisitorFavorite {
  const VisitorFavorite({
    required this.id,
    required this.userId,
    required this.artifactId,
    required this.artifact,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String artifactId;
  final DateTime? createdAt;
  final VisitorArtifactSummary artifact;

  factory VisitorFavorite.fromJson(Map<String, dynamic> json) =>
      VisitorFavorite(
        id: _responseUuid(json, 'id'),
        userId: _responseUuid(json, 'user_id'),
        artifactId: _responseUuid(json, 'artifact_id'),
        createdAt: _dateOrNull(json['created_at']),
        artifact: VisitorArtifactSummary.fromJson(
          json['artifact'] as Map<String, dynamic>,
        ),
      );
}

class VisitorVisit {
  const VisitorVisit({
    required this.id,
    required this.userId,
    required this.artifactId,
    required this.artifact,
    this.beaconId,
    this.languageId,
    this.visitedAt,
    this.durationSeconds,
    this.rssi,
  });

  final String id;
  final String userId;
  final String artifactId;
  final String? beaconId;
  final String? languageId;
  final DateTime? visitedAt;
  final int? durationSeconds;
  final int? rssi;
  final VisitorArtifactSummary artifact;

  factory VisitorVisit.fromJson(Map<String, dynamic> json) => VisitorVisit(
    id: _responseUuid(json, 'id'),
    userId: _responseUuid(json, 'user_id'),
    artifactId: _responseUuid(json, 'artifact_id'),
    beaconId: _optionalResponseUuid(json, 'beacon_id'),
    languageId: _optionalResponseUuid(json, 'language_id'),
    visitedAt: _dateOrNull(json['visited_at']),
    durationSeconds: json['duration_seconds'] as int?,
    rssi: json['rssi'] as int?,
    artifact: VisitorArtifactSummary.fromJson(
      json['artifact'] as Map<String, dynamic>,
    ),
  );
}

class VisitorVisitReceipt {
  const VisitorVisitReceipt({
    required this.id,
    required this.userId,
    required this.artifactId,
    required this.wasCreated,
    this.beaconId,
    this.languageId,
    this.visitedAt,
    this.durationSeconds,
    this.rssi,
  });

  final String id;
  final String userId;
  final String artifactId;
  final String? beaconId;
  final String? languageId;
  final DateTime? visitedAt;
  final int? durationSeconds;
  final int? rssi;
  final bool wasCreated;

  factory VisitorVisitReceipt.fromJson(
    Map<String, dynamic> json, {
    required int statusCode,
  }) {
    if (statusCode != 200 && statusCode != 201) {
      throw FormatException('Unexpected Visit response status: $statusCode.');
    }
    return VisitorVisitReceipt(
      id: _responseUuid(json, 'id'),
      userId: _responseUuid(json, 'user_id'),
      artifactId: _responseUuid(json, 'artifact_id'),
      beaconId: _optionalResponseUuid(json, 'beacon_id'),
      languageId: _optionalResponseUuid(json, 'language_id'),
      visitedAt: _dateOrNull(json['visited_at']),
      durationSeconds: json['duration_seconds'] as int?,
      rssi: json['rssi'] as int?,
      wasCreated: statusCode == 201,
    );
  }
}

class _FavoriteMutationReceipt {
  const _FavoriteMutationReceipt();

  factory _FavoriteMutationReceipt.fromJson(Map<String, dynamic> json) {
    _responseUuid(json, 'id');
    _responseUuid(json, 'user_id');
    _responseUuid(json, 'artifact_id');
    _dateOrNull(json['created_at']);
    return const _FavoriteMutationReceipt();
  }
}

class VisitorPage<T> {
  const VisitorPage({required this.items, required this.count});

  final List<T> items;
  final int count;
}

abstract interface class SiteApi {
  Future<VisitorPage<VisitorSite>> loadSites({
    required String languageCode,
    int skip = 0,
    int limit = 50,
  });

  Future<VisitorSite> loadSite({
    required String siteId,
    required String languageCode,
  });
}

abstract interface class VisitorApi {
  Future<VisitorPage<VisitorArtifactSummary>> loadArtifacts({
    required String languageCode,
    int skip = 0,
    int limit = 50,
  });

  Future<VisitorArtifactContent> loadArtifact({
    required String artifactId,
    required String languageCode,
  });

  Future<VisitorPage<VisitorFavorite>> loadFavorites({
    required AuthToken token,
    required String languageCode,
    int skip = 0,
    int limit = 50,
  });

  Future<void> addFavorite({
    required AuthToken token,
    required String artifactId,
  });
  Future<void> removeFavorite({
    required AuthToken token,
    required String artifactId,
  });

  Future<VisitorPage<VisitorVisit>> loadVisits({
    required AuthToken token,
    required String languageCode,
    int skip = 0,
    int limit = 50,
  });

  Future<VisitorVisitReceipt> recordVisit({
    required AuthToken token,
    required String artifactId,
    String? beaconId,
    int? rssi,
    int? durationSeconds,
  });
}

class HttpVisitorApi implements VisitorApi, SiteApi {
  HttpVisitorApi({required Uri baseUrl, http.Client? client})
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
      throw ArgumentError('baseUrl must be an HTTP(S) origin without a path.');
    }
    return url;
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      _baseUrl.replace(path: '/api/v1$path', queryParameters: query);

  Map<String, String> _headers(AuthToken token, {bool json = false}) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer ${token.accessToken}',
    if (json) 'Content-Type': 'application/json',
  };

  @override
  Future<VisitorPage<VisitorArtifactSummary>> loadArtifacts({
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) async {
    final response = await _send(
      () => _client.get(
        _uri('/artifacts/', {
          'lang': languageCode,
          'skip': '$skip',
          'limit': '$limit',
        }),
        headers: const {'Accept': 'application/json'},
      ),
    );
    final body = _decodeObject(response);
    return VisitorPage(
      items: (body['data'] as List<dynamic>)
          .map(
            (item) =>
                VisitorArtifactSummary.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      count: body['count'] as int,
    );
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw VisitorApiException(switch (response.statusCode) {
          401 => 'Your session has expired. Please sign in again.',
          403 => 'Your account cannot access this data.',
          404 => 'The requested heritage record was not found.',
          >= 500 => 'The server is unavailable. Please try again.',
          _ => 'The request failed (${response.statusCode}).',
        }, statusCode: response.statusCode);
      }
      return response;
    } on VisitorApiException {
      rethrow;
    } on TimeoutException {
      throw const VisitorApiException('The server took too long to respond.');
    } on http.ClientException {
      throw const VisitorApiException('Could not connect to the server.');
    }
  }

  Map<String, dynamic> _decodeObject(http.Response response) =>
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

  @override
  Future<VisitorPage<VisitorSite>> loadSites({
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) async {
    final response = await _send(
      () => _client.get(
        _uri('/sites/', {
          'skip': '$skip',
          'limit': '$limit',
          'lang': languageCode,
        }),
        headers: const {'Accept': 'application/json'},
      ),
    );
    final body = _decodeObject(response);
    return VisitorPage(
      items: (body['data'] as List<dynamic>)
          .map((item) => VisitorSite.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      count: body['count'] as int,
    );
  }

  @override
  Future<VisitorSite> loadSite({
    required String siteId,
    required String languageCode,
  }) async {
    _requireRequestUuid(siteId, 'site_id');
    final response = await _send(
      () => _client.get(
        _uri('/sites/$siteId', {'lang': languageCode}),
        headers: const {'Accept': 'application/json'},
      ),
    );
    return VisitorSite.fromJson(_decodeObject(response));
  }

  @override
  Future<VisitorArtifactContent> loadArtifact({
    required String artifactId,
    required String languageCode,
  }) async {
    _requireRequestUuid(artifactId, 'artifact_id');
    final response = await _send(
      () => _client.get(
        _uri('/artifacts/$artifactId', {'lang': languageCode}),
        headers: {'Accept': 'application/json'},
      ),
    );
    return VisitorArtifactContent.fromJson(_decodeObject(response));
  }

  @override
  Future<VisitorPage<VisitorFavorite>> loadFavorites({
    required AuthToken token,
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) async {
    final response = await _send(
      () => _client.get(
        _uri('/favorites/me', {
          'lang': languageCode,
          'skip': '$skip',
          'limit': '$limit',
        }),
        headers: _headers(token),
      ),
    );
    final body = _decodeObject(response);
    return VisitorPage(
      items: (body['data'] as List<dynamic>)
          .map((item) => VisitorFavorite.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      count: body['count'] as int,
    );
  }

  @override
  Future<void> addFavorite({
    required AuthToken token,
    required String artifactId,
  }) async {
    _requireRequestUuid(artifactId, 'artifact_id');
    final response = await _send(
      () => _client.post(
        _uri('/favorites/'),
        headers: _headers(token, json: true),
        body: jsonEncode({'artifact_id': artifactId}),
      ),
    );
    _FavoriteMutationReceipt.fromJson(_decodeObject(response));
  }

  @override
  Future<void> removeFavorite({
    required AuthToken token,
    required String artifactId,
  }) async {
    _requireRequestUuid(artifactId, 'artifact_id');
    await _send(
      () => _client.delete(
        _uri('/favorites/$artifactId'),
        headers: _headers(token),
      ),
    );
  }

  @override
  Future<VisitorPage<VisitorVisit>> loadVisits({
    required AuthToken token,
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) async {
    final response = await _send(
      () => _client.get(
        _uri('/visits/me', {
          'lang': languageCode,
          'skip': '$skip',
          'limit': '$limit',
        }),
        headers: _headers(token),
      ),
    );
    final body = _decodeObject(response);
    return VisitorPage(
      items: (body['data'] as List<dynamic>)
          .map((item) => VisitorVisit.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      count: body['count'] as int,
    );
  }

  @override
  Future<VisitorVisitReceipt> recordVisit({
    required AuthToken token,
    required String artifactId,
    String? beaconId,
    int? rssi,
    int? durationSeconds,
  }) async {
    _requireRequestUuid(artifactId, 'artifact_id');
    final payload = <String, Object>{'artifact_id': artifactId};
    if (beaconId != null && beaconId.isNotEmpty) {
      _requireRequestUuid(beaconId, 'beacon_id');
      payload['beacon_id'] = beaconId;
    }
    if (rssi != null && rssi < 0) {
      payload['rssi'] = rssi;
    }
    if (durationSeconds != null && durationSeconds >= 0) {
      payload['duration_seconds'] = durationSeconds;
    }
    final response = await _send(
      () => _client.post(
        _uri('/visits/'),
        headers: _headers(token, json: true),
        body: jsonEncode(payload),
      ),
    );
    return VisitorVisitReceipt.fromJson(
      _decodeObject(response),
      statusCode: response.statusCode,
    );
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

DateTime? _dateOrNull(Object? value) {
  if (value == null) return null;
  final timestamp = value as String;
  // SQL Server/pyodbc deployments may serialize a UTC datetime without an
  // offset. Treat that form as UTC, while preserving explicit offsets.
  final hasTimezone = RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(timestamp);
  return DateTime.parse(hasTimezone ? timestamp : '${timestamp}Z');
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

void _requireRequestUuid(String value, String field) {
  if (!_uuidPattern.hasMatch(value)) {
    throw VisitorApiException('$field must be a valid UUID.');
  }
}

String _responseUuid(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String || !_uuidPattern.hasMatch(value)) {
    throw FormatException('Response field "$field" must contain a valid UUID.');
  }
  return value;
}

String? _optionalResponseUuid(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) return null;
  if (value is! String || !_uuidPattern.hasMatch(value)) {
    throw FormatException('Response field "$field" must contain a valid UUID.');
  }
  return value;
}
