import 'dart:async';

import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/beacon/beacon_content_service.dart';
import 'package:flutter_application_1/features/beacon/beacon_tools_page.dart';
import 'package:flutter_application_1/features/visits/visit_log_service.dart';
import 'package:flutter_application_1/l10n/app_strings.dart';

const _uuid = '11111111-2222-3333-4444-555555555555';

const _token = AuthToken(accessToken: 'test-token', tokenType: 'bearer');

final _now = DateTime.utc(2026, 11, 6);

String _artifactId(int minor) =>
    '20000000-0000-0000-0000-${minor.toString().padLeft(12, '0')}';

String _beaconId(int minor) =>
    '30000000-0000-0000-0000-${minor.toString().padLeft(12, '0')}';

Map<String, dynamic> _payload(int? threshold) => {
  'beacon': {
    'id': _beaconId(1),
    'site_id': '10000000-0000-0000-0000-000000000001',
    'artifact_id': _artifactId(1),
    'proximity_uuid': _uuid,
    'major': 1,
    'minor': 1,
    'rssi_threshold': threshold,
  },
  'artifact': {
    'id': _artifactId(1),
    'site_id': '10000000-0000-0000-0000-000000000001',
    'code': 'ART-1',
    'title': 'Nội dung beacon 1',
    'language_code': 'vi',
    'media': <dynamic>[],
  },
};

class _PendingRequest {
  _PendingRequest(this.minor);

  final int minor;
  final completer = Completer<BeaconContent>();

  void complete() {
    completer.complete(
      BeaconContent(
        beaconId: _beaconId(minor),
        artifactId: _artifactId(minor),
        siteId: '10000000-0000-0000-0000-000000000001',
        code: 'ART-$minor',
        title: 'Nội dung beacon $minor',
        description: 'Nội dung kiểm thử.',
        languageCode: 'vi',
        rssiThreshold: -70,
      ),
    );
  }
}

class _FakeService extends BeaconContentService {
  _FakeService() : super(baseUrl: Uri.parse('https://backend.test'));

  final requests = <_PendingRequest>[];

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

class _FakeVisits extends VisitLogService {
  _FakeVisits() : super(baseUrl: Uri.parse('https://backend.test'));

  final artifactIds = <String>[];
  final readings = <int?>[];

  @override
  Future<VisitRecordResult> record({
    required String artifactId,
    required String beaconId,
    required AuthToken token,
    int? rssi,
  }) async {
    artifactIds.add(artifactId);
    readings.add(rssi);

    return VisitRecordResult(
      visit: VisitRecord(
        id: '80000000-0000-0000-0000-000000000001',
        artifactId: artifactId,
        beaconId: beaconId,
        visitedAt: _now,
      ),
      alreadyRecorded: false,
    );
  }
}

class _Harness {
  final source = StreamController<List<Beacon>>.broadcast();
  final service = _FakeService();
  final visits = _FakeVisits();

  Future<void> emit(
    WidgetTester tester, {
    int minor = 1,
    required int rssi,
  }) async {
    source.add([
      Beacon(
        proximityUUID: _uuid,
        major: 1,
        minor: minor,
        rssi: rssi,
        accuracy: 1.5,
      ),
    ]);

    await tester.pump();
  }

