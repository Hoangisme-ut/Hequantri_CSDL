import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/visits/visit_log_service.dart';

const _token = AuthToken(accessToken: 'visitor-token', tokenType: 'bearer');

Map<String, dynamic> _visit() => {
  'id': 'visit-1',
  'artifact_id': 'artifact-1',
  'beacon_id': 'beacon-1',
  'visited_at': '2026-11-01T12:00:00',
};

void main() {
  for (final status in [200, 201]) {
    test(
      'record accepts HTTP $status and sends only the agreed payload',
      () async {
        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/visits/');
          expect(request.headers['Authorization'], 'Bearer visitor-token');
          expect(request.followRedirects, isFalse);
          expect(jsonDecode(request.body), {
            'artifact_id': 'artifact-1',
            'beacon_id': 'beacon-1',
            'rssi': -48,
          });
          return http.Response(jsonEncode(_visit()), status);
        });
        final service = VisitLogService(
          baseUrl: Uri.parse('http://localhost:8000'),
          client: client,
        );
        final result = await service.record(
          artifactId: 'artifact-1',
          beaconId: 'beacon-1',
          token: _token,
          rssi: -48,
        );
        expect(result.alreadyRecorded, status == 200);
        expect(result.visit.visitedAt, DateTime.utc(2026, 11, 1, 12));
        service.close();
        client.close();
      },
    );
  }

  test('simulation omits RSSI and unmeasured fields', () async {
    final client = MockClient((request) async {
      expect(jsonDecode(request.body), {
        'artifact_id': 'artifact-1',
        'beacon_id': 'beacon-1',
      });
      return http.Response(jsonEncode(_visit()), 201);
    });
    final service = VisitLogService(
      baseUrl: Uri.parse('http://localhost:8000'),
      client: client,
    );
    await service.record(
      artifactId: 'artifact-1',
      beaconId: 'beacon-1',
      token: _token,
    );
    client.close();
  });

  test('history parses the P2 envelope, UTF-8 and pagination', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/visits/me');
      expect(request.url.queryParameters, {
        'lang': 'vi',
        'skip': '20',
        'limit': '20',
      });
      expect(request.headers['Authorization'], 'Bearer visitor-token');
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'data': [
              {
                ..._visit(),
                'artifact': {
                  'code': 'HTTL-DOAN-MON',
                  'title': 'Đoan Môn',
                  'language_code': 'vi',
                },
              },
            ],
            'count': 21,
          }),
        ),
        200,
      );
    });
    final service = VisitLogService(
      baseUrl: Uri.parse('http://localhost:8000'),
      client: client,
    );
    final result = await service.history(token: _token, skip: 20);
    expect(result.entries.single.title, 'Đoan Môn');
    expect(result.count, 21);
    client.close();
  });

  test('missing token is rejected before making an HTTP request', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    final service = VisitLogService(
      baseUrl: Uri.parse('http://localhost:8000'),
      client: client,
    );
    await expectLater(
      service.history(
        token: const AuthToken(accessToken: '', tokenType: 'bearer'),
      ),
      throwsA(
        isA<VisitLogException>().having((e) => e.statusCode, 'status', 401),
      ),
    );
    expect(calls, 0);
    client.close();
  });

  for (final status in [401, 403, 404, 422, 500]) {
    test('HTTP $status becomes a VisitLog error', () async {
      final client = MockClient((_) async => http.Response('{}', status));
      final service = VisitLogService(
        baseUrl: Uri.parse('http://localhost:8000'),
        client: client,
      );
      await expectLater(
        service.history(token: _token),
        throwsA(
          isA<VisitLogException>().having(
            (e) => e.statusCode,
            'status',
            status,
          ),
        ),
      );
      client.close();
    });
  }

  test('invalid success response is not reported as recorded', () async {
    final client = MockClient((_) async => http.Response('not JSON', 201));
    final service = VisitLogService(
      baseUrl: Uri.parse('http://localhost:8000'),
      client: client,
    );
    await expectLater(
      service.record(artifactId: 'a', beaconId: 'b', token: _token),
      throwsA(isA<VisitLogException>()),
    );
    client.close();
  });
}
