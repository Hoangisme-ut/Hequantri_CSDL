import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/artifacts/artifact_detail_page.dart';
import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/auth/auth_session.dart';
import 'package:flutter_application_1/features/data/visitor_api_service.dart';
import 'package:flutter_application_1/features/home/favorites_page.dart';
import 'package:flutter_application_1/features/home/history_page.dart';
import 'package:flutter_application_1/features/home/home_page.dart';
import 'package:flutter_application_1/features/home/main_navigation_scaffold.dart';
import 'package:flutter_application_1/features/home/map_page.dart';
import 'package:flutter_application_1/features/home/profile_page.dart';
import 'package:flutter_application_1/l10n/app_strings.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  Widget buildApp({
    Locale locale = const Locale('vi'),
    ValueChanged<Locale>? onLocaleChanged,
    VisitorApi? visitorApi,
  }) {
    final session = AuthSession()
      ..authenticate(
        const AuthToken(
          accessToken: 'integration-test-token',
          tokenType: 'bearer',
        ),
      );
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
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: MainNavigationScaffold(
          onLocaleChanged: onLocaleChanged ?? (_) {},
          visitorApi: visitorApi ?? _FakeVisitorApi(),
        ),
      ),
    );
  }

  testWidgets(
    'MainNavigationScaffold switches across all 5 navigation tabs cleanly',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Tab 0: Home is visible
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Smart Heritage'), findsOneWidget);

      // Switch to Tab 1: Map
      await _tapNavigationDestination(tester, 1);
      await tester.pumpAndSettle();
      expect(find.byType(MapPage), findsOneWidget);

      // Switch to Tab 2: Artifacts
      await _tapNavigationDestination(tester, 2);
      await tester.pumpAndSettle();
      expect(find.text('Hiện vật'), findsWidgets);

      // Switch to Tab 3: Favorites
      await _tapNavigationDestination(tester, 3);
      await tester.pumpAndSettle();
      expect(find.byType(FavoritesPage), findsOneWidget);
      expect(find.textContaining('Tất cả'), findsOneWidget);

      // Switch to Tab 4: Profile
      await _tapNavigationDestination(tester, 4);
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(find.text('Cá nhân & Cài đặt'), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('artifact list uses backend UUIDs and opens API detail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await _tapNavigationDestination(tester, 2);
    await tester.pumpAndSettle();

    final title = _FakeVisitorApi.artifact.title!;
    expect(find.text(title), findsOneWidget);
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();

    expect(find.text('Artifact details from API'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home page navigates to ArtifactDetailPage and back cleanly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Scroll to bring highlighted artifacts into view
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    final artifactTitle = find.text('Bia Tiến sĩ thời Lê - Mạc').first;
    await tester.tap(artifactTitle);
    await tester.pumpAndSettle();

    // ArtifactDetailPage should be open
    expect(find.byType(ArtifactDetailPage), findsOneWidget);
    expect(find.text('Thuyết minh tự động'), findsOneWidget);
    expect(find.text('Địa điểm lưu giữ'), findsOneWidget);

    // Tap back button
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Back on HomePage
    expect(find.byType(HomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Favorites page filters tabs and opens detail screens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Navigate to Favorites tab
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(find.byType(FavoritesPage), findsOneWidget);

    // Switch to Artifacts tab - use first() since multiple "Hiện vật" texts may exist
    await tester.tap(find.textContaining('Hiện vật').first);
    await tester.pumpAndSettle();
    expect(find.text('Bia Tiến sĩ thời Lê - Mạc'), findsOneWidget);

    // Tap on artifact card -> opens detail
    await tester.tap(find.text('Bia Tiến sĩ thời Lê - Mạc'));
    await tester.pumpAndSettle();

    expect(find.byType(ArtifactDetailPage), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Switch to Heritage Sites tab - use first() since multiple "Di tích" texts may exist
    await tester.tap(find.textContaining('Di tích').first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile page navigates to HistoryPage and opens detail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Navigate to Profile tab
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    // Tap on Visit History tile
    await tester.tap(find.text('Lịch sử tham quan'));
    await tester.pumpAndSettle();

    expect(find.byType(HistoryPage), findsOneWidget);
    expect(find.textContaining('Tất cả'), findsOneWidget);

    // Tap on history item -> opens ArtifactDetailPage
    final firstItem = find.text('Bia Tiến sĩ thời Lê - Mạc');
    expect(firstItem, findsOneWidget);
    await tester.tap(firstItem);
    await tester.pumpAndSettle();

    expect(find.byType(ArtifactDetailPage), findsOneWidget);

    // Back to HistoryPage
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryPage), findsOneWidget);

    // Back to ProfilePage
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Layout renders on small screen size 320x568 without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Check Home on 320px
    expect(tester.takeException(), isNull);

    // Check Artifacts on 320px
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.museum_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Check Favorites on 320px
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.favorite_border),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Check Profile on 320px
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.person_outline),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tapNavigationDestination(WidgetTester tester, int index) async {
  final rect = tester.getRect(find.byType(NavigationBar));
  await tester.tapAt(
    Offset(rect.left + rect.width * (index + 0.5) / 5, rect.center.dy),
  );
}

class _FakeVisitorApi implements VisitorApi {
  static const artifactId = '20000000-0000-0000-0000-000000000001';
  static const userId = '50000000-0000-0000-0000-000000000001';
  static const artifact = VisitorArtifactSummary(
    id: artifactId,
    siteId: '10000000-0000-0000-0000-000000000002',
    code: 'VMQT-BIA-TIEN-SI',
    era: 'Thời Lê - Mạc',
    isActive: true,
    title: 'Bia Tiến sĩ thời Lê - Mạc',
    languageCode: 'vi',
  );

  bool _isFavorite = true;

  @override
  Future<VisitorPage<VisitorArtifactSummary>> loadArtifacts({
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) async => const VisitorPage(items: [artifact], count: 1);

  @override
  Future<VisitorArtifactContent> loadArtifact({
    required String artifactId,
    required String languageCode,
  }) async => VisitorArtifactContent(
    id: artifactId,
    siteId: '10000000-0000-0000-0000-000000000002',
    code: 'VMQT-BIA-TIEN-SI',
    era: 'Thời Lê - Mạc',
    title: 'Bia Tiến sĩ thời Lê - Mạc',
    description: 'Artifact details from API',
    languageCode: 'vi',
  );

  @override
  Future<VisitorPage<VisitorFavorite>> loadFavorites({
    required AuthToken token,
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) async => VisitorPage(
    count: _isFavorite ? 1 : 0,
    items: _isFavorite
        ? [
            VisitorFavorite(
              id: '40000000-0000-0000-0000-000000000001',
              userId: userId,
              artifactId: artifactId,
              artifact: artifact,
            ),
          ]
        : const [],
  );

  @override
  Future<void> addFavorite({
    required AuthToken token,
    required String artifactId,
  }) async {
    _isFavorite = true;
  }

  @override
  Future<void> removeFavorite({
    required AuthToken token,
    required String artifactId,
  }) async {
    _isFavorite = false;
  }

  @override
  Future<VisitorPage<VisitorVisit>> loadVisits({
    required AuthToken token,
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) async => VisitorPage(
    count: 1,
    items: [
      VisitorVisit(
        id: '60000000-0000-0000-0000-000000000001',
        userId: userId,
        artifactId: artifactId,
        artifact: artifact,
        visitedAt: DateTime.utc(2026, 10, 30),
      ),
    ],
  );

  @override
  Future<VisitorVisitReceipt> recordVisit({
    required AuthToken token,
    required String artifactId,
    String? beaconId,
    int? rssi,
    int? durationSeconds,
  }) async => VisitorVisitReceipt(
    id: '80000000-0000-0000-0000-000000000001',
    userId: userId,
    artifactId: artifactId,
    visitedAt: DateTime.utc(2026, 10, 30),
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
    userId: userId,
    artifactId: artifactId,
    rating: rating,
    comment: comment,
    status: 'pending',
  );
}
