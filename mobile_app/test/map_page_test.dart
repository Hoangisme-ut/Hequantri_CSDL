import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/data/visitor_api_service.dart';
import 'package:flutter_application_1/features/home/map_page.dart';
import 'package:flutter_application_1/l10n/app_strings.dart';

// Mock heritage site 1.
const _site = VisitorSite(
  id: '10000000-0000-0000-0000-000000000001',
  name: 'Bảo tàng Lịch sử TP.HCM',
  description: 'Nội dung do API cung cấp.',
  address: 'Thành phố Hồ Chí Minh',
  latitude: 10.7875,
  longitude: 106.7021,
);

// Mock heritage site 2.
const _secondSite = VisitorSite(
  id: '10000000-0000-0000-0000-000000000002',
  name: 'Địa điểm di sản thứ hai',
  description: 'Giới thiệu địa điểm thứ hai.',
  address: 'Địa chỉ thứ hai',
  latitude: 10.8200,
  longitude: 106.7500,
);

const _firstMarkerKey = ValueKey(
  'map-marker-10000000-0000-0000-0000-000000000001',
);

const _secondMarkerKey = ValueKey(
  'map-marker-10000000-0000-0000-0000-000000000002',
);

const _previewCardKey = ValueKey('selected-site-card');
const _detailsButtonKey = ValueKey('selected-site-details');
const _closeCardKey = ValueKey('close-site-card');

const _myLocationKey = ValueKey('map-my-location');
const _showHeritageKey = ValueKey('map-show-heritage-sites');
const _currentLocationKey = ValueKey('map-current-location');

