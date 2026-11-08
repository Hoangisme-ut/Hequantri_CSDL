import 'dart:async';

import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/artifacts/artifact.dart';
import 'package:flutter_application_1/features/artifacts/artifact_detail_page.dart';
import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/auth/auth_session.dart';
import 'package:flutter_application_1/features/beacon/beacon_content_service.dart';
import 'package:flutter_application_1/features/beacon/beacon_tools_page.dart';
import 'package:flutter_application_1/features/data/visitor_api_service.dart';
import 'package:flutter_application_1/features/visits/visit_log_service.dart';
import 'package:flutter_application_1/l10n/app_strings.dart';

const _artifactId = '20000000-0000-0000-0000-000000000001';
const _beaconId = '30000000-0000-0000-0000-000000000001';
const _uuid = 'FDA50693-A4E2-4FB1-AFCF-C6EB07647825';
const _tokenA = AuthToken(accessToken: 'account-a', tokenType: 'bearer');
const _tokenB = AuthToken(accessToken: 'account-b', tokenType: 'bearer');
const _artifact = Artifact(
  id: _artifactId,
  titleVi: 'Preview title',
  titleEn: 'Preview title',
  period: '',
  category: '',
  location: '',
  descriptionVi: '',
  descriptionEn: '',
  imageUrl: '',
);
const _content = VisitorArtifactContent(
  id: _artifactId,
  siteId: '10000000-0000-0000-0000-000000000001',
  code: 'ART-1',
  title: 'Opened artifact content',
  description: 'Actual content',
);

