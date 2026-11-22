import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:flutter_application_1/features/data/visitor_api_service.dart';
import 'package:flutter_application_1/features/home/map_page.dart';
import 'package:flutter_application_1/l10n/app_strings.dart';

const _site = VisitorSite(
  id: '10000000-0000-0000-0000-000000000001',
  name: 'Bảo tàng Lịch sử TP.HCM',
  description: 'Nội dung do API cung cấp.',
  address: 'Thành phố Hồ Chí Minh',
  latitude: 10.7875,
  longitude: 106.7021,
);

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

void main() {
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

    // The site list must still open the detail page.
    await tester.tap(find.text(_site.name));
    await tester.pumpAndSettle();

    expect(find.text('Nội dung do API cung cấp.'), findsOneWidget);
  });

  testWidgets('Tapping a map marker shows a preview without opening details', (
    tester,
  ) async {
    final api = _FakeSiteApi()..sites = const [_site];

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('selected-site-card')), findsNothing);

    await tester.tap(find.byKey(_firstMarkerKey));
    await tester.pumpAndSettle();

    // The map remains visible.
    expect(find.byType(FlutterMap), findsOneWidget);

    // The preview contains the selected site's information.
    expect(find.byKey(const ValueKey('selected-site-card')), findsOneWidget);
    expect(find.text(_site.name), findsNWidgets(2));
    expect(find.text(_site.address!), findsWidgets);

    // Details are not opened automatically.
    expect(find.text('Nội dung do API cung cấp.'), findsNothing);

    expect(find.byKey(const ValueKey('selected-site-details')), findsOneWidget);
  });

  testWidgets('Preview card can be closed and reopened', (tester) async {
    final api = _FakeSiteApi()..sites = const [_site];

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_firstMarkerKey));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('selected-site-card')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('close-site-card')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('selected-site-card')), findsNothing);

    // The same marker can be selected again.
    await tester.tap(find.byKey(_firstMarkerKey));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('selected-site-card')), findsOneWidget);
  });

  testWidgets('Selecting another marker updates the preview card', (
    tester,
  ) async {
    final api = _FakeSiteApi()..sites = const [_site, _secondSite];

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    // Select the first marker.
    await tester.tap(find.byKey(_firstMarkerKey));
    await tester.pumpAndSettle();

    final previewCard = find.byKey(const ValueKey('selected-site-card'));

    expect(previewCard, findsOneWidget);

    // The first site is displayed inside the preview.
    expect(
      find.descendant(of: previewCard, matching: find.text(_site.name)),
      findsOneWidget,
    );

    // Select the second marker.
    await tester.tap(find.byKey(_secondMarkerKey));
    await tester.pumpAndSettle();

    expect(previewCard, findsOneWidget);

    // The preview updates to the second site.
    expect(
      find.descendant(of: previewCard, matching: find.text(_secondSite.name)),
      findsOneWidget,
    );

    // The first site must no longer be in the preview.
    expect(
      find.descendant(of: previewCard, matching: find.text(_site.name)),
      findsNothing,
    );
  });

  testWidgets('View details button opens the selected site', (tester) async {
    final api = _FakeSiteApi()..sites = const [_site];

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_firstMarkerKey));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('selected-site-card')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('selected-site-details')));
    await tester.pumpAndSettle();

    expect(find.text('Nội dung do API cung cấp.'), findsOneWidget);
    expect(find.text('Chi tiết địa điểm'), findsOneWidget);
  });

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
}

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