void main() {
  // TEST 1: Load sites from Backend and open site details.
  testWidgets('Map tab uses real Sites and opens their API-backed details', (
    tester,
  ) async {
    final api = _FakeSiteApi()..sites = const [_site];

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(_firstMarkerKey), findsOneWidget);

    expect(find.text(_site.name), findsOneWidget);

    expect(find.textContaining('10.7875, 106.7021'), findsOneWidget);

    expect(find.text('Văn Miếu - Quốc Tử Giám'), findsNothing);

    // Tap the site in the list.
    await tester.tap(find.text(_site.name));
    await tester.pumpAndSettle();

    expect(find.text('Nội dung do API cung cấp.'), findsOneWidget);
  });

  // TEST 2: Selecting a marker displays a preview card.
  testWidgets('Tapping a map marker shows a preview without opening details', (
    tester,
  ) async {
    final api = _FakeSiteApi()..sites = const [_site];

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.byKey(_previewCardKey), findsNothing);

    await tester.tap(find.byKey(_firstMarkerKey));
    await tester.pumpAndSettle();

    // Map remains visible.
    expect(find.byType(FlutterMap), findsOneWidget);

    // Preview appears.
    expect(find.byKey(_previewCardKey), findsOneWidget);

    final preview = find.byKey(_previewCardKey);

    expect(
      find.descendant(of: preview, matching: find.text(_site.name)),
      findsOneWidget,
    );

    expect(
      find.descendant(of: preview, matching: find.text(_site.address!)),
      findsOneWidget,
    );

    // Site details must not open automatically.
    expect(find.text('Nội dung do API cung cấp.'), findsNothing);

    expect(find.byKey(_detailsButtonKey), findsOneWidget);
  });

  // TEST 3: Preview can be closed and reopened.
  testWidgets('Preview card can be closed and reopened', (tester) async {
    final api = _FakeSiteApi()..sites = const [_site];

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_firstMarkerKey));
    await tester.pumpAndSettle();

    expect(find.byKey(_previewCardKey), findsOneWidget);

    // Close preview.
    await tester.tap(find.byKey(_closeCardKey));
    await tester.pumpAndSettle();

    expect(find.byKey(_previewCardKey), findsNothing);

    // Select the marker again.
    await tester.tap(find.byKey(_firstMarkerKey));
    await tester.pumpAndSettle();

    expect(find.byKey(_previewCardKey), findsOneWidget);
  });

  // TEST 4: Preview updates when another marker is selected.
  testWidgets('Selecting another marker updates the preview card', (
    tester,
  ) async {
    final api = _FakeSiteApi()..sites = const [_site, _secondSite];

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_firstMarkerKey));
    await tester.pumpAndSettle();

    final previewCard = find.byKey(_previewCardKey);

    expect(previewCard, findsOneWidget);

    expect(
      find.descendant(of: previewCard, matching: find.text(_site.name)),
      findsOneWidget,
    );

    // Select the second marker.
    await tester.tap(find.byKey(_secondMarkerKey));
    await tester.pumpAndSettle();

    expect(previewCard, findsOneWidget);

    // The card now displays the second site.
    expect(
      find.descendant(of: previewCard, matching: find.text(_secondSite.name)),
      findsOneWidget,
    );

    // The first site's name is no longer in the preview.
    expect(
      find.descendant(of: previewCard, matching: find.text(_site.name)),
      findsNothing,
    );
  });

  // TEST 5: View details opens the correct site.
  testWidgets('View details button opens the selected site', (tester) async {
    final api = _FakeSiteApi()..sites = const [_site];

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_firstMarkerKey));
    await tester.pumpAndSettle();

    expect(find.byKey(_previewCardKey), findsOneWidget);

    await tester.tap(find.byKey(_detailsButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Nội dung do API cung cấp.'), findsOneWidget);

    expect(find.text('Chi tiết địa điểm'), findsOneWidget);
  });

  // TEST 6: Retry works when Backend initially fails.
  testWidgets('Map tab provides retry after a Site request failure', (
    tester,
  ) async {
    final api = _FakeSiteApi()..failNext = true;

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Thử lại'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(api.calls, 2);

    expect(find.text('Chưa có địa điểm di sản nào.'), findsOneWidget);
  });

  // TEST 7: Site data reloads when language changes.
  testWidgets('Map reloads Site names when locale changes', (tester) async {
    final api = _FakeSiteApi();

    final locale = ValueNotifier(const Locale('vi'));

    addTearDown(locale.dispose);

    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (context, value, _) => MaterialApp(
          locale: value,
          supportedLocales: const [Locale('vi'), Locale('en')],
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MapPage(siteApi: api, enableMapTiles: false),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(api.requestedLanguages, ['vi']);

    locale.value = const Locale('en');
    await tester.pumpAndSettle();

    expect(api.requestedLanguages, ['vi', 'en']);
  });

  // TEST 8: GPS controls are visible without automatic GPS access.
  testWidgets(
    'Map shows GPS controls without requesting location automatically',
    (tester) async {
      final api = _FakeSiteApi()..sites = const [_site, _secondSite];

      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      // Both control buttons should be present.
      expect(find.byKey(_myLocationKey), findsOneWidget);

      expect(find.byKey(_showHeritageKey), findsOneWidget);

      // No blue location marker before requesting GPS.
      expect(find.byKey(_currentLocationKey), findsNothing);

      // Existing heritage markers remain available.
      expect(find.byKey(_firstMarkerKey), findsOneWidget);
      expect(find.byKey(_secondMarkerKey), findsOneWidget);

      expect(find.byType(FlutterMap), findsOneWidget);
    },
  );

  // TEST 9: Return to the heritage area after moving the map.
  testWidgets('Show heritage sites button restores the heritage map view', (
    tester,
  ) async {
    final api = _FakeSiteApi()..sites = const [_site, _secondSite];

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    // Read the controller attached to FlutterMap.
    final mapWidget = tester.widget<FlutterMap>(find.byType(FlutterMap));

    final controller = mapWidget.mapController!;

    // Simulate moving the map far away.
    controller.move(const LatLng(0, 0), 5);

    await tester.pumpAndSettle();

    expect(controller.camera.center.latitude, closeTo(0, 0.01));

    expect(controller.camera.center.longitude, closeTo(0, 0.01));

    // Tap "Show heritage sites".
    await tester.tap(find.byKey(_showHeritageKey));

    await tester.pumpAndSettle();

    final center = controller.camera.center;

    // The camera returns near both heritage locations.
    expect(center.latitude, closeTo(10.804, 0.05));

    expect(center.longitude, closeTo(106.726, 0.05));

    // Both site markers remain in the map layer.
    expect(find.byKey(_firstMarkerKey), findsOneWidget);
    expect(find.byKey(_secondMarkerKey), findsOneWidget);
  });
}

// Common MaterialApp wrapper for widget tests.
Widget _app(SiteApi api) => MaterialApp(
  locale: const Locale('vi'),
  supportedLocales: const [Locale('vi'), Locale('en')],
  localizationsDelegates: const [
    AppStrings.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: MapPage(siteApi: api, enableMapTiles: false),
);

// Fake Backend API used by widget tests.
class _FakeSiteApi implements SiteApi {
  int calls = 0;
  bool failNext = false;

  List<VisitorSite> sites = const [];

  final requestedLanguages = <String>[];

  @override
  Future<VisitorPage<VisitorSite>> loadSites({
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) async {
    calls++;
    requestedLanguages.add(languageCode);

    if (failNext) {
      failNext = false;

      throw const VisitorApiException('unavailable', statusCode: 503);
    }

    return VisitorPage(items: sites, count: sites.length);
  }

  @override
  Future<VisitorSite> loadSite({
    required String siteId,
    required String languageCode,
  }) async {
    requestedLanguages.add(languageCode);

    for (final site in sites) {
      if (site.id == siteId) {
        return site;
      }
    }

    return _site;
  }
}