Widget _app(
  AuthSession session,
  Widget child, {
  Locale locale = const Locale('en'),
  GlobalKey<NavigatorState>? navigator,
}) => AuthSessionScope(
  session: session,
  child: MaterialApp(
    navigatorKey: navigator,
    locale: locale,
    supportedLocales: const [Locale('vi'), Locale('en')],
    localizationsDelegates: const [
      AppStrings.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  ),
);

Future<void> _mount(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pump();
}

void main() {
  testWidgets(
    'an in-flight detail visit is not sent again during a locale change',
    (tester) async {
      final session = AuthSession()..authenticate(_tokenA);
      final api = _Api()..pendingRecord = Completer<VisitorVisitReceipt>();
      final detail = ArtifactDetailPage(artifact: _artifact, visitorApi: api);
      await _mount(tester, _app(session, detail));
      await tester.pumpAndSettle();
      expect(api.records, hasLength(1));
      await _mount(tester, _app(session, detail, locale: const Locale('vi')));
      await tester.pumpAndSettle();
      expect(api.records, hasLength(1));
      api.pendingRecord!.complete(
        VisitorVisitReceipt(
          id: 'v',
          userId: 'u',
          artifactId: _artifactId,
          wasCreated: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(api.records, hasLength(1));
    },
  );

  testWidgets(
    'reusing a detail route for A then B then A sends every new open to the server',
    (tester) async {
      final session = AuthSession()..authenticate(_tokenA);
      final api = _Api();
      const other = Artifact(
        id: '20000000-0000-0000-0000-000000000002',
        titleVi: 'B',
        titleEn: 'B',
        period: '',
        category: '',
        location: '',
        descriptionVi: '',
        descriptionEn: '',
        imageUrl: '',
      );
      for (final artifact in [_artifact, other, _artifact]) {
        await _mount(
          tester,
          _app(
            session,
            ArtifactDetailPage(artifact: artifact, visitorApi: api),
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(api.records.map((r) => r.artifactId).toList(), [
        _artifactId,
        other.id,
        _artifactId,
      ]);
    },
  );

  testWidgets('opening detail records only after remote content is displayed', (
    tester,
  ) async {
    final session = AuthSession()..authenticate(_tokenA);
    final api = _Api()..deferContent = true;
    await _mount(
      tester,
      _app(session, ArtifactDetailPage(artifact: _artifact, visitorApi: api)),
    );
    expect(api.records, isEmpty);
    api.loads.single.complete(_content);
    await tester.pumpAndSettle();
    expect(find.text('Opened artifact content'), findsOneWidget);
    expect(api.records.single.artifactId, _artifactId);
    expect(api.records.single.token.accessToken, _tokenA.accessToken);
    await tester.pump();
    expect(api.records, hasLength(1));
  });

  testWidgets('failed content load does not record a visit', (tester) async {
    final api = _Api()..deferContent = true;
    await _mount(
      tester,
      _app(
        AuthSession()..authenticate(_tokenA),
        ArtifactDetailPage(artifact: _artifact, visitorApi: api),
      ),
    );
    api.loads.single.completeError(
      const VisitorApiException('missing', statusCode: 404),
    );
    await tester.pumpAndSettle();
    expect(api.records, isEmpty);
  });

  testWidgets(
    'locale changes and rebuilding an open detail do not record again',
    (tester) async {
      final session = AuthSession()..authenticate(_tokenA);
      final api = _Api();
      final detail = ArtifactDetailPage(artifact: _artifact, visitorApi: api);
      await _mount(tester, _app(session, detail));
      await tester.pumpAndSettle();
      expect(api.records, hasLength(1));
      await _mount(tester, _app(session, detail, locale: const Locale('vi')));
      await tester.pumpAndSettle();
      expect(api.loads, hasLength(2));
      expect(api.records, hasLength(1));
    },
  );

  testWidgets('covered detail waits until it becomes the current route', (
    tester,
  ) async {
    final api = _Api()..deferContent = true;
    final navigator = GlobalKey<NavigatorState>();
    await _mount(
      tester,
      _app(
        AuthSession()..authenticate(_tokenA),
        ArtifactDetailPage(artifact: _artifact, visitorApi: api),
        navigator: navigator,
      ),
    );
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Other screen')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    api.loads.single.complete(_content);
    await tester.pumpAndSettle();
    expect(api.records, isEmpty);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(api.records, hasLength(1));
  });

  testWidgets(
    'account change discards old content before recording for the new account',
    (tester) async {
      final session = AuthSession()..authenticate(_tokenA);
      final api = _Api()..deferContent = true;
      await _mount(
        tester,
        _app(session, ArtifactDetailPage(artifact: _artifact, visitorApi: api)),
      );
      session.authenticate(_tokenB);
      await tester.pump();
      expect(api.loads, hasLength(2));
      api.loads.first.complete(_content);
      await tester.pump();
      expect(api.records, isEmpty);
      api.loads.last.complete(_content);
      await tester.pumpAndSettle();
      expect(api.records.single.token.accessToken, _tokenB.accessToken);
    },
  );

  testWidgets(
    'record failure keeps content and retries only on explicit action',
    (tester) async {
      final api = _Api()
        ..recordError = const VisitorApiException(
          'unavailable',
          statusCode: 503,
        );
      await _mount(
        tester,
        _app(
          AuthSession()..authenticate(_tokenA),
          ArtifactDetailPage(artifact: _artifact, visitorApi: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Opened artifact content'), findsOneWidget);
      expect(api.records, hasLength(1));
      await tester.pump();
      expect(api.records, hasLength(1));
      api.recordError = null;
      final retry = find.byKey(const Key('retry-artifact-visit'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(api.records, hasLength(2));
      expect(retry, findsNothing);
    },
  );

  testWidgets(
    'reopening detail sends a new request for the backend to deduplicate',
    (tester) async {
      final api = _Api();
      final session = AuthSession()..authenticate(_tokenA);
      await _mount(
        tester,
        _app(
          session,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => ArtifactDetailPage(
                      artifact: _artifact,
                      visitorApi: api,
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(api.records, hasLength(1));
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(api.records, hasLength(2));
    },
  );

  for (final mode in ['anonymous', 'demo']) {
    testWidgets('$mode detail does not record an authenticated visit', (
      tester,
    ) async {
      final api = _Api();
      final session = AuthSession();
      if (mode == 'demo') session.enterDemo();
      await _mount(
        tester,
        _app(session, ArtifactDetailPage(artifact: _artifact, visitorApi: api)),
      );
      await tester.pumpAndSettle();
      expect(api.records, isEmpty);
    });
  }

  testWidgets(
    'beacon preview and repeated signals do not record before opening details',
    (tester) async {
      final session = AuthSession()..authenticate(_tokenA);
      final api = _Api();
      final contents = _Contents();
      final oldVisits = _PreviewVisits();
      final source = StreamController<List<Beacon>>.broadcast();
      final key = GlobalKey<BeaconTestPageState>();
      try {
        await _mount(
          tester,
          _app(
            session,
            BeaconTestPage(
              key: key,
              readToken: session.readToken,
              contentService: contents,
              visitorApi: api,
              visitLogService: oldVisits,
              beaconStream: source.stream,
            ),
          ),
        );
        await tester.tap(find.text('Start scanning'));
        await tester.pump();
        for (var i = 0; i < 5; i++) {
          source.add([
            Beacon(
              proximityUUID: _uuid,
              major: 1,
              minor: 1,
              rssi: -50,
              accuracy: 1.5,
            ),
          ]);
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(oldVisits.calls, 0);
        expect(api.records, isEmpty);
        final open = find.text('Open artifact details');
        await tester.ensureVisible(open);
        await tester.pumpAndSettle();
        await tester.tap(open);
        // A packet arriving while the detail route is being built must not
        // replace the RSSI snapshot from the user's open action.
        source.add([
          Beacon(
            proximityUUID: _uuid,
            major: 1,
            minor: 1,
            rssi: -61,
            accuracy: 1.5,
          ),
        ]);
        await tester.pumpAndSettle();
        expect(api.records.single.artifactId, _artifactId);
        expect(api.records.single.beaconId, _beaconId);
        expect(api.records.single.rssi, -50);
        expect(oldVisits.calls, 0);
      } finally {
        await tester.runAsync(
          () =>
              key.currentState?.stopScanningIfNeeded() ?? Future<void>.value(),
        );
        await _mount(tester, const SizedBox.shrink());
        await source.close();
        contents.close();
        oldVisits.close();
      }
    },
  );
}

class _Record {
  _Record(this.token, this.artifactId, this.beaconId, this.rssi);
  final AuthToken token;
  final String artifactId;
  final String? beaconId;
  final int? rssi;
}

class _Api implements VisitorApi {
  bool deferContent = false;
  Object? recordError;
  Completer<VisitorVisitReceipt>? pendingRecord;
  final loads = <Completer<VisitorArtifactContent>>[];
  final records = <_Record>[];

  @override
  Future<VisitorArtifactContent> loadArtifact({
    required String artifactId,
    required String languageCode,
  }) {
    final pending = Completer<VisitorArtifactContent>();
    loads.add(pending);
    if (!deferContent) {
      pending.complete(
        VisitorArtifactContent(
          id: artifactId,
          siteId: _content.siteId,
          code: _content.code,
          title: _content.title,
          description: _content.description,
        ),
      );
    }
    return pending.future;
  }

  @override
  Future<VisitorPage<VisitorFavorite>> loadFavorites({
    required AuthToken token,
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) async => const VisitorPage(items: [], count: 0);
  @override
  Future<VisitorVisitReceipt> recordVisit({
    required AuthToken token,
    required String artifactId,
    String? beaconId,
    int? rssi,
    int? durationSeconds,
  }) async {
    records.add(_Record(token, artifactId, beaconId, rssi));
    if (recordError case final error?) throw error;
    if (pendingRecord case final pending?) return pending.future;
    return VisitorVisitReceipt(
      id: '40000000-0000-0000-0000-000000000001',
      userId: '50000000-0000-0000-0000-000000000001',
      artifactId: artifactId,
      wasCreated: true,
      visitedAt: DateTime.now().toUtc(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Contents extends BeaconContentService {
  _Contents() : super(baseUrl: Uri.parse('https://example.test'));
  @override
  Future<BeaconContent> resolve({
    required String proximityUuid,
    required int major,
    required int minor,
    required AuthToken token,
    String? languageCode,
  }) async => const BeaconContent(
    beaconId: _beaconId,
    artifactId: _artifactId,
    siteId: '10000000-0000-0000-0000-000000000001',
    code: 'ART-1',
    title: 'Beacon preview',
    description: 'Preview is not an open action',
  );
}

class _PreviewVisits extends VisitLogService {
  _PreviewVisits() : super(baseUrl: Uri.parse('https://example.test'));
  int calls = 0;
  @override
  Future<VisitRecordResult> record({
    required String artifactId,
    required AuthToken token,
    required String beaconId,
    int? rssi,
  }) async {
    calls++;
    return VisitRecordResult(
      visit: VisitRecord(id: 'v', artifactId: artifactId),
      alreadyRecorded: false,
    );
  }
}
