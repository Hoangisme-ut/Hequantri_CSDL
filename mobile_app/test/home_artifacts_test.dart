import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/artifacts/artifact_detail_page.dart';
import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/data/visitor_api_service.dart';
import 'package:flutter_application_1/features/home/home_page.dart';
import 'package:flutter_application_1/l10n/app_strings.dart';

const _testSite = VisitorSite(
  id: '10000000-0000-0000-0000-000000000001',
  name: 'Văn Miếu - Quốc Tử Giám',
  description: 'Khu di tích lịch sử.',
  address: 'Hà Nội',
  isActive: true,
);

const _testArtifact = VisitorArtifactSummary(
  id: '20000000-0000-0000-0000-000000000001',
  siteId: '10000000-0000-0000-0000-000000000001',
  code: 'VMQT-BIA-01',
  era: 'Thời Lê - Mạc',
  isActive: true,
  title: 'Bia Tiến sĩ số 01',
  languageCode: 'vi',
);

const _testArtifactEn = VisitorArtifactSummary(
  id: '20000000-0000-0000-0000-000000000001',
  siteId: '10000000-0000-0000-0000-000000000001',
  code: 'VMQT-BIA-01',
  era: 'Le - Mac Dynasty',
  isActive: true,
  title: 'Doctoral Stele No. 01',
  languageCode: 'en',
);