  Future<void> completeLatest(WidgetTester tester) async {
    service.requests.last.complete();
    await tester.pump();
    await tester.pump();
  }
}

Future<void> _withScanner(
  WidgetTester tester,
  Future<void> Function(_Harness harness) body,
) async {
  final harness = _Harness();

  try {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: BeaconTestPage(
          readToken: () => _token,
          languageCode: 'vi',
          contentService: harness.service,
          visitLogService: harness.visits,
          beaconStream: harness.source.stream,
          clock: () => _now,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu quét'));
    await tester.pump();

    await body(harness);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await harness.source.close();
    harness.service.close();
    harness.visits.close();
  }
}

void main() {
  test('parses backend threshold and accepts the exact boundary', () {
    final content = BeaconContent.fromJson(_payload(-70));

    expect(content.rssiThreshold, -70);
    expect(content.acceptsRssi(-50), isTrue);
    expect(content.acceptsRssi(-70), isTrue);
    expect(content.acceptsRssi(-71), isFalse);
    expect(content.acceptsRssi(0), isFalse);
    expect(content.acceptsRssi(10), isFalse);
  });

  test('null threshold still rejects invalid nonnegative RSSI', () {
    final content = BeaconContent.fromJson(_payload(null));

    expect(content.rssiThreshold, isNull);
    expect(content.acceptsRssi(-90), isTrue);
    expect(content.acceptsRssi(0), isFalse);
  });

  testWidgets(
    'weak packets learn the threshold once and do not display or log content',
    (tester) async {
      await _withScanner(tester, (harness) async {
        await harness.emit(tester, rssi: -90);

        expect(harness.service.requests, hasLength(1));

        await harness.completeLatest(tester);

        expect(find.text('Nội dung beacon 1'), findsNothing);
        expect(harness.visits.artifactIds, isEmpty);

        for (var i = 0; i < 4; i++) {
          await harness.emit(tester, rssi: -90);
        }

        expect(harness.service.requests, hasLength(1));

        await tester.pump(const Duration(seconds: 3));
        await harness.emit(tester, rssi: -70);

        expect(harness.service.requests, hasLength(2));

        await harness.completeLatest(tester);

        expect(find.text('Nội dung beacon 1'), findsOneWidget);
        expect(harness.visits.artifactIds, isEmpty);
        expect(harness.visits.readings, isEmpty);
      });
    },
  );

  testWidgets(
    'a weaker reading arriving during resolve prevents content activation',
    (tester) async {
      await _withScanner(tester, (harness) async {
        await harness.emit(tester, rssi: -50);

        expect(harness.service.requests, hasLength(1));

        // API vẫn đang chờ, nhưng tín hiệu đã yếu đi.
        await harness.emit(tester, rssi: -90);
        await harness.completeLatest(tester);

        expect(find.text('Nội dung beacon 1'), findsNothing);
        expect(harness.visits.artifactIds, isEmpty);
      });
    },
  );

  testWidgets(
    'switching from A to B requires three consecutive confirmations',
    (tester) async {
      await _withScanner(tester, (harness) async {
        await harness.emit(tester, minor: 1, rssi: -50);
        await harness.completeLatest(tester);

        expect(find.text('Nội dung beacon 1'), findsOneWidget);

        await harness.emit(tester, minor: 2, rssi: -45);
        await harness.emit(tester, minor: 2, rssi: -45);

        expect(harness.service.requests, hasLength(1));
        expect(find.text('Nội dung beacon 1'), findsOneWidget);

        await harness.emit(tester, minor: 2, rssi: -45);
        await tester.pump(const Duration(seconds: 3));

        expect(harness.service.requests, hasLength(2));
        expect(harness.service.requests.last.minor, 2);

        await harness.completeLatest(tester);

        expect(find.text('Nội dung beacon 1'), findsNothing);
        expect(find.text('Nội dung beacon 2'), findsOneWidget);
        expect(harness.visits.artifactIds, isEmpty);
      });
    },
  );

  testWidgets(
    'weak readings do not renew selection and reentry previews do not record visits',
    (tester) async {
      await _withScanner(tester, (harness) async {
        await harness.emit(tester, rssi: -55);
        await harness.completeLatest(tester);

        expect(harness.visits.artifactIds, isEmpty);

        await tester.pump(const Duration(seconds: 6));
        await harness.emit(tester, rssi: -90);

        // Đã hơn 10 giây kể từ tín hiệu đủ ngưỡng cuối cùng.
        await tester.pump(const Duration(seconds: 5));

        expect(find.text('Nội dung beacon 1'), findsNothing);

        // Vào lại vùng: tải lại nội dung.
        await harness.emit(tester, rssi: -55);

        expect(harness.service.requests, hasLength(2));

        await harness.completeLatest(tester);

        expect(find.text('Nội dung beacon 1'), findsOneWidget);

        // A preview/reentry is not an explicit artifact-open action.
        expect(harness.visits.artifactIds, isEmpty);
      });
    },
  );
}
