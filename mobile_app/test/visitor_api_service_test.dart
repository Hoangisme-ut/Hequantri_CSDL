import 'dart:convert';

import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/data/visitor_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _token = AuthToken(accessToken: 'visitor-token', tokenType: 'bearer');
const _artifactId = '20000000-0000-0000-0000-000000000001';
const _beaconId = '30000000-0000-0000-0000-000000000001';
const _siteId = '10000000-0000-0000-0000-000000000001';

Map<String, Object?> _site() => {
  'id': _siteId,
  'name': 'Văn Miếu - Quốc Tử Giám',
  'description': 'Khu di tích lịch sử.',
  'address': 'Hà Nội',
  'latitude': 21.0293,
  'longitude': 105.836,
  'cover_image_url': 'https://example.test/site.jpg',
  'is_active': true,
  'language_code': 'en',
  'is_fallback': false,
};

Map<String, Object?> _artifact() => {
  'id': _artifactId,
  'site_id': '10000000-0000-0000-0000-000000000001',
  'code': 'HTTL-DOAN-MON',
  'era': 'Le dynasty',
  'latitude': null,
  'longitude': null,
  'cover_image_url': null,
  'is_active': true,
  'title': 'Doan Mon Gate',
  'language_code': 'en',
  'is_fallback': false,
};

Map<String, Object?> _favorite() => {
  'id': '40000000-0000-0000-0000-000000000001',
  'user_id': '50000000-0000-0000-0000-000000000001',
  'artifact_id': _artifactId,
  'created_at': '2026-10-31T10:00:00Z',
  'artifact': _artifact(),
};

Map<String, Object?> _visit() => {
  'id': '60000000-0000-0000-0000-000000000001',
  'user_id': '50000000-0000-0000-0000-000000000001',
  'artifact_id': _artifactId,
  'beacon_id': _beaconId,
  'language_id': null,
  'visited_at': '2026-10-31T10:00:00Z',
  'duration_seconds': null,
  'rssi': -61,
  'artifact': _artifact(),
};

Map<String, Object?> _favoriteMutation() => {
  'id': '40000000-0000-0000-0000-000000000001',
  'user_id': '50000000-0000-0000-0000-000000000001',
  'artifact_id': _artifactId,
  'created_at': '2026-10-31T10:00:00Z',
};

Map<String, Object?> _visitMutation(DateTime visitedAt) => {
  'id': '60000000-0000-0000-0000-000000000001',
  'user_id': '50000000-0000-0000-0000-000000000001',
  'artifact_id': _artifactId,
  'beacon_id': _beaconId,
  'language_id': null,
  'visited_at': visitedAt.toUtc().toIso8601String(),
  'duration_seconds': null,
  'rssi': null,
};

