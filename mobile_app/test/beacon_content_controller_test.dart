import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/beacon/beacon_content_controller.dart';
import 'package:flutter_application_1/features/beacon/beacon_content_service.dart';

const _uuid = '11111111-2222-3333-4444-555555555555';

const _token = AuthToken(accessToken: 'test-token', tokenType: 'bearer');

void main() {
  test('Beacon resolve validates required and optional UUID fields', () {
    final valid = _beaconResolvePayload();
    final parsed = BeaconContent.fromJson(valid);
    expect(parsed.beaconId, '30000000-0000-0000-0000-000000000001');
    expect(parsed.artifactId, '20000000-0000-0000-0000-000000000001');

    final invalidBeaconId = _beaconResolvePayload()
      ..['beacon'] = {
        ..._beaconResolvePayload()['beacon'] as Map<String, dynamic>,
        'id': 'beacon-1',
      };
    expect(
      () => BeaconContent.fromJson(invalidBeaconId),
      throwsFormatException,
    );

    final invalidOptionalBeaconArtifact = _beaconResolvePayload()
      ..['beacon'] = {
        ..._beaconResolvePayload()['beacon'] as Map<String, dynamic>,
        'artifact_id': 'artifact-1',
      };
    expect(
      () => BeaconContent.fromJson(invalidOptionalBeaconArtifact),
      throwsFormatException,
    );

    final invalidOptionalMediaLanguage = _beaconResolvePayload()
      ..['artifact'] = {
        ..._beaconResolvePayload()['artifact'] as Map<String, dynamic>,
        'media': [
          {
            'id': '40000000-0000-0000-0000-000000000001',
            'artifact_id': '20000000-0000-0000-0000-000000000001',
            'language_id': 'language-1',
            'media_type': 'image',
            'url': 'https://example.test/image.jpg',
          },
        ],
      };
    expect(
      () => BeaconContent.fromJson(invalidOptionalMediaLanguage),
      throwsFormatException,
    );
  });

  testWidgets('Repeated beacon only requests content once', (tester) async {
    final service = _FakeBeaconService();
    final controller = BeaconContentController(
      service: service,
      readToken: () => _token,
    );

    try {
      void receiveA() {
        controller.receiveBeacon(proximityUuid: _uuid, major: 1, minor: 1);
      }

      receiveA();
      receiveA();
      receiveA();

      expect(service.requests.length, 1);
      expect(controller.isLoading, isTrue);

      service.requests.first.complete();
      await tester.pump();

      expect(controller.content?.code, 'ART-1');
      expect(controller.contentToken?.accessToken, 'test-token');
      expect(controller.isLoading, isFalse);

      await tester.pump(const Duration(seconds: 3));
      receiveA();

      expect(service.requests.length, 1);
      expect(controller.requestCount, 1);
    } finally {
      controller.dispose();
      service.close();
    }
  });

  testWidgets(
    'Switching beacon ignores old content and requests latest beacon',
    (tester) async {
      final service = _FakeBeaconService();
      final controller = BeaconContentController(
        service: service,
        readToken: () => _token,
      );

      try {
        void receive(int minor) {
          controller.receiveBeacon(
            proximityUuid: _uuid,
            major: 1,
            minor: minor,
          );
        }

        receive(1);
        receive(2);
        receive(3);

        // A đang tải; B rồi C đến sau chưa tạo thêm request.
        expect(service.requests.length, 1);

        await tester.pump(const Duration(seconds: 2));

        service.requests.first.complete();
        await tester.pump();

        // Đã chọn C nên không hiển thị kết quả của A.
        expect(controller.content, isNull);
        expect(controller.isLoading, isTrue);
        expect(service.requests.length, 1);

        await tester.pump(const Duration(seconds: 1));

        // Đủ 3 giây: chỉ gọi beacon mới nhất là C.
        expect(service.requests.length, 2);
        expect(service.requests.last.minor, 3);

        service.requests.last.complete();
        await tester.pump();

        expect(controller.content?.code, 'ART-3');
        expect(controller.isLoading, isFalse);
        expect(controller.requestCount, 2);
      } finally {
        controller.dispose();
        service.close();
      }
    },
  );

  testWidgets('Missing token blocks request and allows retry', (tester) async {
    AuthToken? token;

    final service = _FakeBeaconService();
    final controller = BeaconContentController(
      service: service,
      readToken: () => token,
    );

    try {
      controller.receiveBeacon(proximityUuid: _uuid, major: 1, minor: 1);

      await tester.pump();

      expect(service.requests, isEmpty);
      expect(controller.requestCount, 0);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, 'Cần đăng nhập để tải nội dung beacon.');

      // Giả lập phần đăng nhập đã cung cấp token.
      token = _token;
      controller.retry();

      expect(service.requests.length, 1);

      service.requests.first.complete();
      await tester.pump();

      expect(controller.content?.code, 'ART-1');
      expect(controller.errorMessage, isNull);
    } finally {
      controller.dispose();
      service.close();
    }
  });

  testWidgets('Reset ignores content from an unfinished request', (
    tester,
  ) async {
    final service = _FakeBeaconService();
    final controller = BeaconContentController(
      service: service,
      readToken: () => _token,
    );

    try {
      controller.receiveBeacon(proximityUuid: _uuid, major: 1, minor: 1);

      controller.reset();

      service.requests.first.complete();
      await tester.pump();

      expect(controller.content, isNull);
      expect(controller.currentBeaconKey, isNull);
      expect(controller.errorMessage, isNull);
      expect(controller.isLoading, isFalse);
    } finally {
      controller.dispose();
      service.close();
    }
  });
}

Map<String, dynamic> _beaconResolvePayload() => {
  'beacon': {
    'id': '30000000-0000-0000-0000-000000000001',
    'site_id': '10000000-0000-0000-0000-000000000001',
    'artifact_id': '20000000-0000-0000-0000-000000000001',
    'proximity_uuid': _uuid,
    'major': 1,
    'minor': 1,
    'is_active': true,
  },
  'artifact': {
    'id': '20000000-0000-0000-0000-000000000001',
    'site_id': '10000000-0000-0000-0000-000000000001',
    'code': 'ART-1',
    'era': null,
    'latitude': null,
    'longitude': null,
    'cover_image_url': null,
    'is_active': true,
    'title': 'Artifact',
    'description': null,
    'history_content': null,
    'language_code': 'vi',
    'is_fallback': false,
    'media': const <Object>[],
  },
};

/// Provides controlled API responses for controller tests.
class _FakeBeaconService extends BeaconContentService {
  _FakeBeaconService() : super(baseUrl: Uri.parse('https://example.com'));

  final List<_PendingRequest> requests = [];

  @override
  Future<BeaconContent> resolve({
    required String proximityUuid,
    required int major,
    required int minor,
    required AuthToken token,
    String? languageCode,
  }) {
    final request = _PendingRequest(minor);
    requests.add(request);
    return request.completer.future;
  }
}

class _PendingRequest {
  _PendingRequest(this.minor);

  final int minor;
  final Completer<BeaconContent> completer = Completer<BeaconContent>();

  void complete() {
    completer.complete(
      BeaconContent(
        beaconId: 'beacon-$minor',
        artifactId: 'artifact-$minor',
        siteId: 'test-site',
        code: 'ART-$minor',
        title: 'Nội dung beacon $minor',
      ),
    );
  }
}
