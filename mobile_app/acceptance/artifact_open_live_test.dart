// Opt-in widget + real HTTP + SQL acceptance; never uses a mock API/client.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/features/artifacts/artifact.dart';
import 'package:flutter_application_1/features/artifacts/artifact_detail_page.dart';
import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/auth/auth_session.dart';
import 'package:flutter_application_1/features/data/visitor_api_service.dart';
import 'package:flutter_application_1/l10n/app_strings.dart';

String _env(String key) {
  final value = Platform.environment[key];
  if (value == null || value.isEmpty) {
    throw StateError('Set $key for isolated QA');
  }
  return value;
}

// The widget-test default HTTP override returns fake 400 responses. This
// opt-in harness explicitly restores real sockets to the loopback QA server.
class _RealNetwork extends HttpOverrides {}

class _TrackingClient extends http.BaseClient {
  final _inner = http.Client();
  final visitStatuses = <int>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (request.method == 'POST' && request.url.path == '/api/v1/visits/') {
      visitStatuses.add(response.statusCode);
    }
    return response;
  }

  @override
  void close() => _inner.close();
}

void main() {
  testWidgets(
    'opening real Web content records 201; reopening in 300 seconds reuses 200',
    (tester) async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final origin = Uri.parse(_env('QA_API_URL'));
        expect(['localhost', '127.0.0.1'], contains(origin.host));
        final graph = jsonDecode(
          File(_env('QA_HANDOFF_FILE')).readAsStringSync(),
        ) as Map<String, dynamic>;
        final artifactId = graph['artifact']['id'] as String;
        final auth = AuthService(baseUrl: origin, client: IoAuthHttpClient());
        final network = _TrackingClient();
        final api = HttpVisitorApi(baseUrl: origin, client: network);
        // Keep control queries in the real async zone. Reusing the widget's
        // pooled connection from runAsync can stall fake-zone callbacks.
        final control = (await tester.runAsync(
          () async => HttpVisitorApi(baseUrl: origin),
        ))!;
        final steps = <Map<String, dynamic>>[];
        final results = <String, dynamic>{'checks': steps};
        final resultFile = File(_env('QA_MOBILE_RESULTS_FILE'));
        void save() => resultFile.writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(results)}\n',
        );
        Future<void> waitForVisitCount(int count) async {
          for (var attempt = 0; attempt < 100; attempt++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump();
            if (network.visitStatuses.length == count) return;
          }
          fail(
            'Expected $count actual POST /visits responses, got ${network.visitStatuses}',
          );
        }

        try {
          final email =
              'qa-open-${DateTime.now().microsecondsSinceEpoch}@example.com';
          final random = Random.secure();
          final password = List.generate(
            32,
            (_) => random.nextInt(16).toRadixString(16),
          ).join();
          final user = (await tester.runAsync(
            () => auth.register(email: email, password: password),
          ))!;
          final token = (await tester.runAsync(
            () => auth.login(email: email, password: password),
          ))!;
          final session = AuthSession()..authenticate(token);
          final artifact = Artifact(
            id: artifactId,
            titleVi: 'Preview',
            titleEn: 'Preview',
            period: '',
            category: '',
            location: '',
            descriptionVi: '',
            descriptionEn: '',
            imageUrl: '',
          );
          final before = await tester.runAsync(
            () => control.loadVisits(token: token, languageCode: 'vi'),
          );
          expect(before!.items, isEmpty);
          await tester.runAsync(
            () => control.addFavorite(token: token, artifactId: artifactId),
          );
          await tester.pumpWidget(
            AuthSessionScope(
              session: session,
              child: MaterialApp(
                locale: const Locale('vi'),
                supportedLocales: const [Locale('vi'), Locale('en')],
                localizationsDelegates: const [
                  AppStrings.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => ArtifactDetailPage(
                            artifact: artifact,
                            visitorApi: api,
                          ),
                        ),
                      ),
                      child: const Text('Open real artifact'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(network.visitStatuses, isEmpty);
          steps.add({
            'id': 'OPEN-LIVE-01',
            'status': 'PASS',
            'detail': 'No visit before opening the detail route',
          });
          await tester.tap(find.text('Open real artifact'));
          await waitForVisitCount(1);
          await tester.pumpAndSettle();
          expect(network.visitStatuses, [201]);
          expect(find.text(graph['updatedTitle'] as String), findsOneWidget);
          final first = (await tester.runAsync(
            () => control.loadVisits(token: token, languageCode: 'vi'),
          ))!.items.single;
          expect(first.artifactId, artifactId);
          results.addAll({
            'user_id': user.id,
            'artifact_id': artifactId,
            'site_id': graph['site']['id'],
            'visit_id': first.id,
            'visited_at_utc': first.visitedAt!.toIso8601String(),
          });
          steps.add({
            'id': 'OPEN-LIVE-02',
            'status': 'PASS',
            'detail': 'Actual detail widget loaded Web content, rendered it and recorded HTTP 201',
          });
          await tester.tap(find.byIcon(Icons.arrow_back_rounded));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Open real artifact'));
          await waitForVisitCount(2);
          await tester.pumpAndSettle();
          expect(network.visitStatuses, [201, 200]);
          final reopened = (await tester.runAsync(
            () => control.loadVisits(token: token, languageCode: 'vi'),
          ))!.items;
          expect(reopened.single.id, first.id);
          steps.add({
            'id': 'OPEN-LIVE-03',
            'status': 'PASS',
            'detail': 'Reopening sent another real request; server returned 200 with the same persisted visit',
          });
          results['http_visit_statuses'] = network.visitStatuses;
          save();
          // Manual opens intentionally omit beacon_id/rssi. Verify directly with
          // the read-only QA checker rather than inferring persistence from UI.
          final sql = await tester.runAsync(
            () => Process.run(_env('QA_PYTHON'), [
              _env('QA_SQL_ASSERT_SCRIPT'),
              'artifact-opened',
            ]),
          );
          expect(sql!.exitCode, 0, reason: '${sql.stdout}\n${sql.stderr}');
          steps.add({
            'id': 'OPEN-LIVE-04',
            'status': 'PASS',
            'detail': 'Identity-verified SQL SELECT confirmed one visit, matching user/artifact/timestamp',
          });
          save();
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          api.close();
          control.close();
          network.close();
          auth.close();
        }
      }, _RealNetwork());
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
