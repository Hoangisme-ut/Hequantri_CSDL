import 'dart:async';

import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/beacon/beacon_content_service.dart';
import 'package:flutter_application_1/features/beacon/beacon_tools_page.dart';

const _uuid = '11111111-2222-3333-4444-555555555555';

const _token = AuthToken(accessToken: 'test-token', tokenType: 'bearer');

Beacon _beacon(int minor) {
  return Beacon(
    proximityUUID: _uuid,
    major: 1,
    minor: minor,
    rssi: -50,
    accuracy: 1.5,
  );
}

Future<void> _openScanner(
  WidgetTester tester,
  StreamController<List<Beacon>> source,
  _FakeBeaconService service, {
  required AuthToken? Function() readToken,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BeaconTestPage(
        readToken: readToken,
        languageCode: 'vi',
        contentService: service,
        beaconStream: source.stream,
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Bắt đầu quét'));
  await tester.pump();
}

Future<void> _emit(
  WidgetTester tester,
  StreamController<List<Beacon>> source,
  int minor,
) async {
  source.add([_beacon(minor)]);
  await tester.pump();
}

void main() {
  testWidgets('confirmed scan requests content and suppresses duplicates', (
    WidgetTester tester,
  ) async {
    final source = StreamController<List<Beacon>>.broadcast();
    final service = _FakeBeaconService();

    try {
      await _openScanner(tester, source, service, readToken: () => _token);

      await _emit(tester, source, 1);

      expect(service.requests.length, 1);
      expect(service.requests.first.uuid, _uuid);
      expect(service.requests.first.major, 1);
      expect(service.requests.first.minor, 1);
      expect(service.requests.first.languageCode, 'vi');
      expect(service.requests.first.token.accessToken, 'test-token');

      for (var index = 0; index < 4; index++) {
        await _emit(tester, source, 1);
      }

      expect(service.requests.length, 1);

      service.requests.first.complete();
      await tester.pump();

      expect(find.text('Nội dung beacon 1'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));

      await _emit(tester, source, 2);
      await _emit(tester, source, 2);

      expect(service.requests.length, 1);

      await _emit(tester, source, 2);

      expect(service.requests.length, 2);
      expect(service.requests.last.minor, 2);

      service.requests.last.complete();
      await tester.pump();

      expect(find.text('Nội dung beacon 2'), findsOneWidget);
      expect(find.text('Nội dung beacon 1'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await source.close();
      service.close();
    }
  });

  testWidgets('scan ignores stale content and waits before the next request', (
    WidgetTester tester,
  ) async {
    final source = StreamController<List<Beacon>>.broadcast();
    final service = _FakeBeaconService();

    try {
      await _openScanner(tester, source, service, readToken: () => _token);

      await _emit(tester, source, 1);

      await _emit(tester, source, 2);
      await _emit(tester, source, 2);
      await _emit(tester, source, 2);

      expect(service.requests.length, 1);

      service.requests.first.complete();
      await tester.pump();

      expect(find.text('Nội dung beacon 1'), findsNothing);
      expect(service.requests.length, 1);

      await tester.pump(const Duration(seconds: 3));

      expect(service.requests.length, 2);
      expect(service.requests.last.minor, 2);

      service.requests.last.complete();
      await tester.pump();

      expect(find.text('Nội dung beacon 2'), findsOneWidget);
      expect(find.text('Nội dung beacon 1'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await source.close();
      service.close();
    }
  });

  testWidgets('scan requires a token and retry reads the latest token', (
    WidgetTester tester,
  ) async {
    AuthToken? token;

    final source = StreamController<List<Beacon>>.broadcast();
    final service = _FakeBeaconService();

    try {
      await _openScanner(tester, source, service, readToken: () => token);

      await _emit(tester, source, 1);

      expect(service.requests, isEmpty);
      expect(
        find.text('Cần đăng nhập để tải nội dung beacon.'),
        findsOneWidget,
      );

      token = _token;

      final retry = find.text('Thử lại');
      await tester.ensureVisible(retry);
      await tester.pump();
      await tester.tap(retry);
      await tester.pump();

      expect(service.requests.length, 1);
      expect(service.requests.first.token.accessToken, 'test-token');

      service.requests.first.complete();
      await tester.pump();

      expect(find.text('Nội dung beacon 1'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await source.close();
      service.close();
    }
  });

  testWidgets(
    'stopping scan cancels detection and ignores unfinished content',
    (WidgetTester tester) async {
      final source = StreamController<List<Beacon>>.broadcast();
      final service = _FakeBeaconService();

      try {
        await _openScanner(tester, source, service, readToken: () => _token);

        await _emit(tester, source, 1);

        expect(service.requests.length, 1);

        final scanState = tester.state<BeaconTestPageState>(
          find.byType(BeaconTestPage),
        );

        expect(scanState.isBusy, isFalse);
        expect(source.hasListener, isTrue);

        final stopped = await tester.runAsync<bool>(
          () => scanState.stopScanningIfNeeded().timeout(
            const Duration(seconds: 5),
          ),
        );

        await tester.pumpAndSettle();

        expect(stopped, isTrue, reason: 'Stopping the scan must succeed.');
        expect(scanState.isBusy, isFalse);
        expect(source.hasListener, isFalse);

        final statusTexts = tester
            .widgetList<Text>(find.byType(Text, skipOffstage: false))
            .map((widget) => widget.data ?? '')
            .where((text) => text.contains('quét') || text.contains('Luồng'))
            .join(' | ');

        expect(
          find.textContaining('Đã dừng quét', skipOffstage: false),
          findsOneWidget,
          reason: 'Scan status after stopping: $statusTexts',
        );

        service.requests.first.complete();
        await tester.pump();

        expect(find.text('Nội dung beacon 1'), findsNothing);

        await _emit(tester, source, 2);
        await tester.pump(const Duration(seconds: 3));

        expect(service.requests.length, 1);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await source.close();
        service.close();
      }
    },
  );
}

class _FakeBeaconService extends BeaconContentService {
  _FakeBeaconService() : super(baseUrl: Uri.parse('https://example.test'));

  final List<_PendingRequest> requests = [];

  @override
  Future<BeaconContent> resolve({
    required String proximityUuid,
    required int major,
    required int minor,
    required AuthToken token,
    String? languageCode,
  }) {
    final request = _PendingRequest(
      uuid: proximityUuid,
      major: major,
      minor: minor,
      token: token,
      languageCode: languageCode,
    );

    requests.add(request);
    return request.completer.future;
  }
}

class _PendingRequest {
  _PendingRequest({
    required this.uuid,
    required this.major,
    required this.minor,
    required this.token,
    this.languageCode,
  });

  final String uuid;
  final int major;
  final int minor;
  final AuthToken token;
  final String? languageCode;

  final completer = Completer<BeaconContent>();

  void complete() {
    completer.complete(
      BeaconContent(
        beaconId: 'beacon-$minor',
        artifactId: 'artifact-$minor',
        siteId: 'test-site',
        code: 'ART-$minor',
        title: 'Nội dung beacon $minor',
        description: 'Nội dung kiểm thử từ API giả lập.',
        languageCode: languageCode,
      ),
    );
  }
}
