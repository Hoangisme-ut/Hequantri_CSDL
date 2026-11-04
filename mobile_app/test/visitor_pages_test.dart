import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/artifacts/artifact_detail_page.dart';
import 'package:flutter_application_1/features/artifacts/artifact.dart';
import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/auth/auth_session.dart';
import 'package:flutter_application_1/features/data/visitor_api_service.dart';
import 'package:flutter_application_1/features/home/favorites_page.dart';
import 'package:flutter_application_1/features/home/history_page.dart';
import 'package:flutter_application_1/l10n/app_strings.dart';

const _token = AuthToken(accessToken: 'widget-test-token', tokenType: 'bearer');
const _artifactId = '20000000-0000-0000-0000-000000000001';

void main() {
  testWidgets(
    'Favorites discards old-account responses and reloads current account',
    (tester) async {
      final api = _DeferredVisitorApi();
      final session = AuthSession()..authenticate(_token);
      await tester.pumpWidget(
        _appWithSession(session, FavoritesPage(api: api)),
      );
      await tester.pump();
      expect(api.favoriteRequests, hasLength(1));
      api.favoriteRequests[0].completer.complete(
        _favoritePage('Account A item'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Account A item'), findsOneWidget);

      final pageState = tester.state<FavoritesPageState>(
        find.byType(FavoritesPage),
      );
      unawaited(pageState.reload());
      await tester.pump();
      expect(api.favoriteRequests, hasLength(2));

      session.authenticate(
        const AuthToken(accessToken: 'second-account', tokenType: 'bearer'),
      );
      await tester.pump();
      expect(find.text('Account A item'), findsNothing);

      api.favoriteRequests[1].completer.complete(_favoritePage('Stale item'));
      await tester.pump();
      await tester.pump();
      expect(api.favoriteRequests, hasLength(3));
      expect(find.text('Stale item'), findsNothing);
      expect(api.favoriteRequests.last.token.accessToken, 'second-account');

      api.favoriteRequests.last.completer.complete(
        _favoritePage('Account B item'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Account B item'), findsOneWidget);
      expect(find.text('Stale item'), findsNothing);
    },
  );

  testWidgets(
    'History reloads the latest locale after a stale request finishes',
    (tester) async {
      final api = _DeferredVisitorApi();
      final session = AuthSession()..authenticate(_token);
      await tester.pumpWidget(_appWithSession(session, HistoryPage(api: api)));
      await tester.pump();
      expect(api.visitRequests, hasLength(1));
      await tester.pumpWidget(
        _appWithSession(
          session,
          HistoryPage(api: api),
          locale: const Locale('en'),
        ),
      );
      await tester.pump();

      api.visitRequests[0].completer.complete(
        _visitPage('Stale Vietnamese item'),
      );
      await tester.pump();
      await tester.pump();
      expect(api.visitRequests, hasLength(2));
      expect(api.visitRequests.last.languageCode, 'en');
      expect(find.text('Stale Vietnamese item'), findsNothing);

      api.visitRequests.last.completer.complete(_visitPage('English item'));
      await tester.pump();
      await tester.pump();
      expect(find.text('English item'), findsOneWidget);
      expect(find.text('Stale Vietnamese item'), findsNothing);
    },
  );

  testWidgets('History discards the previous account response', (tester) async {
    final api = _DeferredVisitorApi();
    final session = AuthSession()..authenticate(_token);
    await tester.pumpWidget(_appWithSession(session, HistoryPage(api: api)));
    await tester.pump();
    expect(api.visitRequests, hasLength(1));

    session.authenticate(
      const AuthToken(accessToken: 'history-account-b', tokenType: 'bearer'),
    );
    await tester.pump();
    expect(find.text('Stale history account'), findsNothing);

    api.visitRequests[0].completer.complete(
      _visitPage('Stale history account'),
    );
    await tester.pump();
    await tester.pump();
    expect(api.visitRequests, hasLength(2));
    expect(api.visitRequests.last.token.accessToken, 'history-account-b');
    expect(find.text('Stale history account'), findsNothing);

    api.visitRequests.last.completer.complete(
      _visitPage('Current history account'),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Current history account'), findsOneWidget);
  });

  testWidgets(
    'History pagination advances raw offsets and removes duplicate visits',
    (tester) async {
      final api = _DeferredVisitorApi();
      final session = AuthSession()..authenticate(_token);
      await tester.pumpWidget(_appWithSession(session, HistoryPage(api: api)));
      await tester.pump();
      api.visitRequests[0].completer.complete(
        _visitPage('First visit', count: 2),
      );
      await tester.pump();
      await tester.pump();

      expect(api.visitRequests, hasLength(1));
      expect(find.text('Xem th\u00eam'), findsOneWidget);
      await tester.tap(find.text('Xem th\u00eam'));
      await tester.pump();
      expect(api.visitRequests, hasLength(2));
      expect(api.visitRequests.map((request) => request.skip), [0, 1]);
      api.visitRequests[1].completer.complete(
        _visitPage('Duplicate visit', count: 2),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Tất cả (1)'), findsOneWidget);
      expect(find.text('First visit'), findsOneWidget);
      expect(find.text('Duplicate visit'), findsNothing);
    },
  );

  testWidgets('History shows API fallback language and supports refresh', (
    tester,
  ) async {
    final api = _FakeVisitorApi()..fallbackHistory = true;
    await tester.pumpWidget(_app(api, const HistoryPage()));
    await tester.pumpAndSettle();

    expect(find.text('Ng\u00f4n ng\u1eef d\u1ef1 ph\u00f2ng'), findsOneWidget);
    expect(api.visitLoads, 1);
    await tester.tap(find.byTooltip('L\u00e0m m\u1edbi'));
    await tester.pumpAndSettle();
    expect(api.visitLoads, 2);
  });

  testWidgets(
    'Favorites pagination advances raw offsets and removes duplicate artifacts',
    (tester) async {
      final api = _DeferredVisitorApi();
      final session = AuthSession()..authenticate(_token);
      await tester.pumpWidget(
        _appWithSession(session, FavoritesPage(api: api)),
      );
      await tester.pump();
      api.favoriteRequests[0].completer.complete(
        _favoritePage('First favorite', count: 2),
      );
      await tester.pump();
      await tester.pump();

      expect(api.favoriteRequests, hasLength(2));
      expect(api.favoriteRequests.map((request) => request.skip), [0, 1]);
      api.favoriteRequests[1].completer.complete(
        _favoritePage('Duplicate favorite', count: 2),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Hiện vật (1)'), findsOneWidget);
      expect(find.text('First favorite'), findsOneWidget);
      expect(find.text('Duplicate favorite'), findsNothing);
    },
  );

  testWidgets('Artifact detail ignores content returned for an older locale', (
    tester,
  ) async {
    final api = _DeferredVisitorApi();
    final session = AuthSession()..authenticate(_token);
    const artifact = Artifact(
      id: _artifactId,
      titleVi: 'Vietnamese fallback',
      titleEn: 'English fallback',
      period: 'Test era',
      category: 'Artifact',
      location: 'Test site',
      descriptionVi: 'Fallback description',
      descriptionEn: 'Fallback description',
      imageUrl: '',
    );
    await tester.pumpWidget(
      _appWithSession(
        session,
        ArtifactDetailPage(
          artifact: artifact,
          visitorApi: api,
          initialIsFavorite: false,
        ),
      ),
    );
    await tester.pump();
    expect(api.artifactRequests, hasLength(1));

    await tester.pumpWidget(
      _appWithSession(
        session,
        ArtifactDetailPage(
          artifact: artifact,
          visitorApi: api,
          initialIsFavorite: false,
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pump();
    expect(api.artifactRequests, hasLength(2));
    expect(api.artifactRequests.last.languageCode, 'en');

    api.artifactRequests.last.completer.complete(
      _artifactContent('Current English'),
    );
    await tester.pump();
    expect(find.text('Current English'), findsOneWidget);

    api.artifactRequests.first.completer.complete(
      _artifactContent('Stale Vietnamese'),
    );
    await tester.pump();
    expect(find.text('Current English'), findsOneWidget);
    expect(find.text('Stale Vietnamese'), findsNothing);
  });

  testWidgets('Artifact detail discards favorite state from an old account', (
    tester,
  ) async {
    final api = _DeferredVisitorApi();
    final session = AuthSession()..authenticate(_token);
    const artifact = Artifact(
      id: _artifactId,
      titleVi: 'Vietnamese fallback',
      titleEn: 'English fallback',
      period: 'Test era',
      category: 'Artifact',
      location: 'Test site',
      descriptionVi: 'Fallback description',
      descriptionEn: 'Fallback description',
      imageUrl: '',
      isFavorite: false,
    );
    await tester.pumpWidget(
      _appWithSession(
        session,
        ArtifactDetailPage(artifact: artifact, visitorApi: api),
      ),
    );
    await tester.pump();
    expect(api.favoriteRequests, hasLength(1));

    session.authenticate(
      const AuthToken(accessToken: 'detail-account-b', tokenType: 'bearer'),
    );
    await tester.pump();
    expect(api.favoriteRequests, hasLength(2));
    api.favoriteRequests[1].completer.complete(
      const VisitorPage<VisitorFavorite>(items: [], count: 0),
    );
    await tester.pump();
    expect(find.byIcon(Icons.favorite_border), findsWidgets);

    api.favoriteRequests[0].completer.complete(
      _favoritePage('Old account favorite'),
    );
    await tester.pump();
    expect(find.byIcon(Icons.favorite_border), findsWidgets);
    expect(find.byIcon(Icons.favorite), findsNothing);
  });

  testWidgets('Favorites load from API and reflect a successful removal', (
    tester,
  ) async {
    final api = _FakeVisitorApi();
    await tester.pumpWidget(_app(api, const FavoritesPage()));
    await tester.pumpAndSettle();

    expect(find.text('Artifact from API'), findsOneWidget);
    await tester.tap(find.text('Artifact from API'));
    await tester.pumpAndSettle();
    expect(find.byType(ArtifactDetailPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite).first);
    await tester.pumpAndSettle();
    expect(api.removeCalls, 1);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Chưa có mục yêu thích nào'), findsOneWidget);
    expect(api.favoriteLoads, greaterThanOrEqualTo(2));
  });

  testWidgets('Favorites detail blocks duplicate mutation taps', (
    tester,
  ) async {
    final api = _FakeVisitorApi()..pendingMutation = Completer<void>();
    await tester.pumpWidget(_app(api, const FavoritesPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Artifact from API'));
    await tester.pumpAndSettle();

    final favoriteButton = find.byIcon(Icons.favorite).first;
    await tester.tap(favoriteButton);
    await tester.pump();
    expect(api.removeCalls, 1);
    await tester.tap(favoriteButton, warnIfMissed: false);
    await tester.pump();
    expect(api.removeCalls, 1);

    api.pendingMutation!.complete();
    await tester.pumpAndSettle();
    expect(api.favorite, isFalse);
  });

  testWidgets('History loads API entries and opens the matching detail', (
    tester,
  ) async {
    final api = _FakeVisitorApi();
    await tester.pumpWidget(_app(api, const HistoryPage()));
    await tester.pumpAndSettle();

    expect(find.text('Artifact from API'), findsOneWidget);
    await tester.tap(find.text('Artifact from API'));
    await tester.pumpAndSettle();
    expect(find.byType(ArtifactDetailPage), findsOneWidget);
  });

  testWidgets('History shows the empty state when the API returns no visits', (
    tester,
  ) async {
    final api = _FakeVisitorApi()..historyEmpty = true;
    await tester.pumpWidget(_app(api, const HistoryPage()));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có lịch sử tham quan'), findsOneWidget);
  });

  testWidgets('Favorites shows API authentication errors with retry', (
    tester,
  ) async {
    final api = _FakeVisitorApi()
      ..favoriteFailure = const VisitorApiException(
        'Your session has expired. Please sign in again.',
        statusCode: 401,
      );
    await tester.pumpWidget(_app(api, const FavoritesPage()));
    await tester.pumpAndSettle();

    expect(
      find.text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);
  });
}

Widget _app(VisitorApi api, Widget home) {
  final session = AuthSession()..authenticate(_token);
  return _appWithSession(
    session,
    home is FavoritesPage ? FavoritesPage(api: api) : HistoryPage(api: api),
  );
}

Widget _appWithSession(
  AuthSession session,
  Widget home, {
  Locale locale = const Locale('vi'),
}) {
  return AuthSessionScope(
    session: session,
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  );
}

VisitorPage<VisitorFavorite> _favoritePage(String title, {int count = 1}) =>
    VisitorPage(
      count: count,
      items: [
        VisitorFavorite(
          id: '40000000-0000-0000-0000-000000000001',
          userId: '50000000-0000-0000-0000-000000000001',
          artifactId: _artifactId,
          artifact: _summaryWithTitle(title),
        ),
      ],
    );

VisitorPage<VisitorVisit> _visitPage(String title, {int count = 1}) =>
    VisitorPage(
      count: count,
      items: [
        VisitorVisit(
          id: '60000000-0000-0000-0000-000000000001',
          userId: '50000000-0000-0000-0000-000000000001',
          artifactId: _artifactId,
          artifact: _summaryWithTitle(title),
          visitedAt: DateTime.utc(2026, 10, 30),
        ),
      ],
    );

VisitorArtifactSummary _summaryWithTitle(String title) =>
    VisitorArtifactSummary(
      id: _artifactId,
      siteId: '10000000-0000-0000-0000-000000000001',
      code: 'TEST-ARTIFACT',
      era: 'Test era',
      isActive: true,
      title: title,
      languageCode: 'vi',
    );

VisitorArtifactContent _artifactContent(String title) => VisitorArtifactContent(
  id: _artifactId,
  siteId: '10000000-0000-0000-0000-000000000001',
  code: 'TEST-ARTIFACT',
  title: title,
  description: 'Description',
  languageCode: 'en',
);

class _FakeVisitorApi implements VisitorApi {
  static const _summary = VisitorArtifactSummary(
    id: _artifactId,
    siteId: '10000000-0000-0000-0000-000000000001',
    code: 'TEST-ARTIFACT',
    era: 'Test era',
    isActive: true,
    title: 'Artifact from API',
    languageCode: 'vi',
  );

  bool favorite = true;
  bool historyEmpty = false;
  bool fallbackHistory = false;
  int favoriteLoads = 0;
  int visitLoads = 0;
  int removeCalls = 0;
  VisitorApiException? favoriteFailure;
  Completer<void>? pendingMutation;

  @override
  Future<VisitorPage<VisitorArtifactSummary>> loadArtifacts({
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) async => VisitorPage(count: 1, items: const [_summary]);

  @override
  Future<VisitorArtifactContent> loadArtifact({
    required String artifactId,
    required String languageCode,
  }) async => const VisitorArtifactContent(
    id: _artifactId,
    siteId: '10000000-0000-0000-0000-000000000001',
    code: 'TEST-ARTIFACT',
    era: 'Test era',
    title: 'Artifact from API',
    description: 'Artifact description from API',
    languageCode: 'vi',
  );

  @override
  Future<VisitorPage<VisitorFavorite>> loadFavorites({
    required AuthToken token,
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) async {
    favoriteLoads++;
    if (favoriteFailure case final error?) throw error;
    return VisitorPage(
      count: favorite ? 1 : 0,
      items: favorite
          ? [
              const VisitorFavorite(
                id: '40000000-0000-0000-0000-000000000001',
                userId: '50000000-0000-0000-0000-000000000001',
                artifactId: _artifactId,
                artifact: _summary,
              ),
            ]
          : const [],
    );
  }

  @override
  Future<void> addFavorite({
    required AuthToken token,
    required String artifactId,
  }) async {
    favorite = true;
  }

  @override
  Future<void> removeFavorite({
    required AuthToken token,
    required String artifactId,
  }) async {
    removeCalls++;
    if (pendingMutation != null) await pendingMutation!.future;
    favorite = false;
  }

  @override
  Future<VisitorPage<VisitorVisit>> loadVisits({
    required AuthToken token,
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) async {
    visitLoads++;
    return VisitorPage(
      count: historyEmpty ? 0 : 1,
      items: historyEmpty
          ? const []
          : [
              VisitorVisit(
                id: '60000000-0000-0000-0000-000000000001',
                userId: '50000000-0000-0000-0000-000000000001',
                artifactId: _artifactId,
                artifact: VisitorArtifactSummary(
                  id: _summary.id,
                  siteId: _summary.siteId,
                  code: _summary.code,
                  era: _summary.era,
                  isActive: _summary.isActive,
                  title: _summary.title,
                  languageCode: _summary.languageCode,
                  isFallback: fallbackHistory,
                ),
                visitedAt: DateTime.utc(2026, 10, 30),
              ),
            ],
    );
  }

  @override
  Future<VisitorVisitReceipt> recordVisit({
    required AuthToken token,
    required String artifactId,
    String? beaconId,
    int? rssi,
    int? durationSeconds,
  }) async => const VisitorVisitReceipt(
    id: '80000000-0000-0000-0000-000000000001',
    userId: '50000000-0000-0000-0000-000000000001',
    artifactId: _artifactId,
    wasCreated: true,
  );
}

class _DeferredVisitorApi extends _FakeVisitorApi {
  final favoriteRequests = <_DeferredCall<VisitorPage<VisitorFavorite>>>[];
  final visitRequests = <_DeferredCall<VisitorPage<VisitorVisit>>>[];
  final artifactRequests = <_DeferredArtifactCall>[];

  @override
  Future<VisitorPage<VisitorFavorite>> loadFavorites({
    required AuthToken token,
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) {
    final request = _DeferredCall<VisitorPage<VisitorFavorite>>(
      token: token,
      languageCode: languageCode,
      skip: skip,
      limit: limit,
    );
    favoriteRequests.add(request);
    return request.completer.future;
  }

  @override
  Future<VisitorPage<VisitorVisit>> loadVisits({
    required AuthToken token,
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) {
    final request = _DeferredCall<VisitorPage<VisitorVisit>>(
      token: token,
      languageCode: languageCode,
      skip: skip,
      limit: limit,
    );
    visitRequests.add(request);
    return request.completer.future;
  }

  @override
  Future<VisitorArtifactContent> loadArtifact({
    required String artifactId,
    required String languageCode,
  }) {
    final request = _DeferredArtifactCall(artifactId, languageCode);
    artifactRequests.add(request);
    return request.completer.future;
  }
}

class _DeferredCall<T> {
  _DeferredCall({
    required this.token,
    required this.languageCode,
    required this.skip,
    required this.limit,
  });

  final AuthToken token;
  final String languageCode;
  final int skip;
  final int limit;
  final completer = Completer<T>();
}

class _DeferredArtifactCall {
  _DeferredArtifactCall(this.artifactId, this.languageCode);

  final String artifactId;
  final String languageCode;
  final completer = Completer<VisitorArtifactContent>();
}
