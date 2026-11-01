import 'dart:async';

import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/beacon/beacon_content_controller.dart';
import 'package:flutter_application_1/features/beacon/beacon_content_panel.dart';
import 'package:flutter_application_1/features/beacon/beacon_content_service.dart';
import 'package:flutter_application_1/features/beacon/beacon_tools_page.dart';
import 'package:flutter_application_1/features/visits/visit_log_service.dart';
import 'package:flutter_application_1/beacon_simulation_page.dart';

const _token = AuthToken(accessToken: 'visitor-token', tokenType: 'bearer');
const _uuid = 'FDA50693-A4E2-4FB1-AFCF-C6EB07647825';
BeaconContent _content(int minor) => BeaconContent(
  beaconId: 'beacon-$minor',
  artifactId: 'artifact-$minor',
  siteId: 'site-1',
  code: 'ART-$minor',
  title: 'Nội dung $minor',
);

class _Contents extends BeaconContentService {
  _Contents() : super(baseUrl: Uri.parse('http://localhost:8000'));
  final List<Completer<BeaconContent>> pending = [];

  @override
  Future<BeaconContent> resolve({
    required String proximityUuid,
    required int major,
    required int minor,
    required AuthToken token,
    String? languageCode,
  }) {
    final request = Completer<BeaconContent>();
    pending.add(request);
    return request.future;
  }
}

class _Visits extends VisitLogService {
  _Visits() : super(baseUrl: Uri.parse('http://localhost:8000'));
  final List<String> artifacts = [];
  final List<int?> signals = [];
  bool fail = false;
  Completer<VisitRecordResult>? pending;

  @override
  Future<VisitRecordResult> record({
    required String artifactId,
    required String beaconId,
    required AuthToken token,
    int? rssi,
  }) async {
    artifacts.add(artifactId);
    signals.add(rssi);
    if (fail) throw const VisitLogException('Không lưu được lượt xem.');
    if (pending != null) return pending!.future;
    return VisitRecordResult(
      visit: VisitRecord(
        id: 'visit-${artifacts.length}',
        artifactId: artifactId,
      ),
      alreadyRecorded: false,
    );
  }
}

void _receive(BeaconContentController c, int minor, {String lang = 'vi'}) =>
    c.receiveBeacon(
      proximityUuid: _uuid,
      major: 1,
      minor: minor,
      languageCode: lang,
    );