void main() {
  testWidgets('Home shows loading then renders backend artifacts', (
    tester,
  ) async {
    final pending = Completer<VisitorPage<VisitorArtifactSummary>>();
    final api = _FakeFullApi()
      ..sitesResult = const VisitorPage(items: [_testSite], count: 1)
      ..nextArtifacts = pending.future;

    await tester.pumpWidget(_app(api));
    await tester.pump();

    // Verify sections and loading indicator
    expect(find.text('Hiện vật tiêu biểu'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    pending.complete(
      const VisitorPage<VisitorArtifactSummary>(
        items: [_testArtifact],
        count: 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bia Tiến sĩ số 01'), findsOneWidget);
    expect(find.textContaining('Thời Lê - Mạc'), findsOneWidget);
    expect(find.textContaining('Văn Miếu - Quốc Tử Giám'), findsWidgets);
    expect(find.text('1 hiện vật'), findsOneWidget);
  });

  testWidgets('Home displays empty state when API returns 0 artifacts', (
    tester,
  ) async {
    final api = _FakeFullApi()
      ..sitesResult = const VisitorPage(items: [_testSite], count: 1)
      ..artifactsResults = [
        const VisitorPage<VisitorArtifactSummary>(items: [], count: 0),
      ];

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Hiện vật tiêu biểu'), findsOneWidget);
    expect(find.text('Hiện chưa có hiện vật nào.'), findsOneWidget);
  });

  testWidgets('Home shows error card with retry button when Artifact API fails', (
    tester,
  ) async {
    final api = _FakeFullApi()
      ..sitesResult = const VisitorPage(items: [_testSite], count: 1)
      ..artifactsResults = [
        const VisitorApiException('error', statusCode: 500),
        const VisitorPage<VisitorArtifactSummary>(
          items: [_testArtifact],
          count: 1,
        ),
      ];

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(
      find.text('Máy chủ hiện không khả dụng. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);

    // Scroll to bring button into view if needed
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    // Tap retry button
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(api.loadArtifactsCalls, 2);
    expect(find.text('Bia Tiến sĩ số 01'), findsOneWidget);
  });

  testWidgets('Home reloads backend artifacts when locale changes', (
    tester,
  ) async {
    final api = _FakeFullApi()
      ..sitesResult = const VisitorPage(items: [_testSite], count: 1)
      ..artifactsResults = [
        const VisitorPage<VisitorArtifactSummary>(
          items: [_testArtifact],
          count: 1,
        ),
        const VisitorPage<VisitorArtifactSummary>(
          items: [_testArtifactEn],
          count: 1,
        ),
      ];

    final locale = ValueNotifier(const Locale('vi'));
    addTearDown(locale.dispose);

    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (context, val, _) => MaterialApp(
          locale: val,
          supportedLocales: const [Locale('vi'), Locale('en')],
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: HomePage(
            siteApi: api,
            visitorApi: api,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bia Tiến sĩ số 01'), findsOneWidget);
    expect(api.requestedLanguages, ['vi']);

    // Switch to English
    locale.value = const Locale('en');
    await tester.pumpAndSettle();

    expect(api.requestedLanguages, ['vi', 'en']);
    expect(find.text('Doctoral Stele No. 01'), findsOneWidget);
    expect(find.text('Highlighted Artifacts'), findsOneWidget);
    expect(find.text('1 items'), findsOneWidget);
  });

  testWidgets('Home can refresh artifacts using section refresh button', (
    tester,
  ) async {
    final api = _FakeFullApi()
      ..sitesResult = const VisitorPage(items: [_testSite], count: 1)
      ..artifactsResults = [
        const VisitorPage<VisitorArtifactSummary>(items: [], count: 0),
        const VisitorPage<VisitorArtifactSummary>(
          items: [_testArtifact],
          count: 1,
        ),
      ];

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Hiện chưa có hiện vật nào.'), findsOneWidget);

    // Scroll to section
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tải lại hiện vật'));
    await tester.pumpAndSettle();

    expect(api.loadArtifactsCalls, 2);
    expect(find.text('Bia Tiến sĩ số 01'), findsOneWidget);
  });

  testWidgets(
    'Tapping backend artifact opens ArtifactDetailPage with backend UUID',
    (tester) async {
      final api = _FakeFullApi()
        ..sitesResult = const VisitorPage(items: [_testSite], count: 1)
        ..artifactsResults = [
          const VisitorPage<VisitorArtifactSummary>(
            items: [_testArtifact],
            count: 1,
          ),
        ]
        ..detailResult = VisitorArtifactContent(
          id: _testArtifact.id,
          siteId: _testArtifact.siteId,
          code: _testArtifact.code,
          era: _testArtifact.era,
          title: _testArtifact.title,
          description: 'Mô tả chi tiết hiện vật từ Backend.',
          languageCode: 'vi',
        );

      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      // Scroll to bring artifact card into view
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bia Tiến sĩ số 01'));
      await tester.pumpAndSettle();

      expect(find.byType(ArtifactDetailPage), findsOneWidget);
      expect(find.text('Mô tả chi tiết hiện vật từ Backend.'), findsOneWidget);
      expect(find.text('Lưu vào yêu thích'), findsOneWidget);
      expect(find.text('Đánh giá hiện vật'), findsOneWidget);
    },
  );

  testWidgets('Search query filters backend artifacts by title and code', (
    tester,
  ) async {
    const secondArtifact = VisitorArtifactSummary(
      id: '20000000-0000-0000-0000-000000000002',
      siteId: '10000000-0000-0000-0000-000000000001',
      code: 'TRONG-DONG-01',
      era: 'Đông Sơn',
      isActive: true,
      title: 'Trống đồng Đông Sơn',
      languageCode: 'vi',
    );

    final api = _FakeFullApi()
      ..sitesResult = const VisitorPage(items: [_testSite], count: 1)
      ..artifactsResults = [
        const VisitorPage<VisitorArtifactSummary>(
          items: [_testArtifact, secondArtifact],
          count: 2,
        ),
      ];

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Bia Tiến sĩ số 01'), findsOneWidget);
    expect(find.text('Trống đồng Đông Sơn'), findsOneWidget);

    // Search for "Trống"
    await tester.enterText(find.byType(TextField), 'Trống');
    await tester.pumpAndSettle();

    expect(find.text('Bia Tiến sĩ số 01'), findsNothing);
    expect(find.text('Trống đồng Đông Sơn'), findsOneWidget);

    // Clear search
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(find.text('Bia Tiến sĩ số 01'), findsOneWidget);
    expect(find.text('Trống đồng Đông Sơn'), findsOneWidget);
  });
}

Widget _app(VisitorApi api) => MaterialApp(
  locale: const Locale('vi'),
  supportedLocales: const [Locale('vi'), Locale('en')],
  localizationsDelegates: const [
    AppStrings.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: HomePage(
    siteApi: api is SiteApi ? (api as SiteApi) : null,
    visitorApi: api,
  ),
);

class _FakeFullApi implements VisitorApi, SiteApi {
  int loadArtifactsCalls = 0;
  int loadSitesCalls = 0;
  Future<VisitorPage<VisitorArtifactSummary>>? nextArtifacts;
  List<Object> artifactsResults = [];
  VisitorPage<VisitorSite> sitesResult = const VisitorPage(
    items: [],
    count: 0,
  );
  VisitorArtifactContent? detailResult;
  final requestedLanguages = <String>[];

  @override
  Future<VisitorPage<VisitorArtifactSummary>> loadArtifacts({
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) async {
    loadArtifactsCalls++;
    requestedLanguages.add(languageCode);
    if (nextArtifacts != null) return nextArtifacts!;
    if (artifactsResults.isEmpty) {
      return const VisitorPage<VisitorArtifactSummary>(items: [], count: 0);
    }
    final res = artifactsResults.removeAt(0);
    if (res is Exception) throw res;
    return res as VisitorPage<VisitorArtifactSummary>;
  }

  @override
  Future<VisitorArtifactContent> loadArtifact({
    required String artifactId,
    required String languageCode,
  }) async {
    return detailResult ??
        VisitorArtifactContent(
          id: artifactId,
          siteId: '10000000-0000-0000-0000-000000000001',
          code: 'CODE',
          title: 'Chi tiết hiện vật',
          description: 'Mô tả chi tiết',
          languageCode: languageCode,
        );
  }

  @override
  Future<VisitorPage<VisitorSite>> loadSites({
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) async {
    loadSitesCalls++;
    return sitesResult;
  }

  @override
  Future<VisitorSite> loadSite({
    required String siteId,
    required String languageCode,
  }) async => _testSite;

  @override
  Future<VisitorPage<VisitorFavorite>> loadFavorites({
    required AuthToken token,
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) async => const VisitorPage(items: [], count: 0);

  @override
  Future<void> addFavorite({
    required AuthToken token,
    required String artifactId,
  }) async {}

  @override
  Future<void> removeFavorite({
    required AuthToken token,
    required String artifactId,
  }) async {}

  @override
  Future<VisitorPage<VisitorVisit>> loadVisits({
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
  }) async => VisitorVisitReceipt(
    id: '80000000-0000-0000-0000-000000000001',
    userId: '50000000-0000-0000-0000-000000000001',
    artifactId: artifactId,
    wasCreated: true,
  );

  @override
  Future<VisitorFeedback> submitFeedback({
    required AuthToken token,
    required String artifactId,
    required int rating,
    String? comment,
  }) async => VisitorFeedback(
    id: '70000000-0000-0000-0000-000000000001',
    userId: '50000000-0000-0000-0000-000000000001',
    artifactId: artifactId,
    rating: rating,
    comment: comment,
    status: 'pending',
  );

  @override
  Future<VisitorPage<VisitorFeedback>> loadUserFeedbacks({
    required AuthToken token,
    int skip = 0,
    int limit = 50,
    bool includeInactive = false,
  }) async => const VisitorPage(items: [], count: 0);

  @override
  Future<VisitorFeedback> updateFeedback({
    required AuthToken token,
    required String feedbackId,
    int? rating,
    String? comment,
  }) async => VisitorFeedback(
    id: feedbackId,
    userId: '50000000-0000-0000-0000-000000000001',
    artifactId: '20000000-0000-0000-0000-000000000001',
    rating: rating ?? 5,
    comment: comment,
    status: 'approved',
  );
}
