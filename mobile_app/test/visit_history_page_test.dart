import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/auth/auth_session.dart';
import 'package:flutter_application_1/features/data/visitor_api_service.dart';
import 'package:flutter_application_1/features/home/history_page.dart';
import 'package:flutter_application_1/l10n/app_strings.dart';

const _token = AuthToken(
  accessToken: 'history-test-token',
  tokenType: 'bearer',
);
const _visitId = '80000000-0000-0000-0000-000000000001';
const _userId = '50000000-0000-0000-0000-000000000001';
const _artifactId = '70000000-0000-0000-0000-000000000001';
const _siteId = '10000000-0000-0000-0000-000000000001';

Map<String, Object?> _visitPayload(String title) => {
  'data': [
    {
      'id': _visitId,
      'user_id': _userId,
      'artifact_id': _artifactId,
      'beacon_id': null,
      'language_id': null,
      'visited_at': '2026-11-01T12:30:00',
      'duration_seconds': null,
      'rssi': null,
      'artifact': {
        'id': _artifactId,
        'site_id': _siteId,
        'code': 'ART-HISTORY-1',
        'era': 'Bronze Age',
        'latitude': null,
        'longitude': null,
        'cover_image_url': null,
        'is_active': true,
        'title': title,
        'language_code': 'vi',
        'is_fallback': false,
      },
    },
  ],
  'count': 1,
};

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('vi'),
  supportedLocales: const [Locale('vi'), Locale('en')],
  localizationsDelegates: const [
    AppStrings.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

void main() {
  testWidgets('History uses HttpVisitorApi and refreshes backend data', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode(_visitPayload('History artifact')),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = HttpVisitorApi(
      baseUrl: Uri.parse('http://localhost:8000'),
      client: client,
    );
    final session = AuthSession()..authenticate(_token);
    addTearDown(() {
      api.close();
      client.close();
      session.dispose();
    });

    await tester.pumpWidget(
      _app(AuthSessionScope(session: session, child: HistoryPage(api: api))),
    );
    await tester.pumpAndSettle();

    expect(find.text('History artifact'), findsOneWidget);
    expect(find.text('Tổng lượt xem: 1'), findsOneWidget);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/api/v1/visits/me');
    expect(requests.single.url.queryParameters, {
      'lang': 'vi',
      'skip': '0',
      'limit': '20',
    });
    expect(
      requests.single.headers['authorization'],
      'Bearer history-test-token',
    );

    await tester.tap(find.byTooltip('Làm mới'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('History does not call the API without a session', (
    tester,
  ) async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      return http.Response('{}', 200);
    });
    final api = HttpVisitorApi(
      baseUrl: Uri.parse('http://localhost:8000'),
      client: client,
    );
    final session = AuthSession();
    addTearDown(() {
      api.close();
      client.close();
      session.dispose();
    });

    await tester.pumpWidget(
      _app(AuthSessionScope(session: session, child: HistoryPage(api: api))),
    );
    await tester.pumpAndSettle();

    expect(requestCount, 0);
    expect(
      find.text('Vui lòng đăng nhập để tải lịch sử tham quan.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
