import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  testWidgets('Map tab uses real Sites and opens their API-backed details', (
    tester,
  ) async {
    final api = _FakeSiteApi()..sites = const [_site];

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Bản đồ nền và vị trí trực tiếp'),
      findsOneWidget,
    );
    expect(find.text(_site.name), findsOneWidget);
    expect(find.textContaining('10.7875, 106.7021'), findsOneWidget);
    expect(find.text('Văn Miếu - Quốc Tử Giám'), findsNothing);

    await tester.tap(find.text(_site.name));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung do API cung cấp.'), findsOneWidget);
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
          home: MapPage(siteApi: api),
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
  home: MapPage(siteApi: api),
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
    return _site;
  }
}