void main() {
  testWidgets('resolution alone never logs; a displayed selection logs once', (
    tester,
  ) async {
    final contents = _Contents();
    final visits = _Visits();
    final c = BeaconContentController(
      service: contents,
      visitLogService: visits,
      readToken: () => _token,
      minRequestInterval: Duration.zero,
    );
    // Drain zero-duration cooldown timers explicitly in Flutter's fake clock.
    // Dispose before the widget-test invariant checks, including on failure.
    try {
      _receive(c, 1);
      contents.pending.single.complete(_content(1));
      await tester.pump(Duration.zero);
      expect(visits.artifacts, isEmpty);
      await c.recordDisplayedContent(c.content!, rssi: -50);
      await c.recordDisplayedContent(c.content!, rssi: -49);
      _receive(c, 1);
      expect(visits.artifacts, ['artifact-1']);
      expect(visits.signals, [-50]);
    } finally {
      c.dispose();
      contents.close();
      visits.close();
    }
  });

  testWidgets(
    'language changes and content retry do not create another visit',
    (tester) async {
      final contents = _Contents();
      final visits = _Visits();
      final c = BeaconContentController(
        service: contents,
        visitLogService: visits,
        readToken: () => _token,
        minRequestInterval: Duration.zero,
      );
      // Drain zero-duration cooldown timers explicitly in Flutter's fake clock.
      // Dispose before the widget-test invariant checks, including on failure.
      try {
        _receive(c, 1);
        contents.pending.last.complete(_content(1));
        await tester.pump(Duration.zero);
        await c.recordDisplayedContent(c.content!);
        _receive(c, 1, lang: 'en');
        await tester.pump(Duration.zero);
        expect(contents.pending.length, 2);
        contents.pending.last.complete(_content(1));
        await tester.pump(Duration.zero);
        await c.recordDisplayedContent(c.content!);
        c.retry();
        await tester.pump(Duration.zero);
        expect(contents.pending.length, 3);
        contents.pending.last.complete(_content(1));
        await tester.pump(Duration.zero);
        await c.recordDisplayedContent(c.content!);
        expect(visits.artifacts, ['artifact-1']);
      } finally {
        c.dispose();
        contents.close();
        visits.close();
      }
    },
  );

  testWidgets('stale resolve and stopped selections never log', (tester) async {
    final contents = _Contents();
    final visits = _Visits();
    final c = BeaconContentController(
      service: contents,
      visitLogService: visits,
      readToken: () => _token,
      minRequestInterval: Duration.zero,
    );
    // Drain zero-duration cooldown timers explicitly in Flutter's fake clock.
    // Dispose before the widget-test invariant checks, including on failure.
    try {
      _receive(c, 1);
      _receive(c, 2);
      final stale = _content(1);
      contents.pending.first.complete(stale);
      await tester.pump(Duration.zero);
      expect(contents.pending.length, 2);
      await c.recordDisplayedContent(stale);
      expect(visits.artifacts, isEmpty);
      c.reset();
      contents.pending.last.complete(_content(2));
      await tester.pump(Duration.zero);
      expect(c.content, isNull);
      await c.recordDisplayedContent(_content(2));
      expect(visits.artifacts, isEmpty);
    } finally {
      c.dispose();
      contents.close();
      visits.close();
    }
  });

  testWidgets('visit failure keeps content and requires explicit retry', (
    tester,
  ) async {
    final contents = _Contents();
    final visits = _Visits()..fail = true;
    final c = BeaconContentController(
      service: contents,
      visitLogService: visits,
      readToken: () => _token,
      minRequestInterval: Duration.zero,
    );
    // Drain zero-duration cooldown timers explicitly in Flutter's fake clock.
    // Dispose before the widget-test invariant checks, including on failure.
    try {
      _receive(c, 1);
      contents.pending.single.complete(_content(1));
      await tester.pump(Duration.zero);
      final displayed = c.content!;
      await c.recordDisplayedContent(displayed);
      await c.recordDisplayedContent(displayed);
      expect(visits.artifacts.length, 1);
      expect(c.content, same(displayed));
      expect(c.visitError, isNotNull);
      visits.fail = false;
      c.retryVisitLog();
      await tester.pump(Duration.zero);
      expect(visits.artifacts.length, 2);
      expect(c.visitError, isNull);
      expect(c.visitResult, isNotNull);
    } finally {
      c.dispose();
      contents.close();
      visits.close();
    }
  });

  testWidgets(
    'in-flight duplicates are blocked and reset ignores a late visit response',
    (tester) async {
      final contents = _Contents();
      final visits = _Visits()..pending = Completer<VisitRecordResult>();
      final c = BeaconContentController(
        service: contents,
        visitLogService: visits,
        readToken: () => _token,
        minRequestInterval: Duration.zero,
      );
      // Drain zero-duration cooldown timers explicitly in Flutter's fake clock.
      // Dispose before the widget-test invariant checks, including on failure.
      try {
        _receive(c, 1);
        contents.pending.single.complete(_content(1));
        await tester.pump(Duration.zero);
        final future = c.recordDisplayedContent(c.content!);
        await c.recordDisplayedContent(c.content!);
        expect(visits.artifacts.length, 1);
        c.reset();
        visits.pending!.complete(
          const VisitRecordResult(
            visit: VisitRecord(id: 'v', artifactId: 'artifact-1'),
            alreadyRecorded: true,
          ),
        );
        await future;
        expect(c.visitResult, isNull);
        expect(c.isSavingVisit, isFalse);
      } finally {
        c.dispose();
        contents.close();
        visits.close();
      }
    },
  );

  testWidgets(
    'a replacement session cannot log content loaded by another account',
    (tester) async {
      AuthToken? token = _token;
      final contents = _Contents();
      final visits = _Visits();
      final c = BeaconContentController(
        service: contents,
        visitLogService: visits,
        readToken: () => token,
        minRequestInterval: Duration.zero,
      );
      // Drain zero-duration cooldown timers explicitly in Flutter's fake clock.
      // Dispose before the widget-test invariant checks, including on failure.
      try {
        _receive(c, 1);
        contents.pending.single.complete(_content(1));
        await tester.pump(Duration.zero);
        token = const AuthToken(
          accessToken: 'other-account',
          tokenType: 'bearer',
        );
        await c.recordDisplayedContent(c.content!);
        expect(visits.artifacts, isEmpty);
        expect(c.visitError, isNotNull);
      } finally {
        c.dispose();
        contents.close();
        visits.close();
      }
    },
  );

  testWidgets('an inactive panel waits until its tab becomes visible', (
    tester,
  ) async {
    final contents = _Contents();
    final visits = _Visits();
    final c = BeaconContentController(
      service: contents,
      visitLogService: visits,
      readToken: () => _token,
      minRequestInterval: Duration.zero,
    );
    addTearDown(() {
      c.dispose();
      contents.close();
      visits.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BeaconContentPanel(controller: c, isActive: false),
        ),
      ),
    );
    _receive(c, 1);
    contents.pending.single.complete(_content(1));
    await tester.pumpAndSettle();
    expect(visits.artifacts, isEmpty);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BeaconContentPanel(controller: c, isActive: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(visits.artifacts, ['artifact-1']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Simulation records displayed A and B, without fabricated RSSI', (
    tester,
  ) async {
    final contents = _Contents();
    final visits = _Visits();
    addTearDown(() {
      contents.close();
      visits.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: BeaconSimulationPage(
          readToken: () => _token,
          contentService: contents,
          visitLogService: visits,
        ),
      ),
    );
    await tester.tap(find.text('Simulate Beacon A'));
    contents.pending.single.complete(_content(1));
    await tester.pumpAndSettle();
    expect(visits.artifacts, ['artifact-1']);
    await tester.tap(find.text('Simulate Beacon A'));
    await tester.pumpAndSettle();
    expect(visits.artifacts.length, 1);
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('Simulate Beacon B'));
    contents.pending.last.complete(_content(2));
    await tester.pumpAndSettle();
    expect(visits.artifacts, ['artifact-1', 'artifact-2']);
    expect(visits.signals, [null, null]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a covered route waits until the content screen is current', (
    tester,
  ) async {
    final contents = _Contents();
    final visits = _Visits();
    final c = BeaconContentController(
      service: contents,
      visitLogService: visits,
      readToken: () => _token,
      minRequestInterval: Duration.zero,
    );
    final navigator = GlobalKey<NavigatorState>();
    addTearDown(() {
      c.dispose();
      contents.close();
      visits.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(body: BeaconContentPanel(controller: c)),
      ),
    );
    _receive(c, 1);
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Other screen')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    contents.pending.single.complete(_content(1));
    await tester.pumpAndSettle();
    expect(visits.artifacts, isEmpty);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(visits.artifacts, ['artifact-1']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('confirmed real scan logs A and B once with measured RSSI', (
    tester,
  ) async {
    final contents = _Contents();
    final visits = _Visits();
    final source = StreamController<List<Beacon>>.broadcast();
    final key = GlobalKey<BeaconTestPageState>();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: BeaconTestPage(
            key: key,
            readToken: () => _token,
            contentService: contents,
            visitLogService: visits,
            beaconStream: source.stream,
          ),
        ),
      );
      await tester.tap(find.text('Bắt đầu quét'));
      await tester.pump();
      Future<void> emit(int minor) async {
        source.add([
          Beacon(
            proximityUUID: _uuid,
            major: 1,
            minor: minor,
            rssi: -50,
            accuracy: 1.5,
          ),
        ]);
        await tester.pump();
      }

      await emit(1);
      contents.pending.single.complete(_content(1));
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await emit(1);
      }
      expect(visits.artifacts, ['artifact-1']);
      await tester.pump(const Duration(seconds: 3));
      await emit(2);
      await emit(2);
      expect(contents.pending.length, 1);
      await emit(2);
      contents.pending.last.complete(_content(2));
      await tester.pumpAndSettle();
      expect(visits.artifacts, ['artifact-1', 'artifact-2']);
      expect(visits.signals, [-50, -50]);
      await tester.runAsync(() => key.currentState!.stopScanningIfNeeded());
      await tester.pump();
      expect(visits.artifacts.length, 2);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await source.close();
      contents.close();
      visits.close();
    }
  });
}
