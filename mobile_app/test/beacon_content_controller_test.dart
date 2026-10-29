import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/beacon/beacon_content_controller.dart';
import 'package:flutter_application_1/features/beacon/beacon_content_service.dart';

const _uuid = '11111111-2222-3333-4444-555555555555';

const _token = AuthToken(accessToken: 'test-token', tokenType: 'bearer');

void main() {
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

/// Thay API thật bằng các phản hồi do bài kiểm thử điều khiển.
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