void main() {
  test('parses SQL Server UTC-naive visit timestamps as UTC', () async {
    final visit = _visit()..['visited_at'] = '2026-10-31T10:00:00';
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'data': [visit],
          'count': 1,
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final api = HttpVisitorApi(
      baseUrl: Uri.parse('https://api.example.test'),
      client: client,
    );

    final result = await api.loadVisits(token: _token, languageCode: 'vi');

    expect(result.items.single.visitedAt, DateTime.utc(2026, 10, 31, 10));
    expect(result.items.single.visitedAt!.isUtc, isTrue);
    client.close();
  });

  test(
    'loads public Sites and Site detail using the backend contract',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/sites/')) {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'data': [_site()],
                'count': 1,
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response.bytes(
          utf8.encode(jsonEncode(_site())),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = HttpVisitorApi(
        baseUrl: Uri.parse('https://api.example.test'),
        client: client,
      );

      final sites = await api.loadSites(
        languageCode: 'en',
        skip: 10,
        limit: 20,
      );
      final site = await api.loadSite(siteId: _siteId, languageCode: 'vi');

      expect(sites.count, 1);
      expect(sites.items.single.id, _siteId);
      expect(sites.items.single.name, 'Văn Miếu - Quốc Tử Giám');
      expect(sites.items.single.latitude, 21.0293);
      expect(site.description, 'Khu di tích lịch sử.');
      expect(requests[0].url.path, '/api/v1/sites/');
      expect(requests[0].url.queryParameters, {
        'skip': '10',
        'limit': '20',
        'lang': 'en',
      });
      expect(requests[1].url.path, '/api/v1/sites/$_siteId');
      expect(requests[1].url.queryParameters, {'lang': 'vi'});
      expect(requests.every((request) => request.method == 'GET'), isTrue);
      expect(
        requests.every(
          (request) => !request.headers.containsKey('Authorization'),
        ),
        isTrue,
      );
      client.close();
    },
  );

  test(
    'loads public artifact summaries using backend pagination contract',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'data': [_artifact()],
            'count': 1,
          }),
          200,
        );
      });
      final api = HttpVisitorApi(
        baseUrl: Uri.parse('https://api.example.test'),
        client: client,
      );

      final page = await api.loadArtifacts(
        languageCode: 'vi',
        skip: 10,
        limit: 25,
      );

      expect(page.count, 1);
      expect(page.items.single.id, _artifactId);
      expect(page.items.single.title, 'Doan Mon Gate');
      expect(requests.single.url.path, '/api/v1/artifacts/');
      expect(requests.single.url.queryParameters, {
        'lang': 'vi',
        'skip': '10',
        'limit': '25',
      });
      expect(requests.single.headers['Accept'], 'application/json');
      expect(requests.single.headers.containsKey('Authorization'), isFalse);
      client.close();
    },
  );

  test(
    'loads Favorites and History with page schema and Bearer token',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.startsWith('/api/v1/artifacts/')) {
          return http.Response(
            jsonEncode({
              ..._artifact(),
              'description': 'Artifact description',
              'history_content': 'Artifact history',
              'media': <Object>[],
            }),
            200,
          );
        }
        final data = request.url.path.endsWith('/favorites/me')
            ? [_favorite()]
            : [_visit()];
        return http.Response(
          jsonEncode({'data': data, 'count': 1}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = HttpVisitorApi(
        baseUrl: Uri.parse('https://api.example.test'),
        client: client,
      );

      final favorites = await api.loadFavorites(
        token: _token,
        languageCode: 'en',
        skip: 20,
        limit: 10,
      );
      final visits = await api.loadVisits(token: _token, languageCode: 'vi');
      final artifact = await api.loadArtifact(
        artifactId: _artifactId,
        languageCode: 'en',
      );

      expect(favorites.count, 1);
      expect(favorites.items.single.artifactId, _artifactId);
      expect(favorites.items.single.artifact.title, 'Doan Mon Gate');
      expect(visits.items.single.beaconId, _beaconId);
      expect(artifact.description, 'Artifact description');
      expect(artifact.historyContent, 'Artifact history');
      expect(requests[0].url.queryParameters, {
        'lang': 'en',
        'skip': '20',
        'limit': '10',
      });
      expect(requests[1].url.queryParameters['lang'], 'vi');
      expect(requests[2].url.queryParameters['lang'], 'en');
      expect(requests[0].headers['Authorization'], 'Bearer visitor-token');
      expect(requests[1].headers['Authorization'], 'Bearer visitor-token');
      expect(requests[2].headers.containsKey('Authorization'), isFalse);
      client.close();
    },
  );

  test('posts the schema payloads for favorite and visit mutations', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/favorites/') {
        return http.Response(jsonEncode(_favoriteMutation()), 201);
      }
      if (request.url.path == '/api/v1/visits/') {
        return http.Response(
          jsonEncode(_visitMutation(DateTime.utc(2026, 10, 31))),
          201,
        );
      }
      return http.Response('{}', 200);
    });
    final api = HttpVisitorApi(
      baseUrl: Uri.parse('https://api.example.test'),
      client: client,
    );

    await api.addFavorite(token: _token, artifactId: _artifactId);
    await api.removeFavorite(token: _token, artifactId: _artifactId);
    final receipt = await api.recordVisit(
      token: _token,
      artifactId: _artifactId,
      beaconId: _beaconId,
      rssi: -61,
      durationSeconds: -1,
    );

    expect(requests[0].url.path, '/api/v1/favorites/');
    expect(jsonDecode(requests[0].body), {'artifact_id': _artifactId});
    expect(requests[1].method, 'DELETE');
    expect(requests[1].url.path, '/api/v1/favorites/$_artifactId');
    expect(jsonDecode(requests[2].body), {
      'artifact_id': _artifactId,
      'beacon_id': _beaconId,
      'rssi': -61,
    });
    expect(receipt.wasCreated, isTrue);
    expect(receipt.visitedAt, DateTime.utc(2026, 10, 31));
    expect(
      requests.every(
        (request) => request.headers['Authorization'] == 'Bearer visitor-token',
      ),
      isTrue,
    );
    client.close();
  });

  test('Visit receipt preserves backend time and duplicate status', () async {
    final backendTime = DateTime.utc(2026, 10, 30, 12);
    var requestIndex = 0;
    final client = MockClient((_) async {
      requestIndex++;
      return http.Response(
        jsonEncode(_visitMutation(backendTime)),
        requestIndex == 1 ? 201 : 200,
      );
    });
    final api = HttpVisitorApi(
      baseUrl: Uri.parse('https://api.example.test'),
      client: client,
    );

    final created = await api.recordVisit(
      token: _token,
      artifactId: _artifactId,
    );
    final duplicate = await api.recordVisit(
      token: _token,
      artifactId: _artifactId,
    );

    expect(created.wasCreated, isTrue);
    expect(duplicate.wasCreated, isFalse);
    expect(created.visitedAt, backendTime);
    expect(duplicate.visitedAt, backendTime);
    client.close();
  });

  test('rejects invalid mutation UUIDs without sending requests', () async {
    var requestCount = 0;
    final client = MockClient((_) async {
      requestCount++;
      return http.Response('{}', 200);
    });
    final api = HttpVisitorApi(
      baseUrl: Uri.parse('https://api.example.test'),
      client: client,
    );

    await expectLater(
      api.addFavorite(token: _token, artifactId: 'artifact-001'),
      throwsA(
        isA<VisitorApiException>().having(
          (error) => error.message,
          'message',
          contains('artifact_id'),
        ),
      ),
    );
    await expectLater(
      api.removeFavorite(token: _token, artifactId: 'artifact-001'),
      throwsA(isA<VisitorApiException>()),
    );
    await expectLater(
      api.recordVisit(token: _token, artifactId: 'artifact-001'),
      throwsA(isA<VisitorApiException>()),
    );
    await expectLater(
      api.recordVisit(
        token: _token,
        artifactId: _artifactId,
        beaconId: 'beacon-001',
      ),
      throwsA(isA<VisitorApiException>()),
    );

    expect(requestCount, 0);
    client.close();
  });

  test('rejects malformed UUIDs in backend response records', () async {
    final malformedFavorite = _favorite()..['artifact_id'] = 'artifact-001';
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'data': [malformedFavorite],
          'count': 1,
        }),
        200,
      ),
    );
    final api = HttpVisitorApi(
      baseUrl: Uri.parse('https://api.example.test'),
      client: client,
    );

    await expectLater(
      api.loadFavorites(token: _token, languageCode: 'vi'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('artifact_id'),
        ),
      ),
    );
    client.close();
  });

  test(
    'rejects invalid UUIDs in Favorite and Visit mutation responses',
    () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/favorites/') {
          return http.Response(
            jsonEncode({..._favoriteMutation(), 'user_id': 'not-a-uuid'}),
            201,
          );
        }
        return http.Response(
          jsonEncode({
            ..._visitMutation(DateTime.utc(2026)),
            'beacon_id': 'beacon-1',
          }),
          201,
        );
      });
      final api = HttpVisitorApi(
        baseUrl: Uri.parse('https://api.example.test'),
        client: client,
      );

      await expectLater(
        api.addFavorite(token: _token, artifactId: _artifactId),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        api.recordVisit(token: _token, artifactId: _artifactId),
        throwsA(isA<FormatException>()),
      );
      client.close();
    },
  );

  test('surfaces authentication and network failures', () async {
    final unauthorizedClient = MockClient(
      (_) async => http.Response('{}', 401),
    );
    final unauthorizedApi = HttpVisitorApi(
      baseUrl: Uri.parse('https://api.example.test'),
      client: unauthorizedClient,
    );
    await expectLater(
      unauthorizedApi.loadFavorites(token: _token, languageCode: 'vi'),
      throwsA(
        isA<VisitorApiException>().having(
          (e) => e.isAuthenticationError,
          'auth',
          isTrue,
        ),
      ),
    );
    unauthorizedClient.close();

    final networkClient = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    final networkApi = HttpVisitorApi(
      baseUrl: Uri.parse('https://api.example.test'),
      client: networkClient,
    );
    await expectLater(
      networkApi.loadVisits(token: _token, languageCode: 'vi'),
      throwsA(isA<VisitorApiException>()),
    );
    networkClient.close();

    final failedMutationClient = MockClient(
      (_) async => http.Response('{}', 500),
    );
    final failedMutationApi = HttpVisitorApi(
      baseUrl: Uri.parse('https://api.example.test'),
      client: failedMutationClient,
    );
    await expectLater(
      failedMutationApi.addFavorite(token: _token, artifactId: _artifactId),
      throwsA(isA<VisitorApiException>()),
    );
    failedMutationClient.close();
  });
}
