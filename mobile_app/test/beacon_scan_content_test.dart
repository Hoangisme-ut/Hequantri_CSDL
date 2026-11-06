import 'dart:async';

import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/beacon/beacon_content_service.dart';
import 'package:flutter_application_1/features/beacon/beacon_tools_page.dart';
import 'package:flutter_application_1/features/visits/visit_log_service.dart';
import 'package:flutter_application_1/features/beacon/visit_deduplicator.dart';
import 'package:flutter_application_1/l10n/app_strings.dart';

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
  VisitLogService? visitLogService,
  DateTime Function()? clock,
  bool isActive = true,
  String languageCode = 'vi',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(languageCode),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: BeaconTestPage(
        readToken: readToken,
        languageCode: languageCode,
        isActive: isActive,
        contentService: service,
        visitLogService: visitLogService,
        beaconStream: source.stream,
        clock: clock,
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(
    find.text(languageCode == 'en' ? 'Start scanning' : 'Bắt đầu quét'),
  );
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
  testWidgets('scanner labels use the selected English locale', (tester) async {
    final source = StreamController<List<Beacon>>();
    await _openScanner(
      tester,
      source,
      _FakeBeaconService(),
      readToken: () => _token,
      languageCode: 'en',
    );

    expect(find.text('Beacon Guide'), findsOneWidget);
    expect(
      find.text('Scanning — waiting for an iBeacon signal'),
      findsOneWidget,
    );
    expect(find.text('Stop scanning'), findsOneWidget);
    expect(find.text('Heritage guide'), findsOneWidget);

    await source.close();
  });

  test('visit deduplication follows the backend 300-second window', () {
    var now = DateTime.utc(2026, 11, 1);
    final deduplicator = VisitDeduplicator(clock: () => now);

    final initial = deduplicator.reserve('artifact-uuid');
    expect(initial, isNotNull);
    expect(deduplicator.reserve('artifact-uuid'), isNull);
    deduplicator.complete(
      initial!,
      succeeded: true,
      visitedAt: now,
      wasCreated: true,
    );

    // Repeated signals, a locale re-resolve, and stop/rescan preserve the
    // same artifact key for this page/session.
    now = now.add(const Duration(seconds: 300));
    expect(deduplicator.reserve('artifact-uuid'), isNull);

    now = now.add(const Duration(seconds: 1));
    final afterWindow = deduplicator.reserve('artifact-uuid');
    expect(afterWindow, isNotNull);
    deduplicator.complete(
      afterWindow!,
      succeeded: true,
      visitedAt: now,
      wasCreated: true,
    );
  });

  test(
    'duplicate response anchors dedup to backend visit time after reopen',
    () {
      final backendVisitAt = DateTime.utc(2026, 11, 1);
      var now = backendVisitAt.add(const Duration(seconds: 299));
      final reopenedPageDeduplicator = VisitDeduplicator(clock: () => now);

      final retry = reopenedPageDeduplicator.reserve('artifact-uuid');
      expect(retry, isNotNull);
      reopenedPageDeduplicator.complete(
        retry!,
        succeeded: true,
        visitedAt: backendVisitAt,
        wasCreated: false,
      );

      now = backendVisitAt.add(const Duration(seconds: 301));
      expect(reopenedPageDeduplicator.reserve('artifact-uuid'), isNotNull);
    },
  );

  test('failed and stale visit completions cannot block a retry', () {
    var now = DateTime.utc(2026, 11, 1);
    final deduplicator = VisitDeduplicator(clock: () => now);
    final failedAttempt = deduplicator.reserve('artifact-uuid')!;

    deduplicator.complete(failedAttempt, succeeded: false);
    final retry = deduplicator.reserve('artifact-uuid')!;
    deduplicator.complete(failedAttempt, succeeded: true);

    expect(deduplicator.reserve('artifact-uuid'), isNull);
    deduplicator.complete(retry, succeeded: false);
    expect(deduplicator.reserve('artifact-uuid'), isNotNull);
  });

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

  testWidgets(
    'records a visit once after content is resolved, not per BLE signal',
    (WidgetTester tester) async {
      var now = DateTime.utc(2026, 11, 1);
      final source = StreamController<List<Beacon>>.broadcast();
      final service = _FakeBeaconService();
      final visitorApi = _FakeVisits();
      try {
        await _openScanner(
          tester,
          source,
          service,
          readToken: () => _token,
          visitLogService: visitorApi,
          clock: () => now,
        );
        await _emit(tester, source, 1);
        expect(visitorApi.visits, isEmpty);

        service.requests.single.complete();
        await tester.pump();
        await tester.pump();
        expect(visitorApi.visits, hasLength(1));

        for (var index = 0; index < 5; index++) {
          await _emit(tester, source, 1);
        }
        await tester.pump();
        expect(visitorApi.visits, hasLength(1));

        // A locale-triggered re-resolve remains in the same backend window.
        await tester.pumpWidget(
          MaterialApp(
            home: BeaconTestPage(
              readToken: () => _token,
              languageCode: 'en',
              contentService: service,
              visitLogService: visitorApi,
              beaconStream: source.stream,
              clock: () => now,
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 3));
        expect(service.requests, hasLength(2));
        service.requests.last.complete();
        await tester.pump();
        await tester.pump();
        expect(visitorApi.visits, hasLength(1));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await source.close();
        service.close();
      }
    },
  );

  testWidgets('does not record content resolved with a replaced session', (
    tester,
  ) async {
    AuthToken? token = _token;
    final source = StreamController<List<Beacon>>.broadcast();
    final service = _FakeBeaconService();
    final visitorApi = _FakeVisits();
    try {
      await _openScanner(
        tester,
        source,
        service,
        readToken: () => token,
        visitLogService: visitorApi,
      );
      await _emit(tester, source, 1);
      token = const AuthToken(
        accessToken: 'replacement-session',
        tokenType: 'bearer',
      );
      service.requests.single.complete();
      await tester.pumpAndSettle();

      expect(visitorApi.calls, 0);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await source.close();
      service.close();
    }
  });

  testWidgets('beacon selection change discards the older resolve result', (
    tester,
  ) async {
    final source = StreamController<List<Beacon>>.broadcast();
    final service = _FakeBeaconService();
    final visitorApi = _FakeVisits();
    try {
      await _openScanner(
        tester,
        source,
        service,
        readToken: () => _token,
        visitLogService: visitorApi,
        clock: () => DateTime.utc(2026, 11, 1),
      );
      await _emit(tester, source, 1);
      for (var i = 0; i < 3; i++) {
        await _emit(tester, source, 2);
      }

      service.requests.first.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(service.requests, hasLength(2));
      expect(visitorApi.calls, 0);

      service.requests.last.complete();
      // A scanner page has an active stream and snackbar animations, so
      // pump the resolve/render/post-frame sequence explicitly.
      await tester.pump();
      await tester.pump();
      expect(visitorApi.visits, hasLength(1));
      expect(visitorApi.visits.single, endsWith(':beacon-2:-50'));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await source.close();
      service.close();
    }
  });

  testWidgets('inactive beacon tab waits until its content panel is visible', (
    tester,
  ) async {
    final source = StreamController<List<Beacon>>.broadcast();
    final service = _FakeBeaconService();
    final visitorApi = _FakeVisits();
    try {
      await _openScanner(
        tester,
        source,
        service,
        readToken: () => _token,
        visitLogService: visitorApi,
        isActive: false,
      );
      await _emit(tester, source, 1);
      service.requests.single.complete();
      await tester.pumpAndSettle();
      expect(visitorApi.calls, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: BeaconTestPage(
            readToken: () => _token,
            contentService: service,
            visitLogService: visitorApi,
            beaconStream: source.stream,
            isActive: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(visitorApi.calls, 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await source.close();
      service.close();
    }
  });

  testWidgets('covered beacon route records only after it is visible again', (
    tester,
  ) async {
    final source = StreamController<List<Beacon>>.broadcast();
    final service = _FakeBeaconService();
    final visitorApi = _FakeVisits();
    final navigatorKey = GlobalKey<NavigatorState>();
    try {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: BeaconTestPage(
            readToken: () => _token,
            contentService: service,
            visitLogService: visitorApi,
            beaconStream: source.stream,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bắt đầu quét'));
      await tester.pump();
      await _emit(tester, source, 1);
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Cover route')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      service.requests.single.complete();
      await tester.pump();
      await tester.pump();
      expect(visitorApi.calls, 0);

      navigatorKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(visitorApi.calls, 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await source.close();
      service.close();
    }
  });

  testWidgets('disposed scanner ignores a late resolve callback', (
    tester,
  ) async {
    final source = StreamController<List<Beacon>>.broadcast();
    final service = _FakeBeaconService();
    final visitorApi = _FakeVisits();
    try {
      await _openScanner(
        tester,
        source,
        service,
        readToken: () => _token,
        visitLogService: visitorApi,
      );
      await _emit(tester, source, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      service.requests.single.complete();
      await tester.pump();

      expect(visitorApi.calls, 0);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await source.close();
      service.close();
    }
  });

  testWidgets('only one Visit request can be in flight for displayed content', (
    tester,
  ) async {
    final source = StreamController<List<Beacon>>.broadcast();
    final service = _FakeBeaconService();
    final visitorApi = _FakeVisits()..pending = Completer<VisitRecordResult>();
    try {
      await _openScanner(
        tester,
        source,
        service,
        readToken: () => _token,
        visitLogService: visitorApi,
      );
      await _emit(tester, source, 1);
      service.requests.single.complete();
      await tester.pumpAndSettle();
      expect(visitorApi.calls, 1);

      for (var i = 0; i < 4; i++) {
        await _emit(tester, source, 1);
      }
      await tester.pumpAndSettle();
      expect(visitorApi.calls, 1);

      visitorApi.pending!.complete(_visitReceipt());
      await tester.pumpAndSettle();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await source.close();
      service.close();
    }
  });

  testWidgets('failed Visit request can be retried from the visible panel', (
    tester,
  ) async {
    final source = StreamController<List<Beacon>>.broadcast();
    final service = _FakeBeaconService();
    final visitorApi = _FakeVisits()..failNext = true;
    try {
      await _openScanner(
        tester,
        source,
        service,
        readToken: () => _token,
        visitLogService: visitorApi,
      );
      await _emit(tester, source, 1);
      service.requests.single.complete();
      await tester.pumpAndSettle();
      expect(visitorApi.calls, 1);
      expect(
        find.text('Không thể kết nối máy chủ. Vui lòng thử lại.'),
        findsOneWidget,
      );

      final retryButton = find.byType(TextButton);
      await tester.ensureVisible(retryButton);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(retryButton);
      await tester.pump();
      await tester.pump();
      expect(visitorApi.calls, 2);
      expect(visitorApi.visits, hasLength(1));
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
    final visitorApi = _FakeVisits();

    try {
      await _openScanner(
        tester,
        source,
        service,
        readToken: () => token,
        visitLogService: visitorApi,
      );

      await _emit(tester, source, 1);

      expect(service.requests, isEmpty);
      expect(visitorApi.visits, isEmpty);
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
      final visitorApi = _FakeVisits();

      try {
        await _openScanner(
          tester,
          source,
          service,
          readToken: () => _token,
          visitLogService: visitorApi,
        );

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
        artifactId:
            '70000000-0000-0000-0000-${minor.toString().padLeft(12, '0')}',
        siteId: 'test-site',
        code: 'ART-$minor',
        title: 'Nội dung beacon $minor',
        description: 'Nội dung kiểm thử từ API giả lập.',
        languageCode: languageCode,
      ),
    );
  }
}

class _FakeVisits extends VisitLogService {
  _FakeVisits() : super(baseUrl: Uri.parse('http://localhost:8000'));

  final List<String> visits = [];
  int calls = 0;
  bool failNext = false;
  Completer<VisitRecordResult>? pending;

  @override
  Future<VisitRecordResult> record({
    required String artifactId,
    required String beaconId,
    required AuthToken token,
    int? rssi,
  }) async {
    calls++;
    if (failNext) {
      failNext = false;
      throw const VisitLogException('simulated failure');
    }

    final receipt = pending == null ? _visitReceipt() : await pending!.future;
    visits.add('$artifactId:$beaconId:$rssi');
    return receipt;
  }
}

VisitRecordResult _visitReceipt() => VisitRecordResult(
  visit: VisitRecord(
    id: '80000000-0000-0000-0000-000000000001',
    artifactId: '70000000-0000-0000-0000-000000000001',
    visitedAt: DateTime.utc(2026, 11, 1),
  ),
  alreadyRecorded: false,
);
