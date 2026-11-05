import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/data/visitor_api_service.dart';
import 'package:flutter_application_1/features/home/home_page.dart';
import 'package:flutter_application_1/features/sites/site_detail_page.dart';
import 'package:flutter_application_1/l10n/app_strings.dart';

const _site = VisitorSite(
  id: '10000000-0000-0000-0000-000000000001',
  name: 'Văn Miếu - Quốc Tử Giám',
  description: 'Khu di tích lịch sử.',
  address: 'Hà Nội',
  latitude: 21.0293,
  longitude: 105.836,
  isActive: true,
);

void main() {
  testWidgets('Home shows loading then the empty Sites state', (tester) async {
    final pending = Completer<VisitorPage<VisitorSite>>();
    final api = _FakeSiteApi()..nextList = pending.future;

    await tester.pumpWidget(_app(api));
    await tester.pump();
    expect(find.text('Địa điểm di sản'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(const VisitorPage(items: [], count: 0));
    await tester.pumpAndSettle();
    expect(find.text('Hiện chưa có địa điểm di sản nào.'), findsOneWidget);
  });

  testWidgets('Home shows a retry action after Sites API failure', (
    tester,
  ) async {
    final api = _FakeSiteApi()
      ..listResults = [
        const VisitorApiException('unavailable', statusCode: 503),
        const VisitorPage(items: [], count: 0),
      ];

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    expect(
      find.text('Máy chủ hiện không khả dụng. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(api.listCalls, 2);
    expect(
      find.text('Máy chủ hiện không khả dụng. Vui lòng thử lại.'),
      findsNothing,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Home can refresh Sites after a successful load', (tester) async {
    final api = _FakeSiteApi()
      ..listResults = [
        const VisitorPage(items: [], count: 0),
        const VisitorPage(items: [_site], count: 1),
      ];

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tải lại địa điểm'));
    await tester.pumpAndSettle();

    expect(api.listCalls, 2);
    expect(find.text(_site.name), findsOneWidget);
  });

  testWidgets('Home reloads Sites when locale changes', (tester) async {
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
          home: HomePage(siteApi: api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.requestedLanguages, ['vi']);

    locale.value = const Locale('en');
    await tester.pumpAndSettle();
    expect(api.requestedLanguages, ['vi', 'en']);
  });

  testWidgets('Site details reload content when locale changes', (
    tester,
  ) async {
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
          home: SiteDetailPage(site: _site, siteApi: api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.requestedLanguages, ['vi']);

    locale.value = const Locale('en');
    await tester.pumpAndSettle();
    expect(api.requestedLanguages, ['vi', 'en']);
  });

  testWidgets('Home lists real Sites and opens API-backed detail', (
    tester,
  ) async {
    final api = _FakeSiteApi()
      ..listResults = [
        const VisitorPage(items: [_site], count: 1),
      ]
      ..detail = _site.copyWith(description: 'Nội dung chi tiết từ API.');

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    expect(find.text(_site.name), findsOneWidget);
    expect(find.text(_site.description!), findsOneWidget);

    await tester.tap(find.text(_site.name));
    await tester.pumpAndSettle();

    expect(api.requestedSiteIds, [_site.id]);
    expect(find.text('Nội dung chi tiết từ API.'), findsOneWidget);
    expect(find.text('Địa chỉ'), findsOneWidget);
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
  home: HomePage(siteApi: api),
);

class _FakeSiteApi implements SiteApi {
  int listCalls = 0;
  Future<VisitorPage<VisitorSite>>? nextList;
  List<Object> listResults = [];
  VisitorSite detail = _site;
  final requestedSiteIds = <String>[];
  final requestedLanguages = <String>[];

  @override
  Future<VisitorPage<VisitorSite>> loadSites({
    required String languageCode,
    int skip = 0,
    int limit = 50,
  }) async {
    listCalls++;
    requestedLanguages.add(languageCode);
    if (nextList != null) return nextList!;
    if (listResults.isEmpty) {
      return const VisitorPage(items: [], count: 0);
    }
    final result = listResults.removeAt(0);
    if (result is Exception) throw result;
    return result as VisitorPage<VisitorSite>;
  }

  @override
  Future<VisitorSite> loadSite({
    required String siteId,
    required String languageCode,
  }) async {
    requestedSiteIds.add(siteId);
    requestedLanguages.add(languageCode);
    return detail;
  }
}

extension on VisitorSite {
  VisitorSite copyWith({String? description}) => VisitorSite(
    id: id,
    name: name,
    description: description ?? this.description,
    address: address,
    latitude: latitude,
    longitude: longitude,
    coverImageUrl: coverImageUrl,
    isActive: isActive,
    languageCode: languageCode,
    isFallback: isFallback,
  );
}
