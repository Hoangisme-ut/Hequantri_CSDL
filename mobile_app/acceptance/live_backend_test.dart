// Opt-in real-network acceptance. Not part of the isolated unit/widget suite.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/beacon/beacon_content_service.dart';
import 'package:flutter_application_1/features/data/visitor_api_service.dart';

String requiredEnv(String key) {
  final value = Platform.environment[key];
  if (value == null || value.isEmpty) {
    throw StateError(
      'Set $key; see docs/qa/web-mobile-sqlserver-acceptance.md',
    );
  }
  return value;
}

void main() {
  test(
    'real Web data -> Flutter clients -> SQL Server, with per-user state',
    () async {
      final origin = Uri.parse(requiredEnv('QA_API_URL'));
      expect(['127.0.0.1', 'localhost'], contains(origin.host));
      final graph = jsonDecode(
        await File(requiredEnv('QA_HANDOFF_FILE')).readAsString(),
      ) as Map<String, dynamic>;
      final artifactId = graph['artifact']['id'] as String;
      final siteId = graph['site']['id'] as String;
      final beacon = graph['beacon'] as Map<String, dynamic>;
      final transport = IoAuthHttpClient();
      final auth = AuthService(baseUrl: origin, client: transport);
      final api = HttpVisitorApi(baseUrl: origin);
      final resolver = BeaconContentService(baseUrl: origin);
      final results = <Map<String, dynamic>>[];
      final receipt = <String, dynamic>{'checks': results};
      final resultFile = File(requiredEnv('QA_MOBILE_RESULTS_FILE'));
      Future<void> save() => resultFile.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(receipt)}\n',
      );
      Future<void> record(String id, String detail) async {
        results.add({'id': id, 'status': 'PASS', 'detail': detail});
        await save();
      }

      Future<void> verifySql(String phase) async {
        await save();
        final result = await Process.run(requiredEnv('QA_PYTHON'), [
          requiredEnv('QA_SQL_ASSERT_SCRIPT'),
          phase,
        ]);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        await record(
          'SQL-$phase',
          'Direct SQL Server SELECT assertions passed',
        );
      }

      try {
        final sites = await api.loadSites(languageCode: 'vi');
        expect(sites.items.map((s) => s.id), contains(siteId));
        await record(
          'MB-01-client',
          'Real Site list includes Web-created Site ID',
        );
        final artifacts = await api.loadArtifacts(languageCode: 'vi');
        expect(artifacts.items.map((a) => a.id), contains(artifactId));
        await record(
          'MB-02-client',
          'Real Artifact list includes Web-created Artifact ID',
        );
        final vi = await api.loadArtifact(
          artifactId: artifactId,
          languageCode: 'vi',
        );
        final en = await api.loadArtifact(
          artifactId: artifactId,
          languageCode: 'en',
        );
        expect(vi.siteId, siteId);
        expect(vi.title, graph['updatedTitle']);
        expect(en.title, 'Acceptance bronze drum');
        expect(vi.languageCode, 'vi');
        expect(en.languageCode, 'en');
        expect(vi.isFallback || en.isFallback, false);
        await record(
          'MB-03-05-client',
          'Flutter received updated Web text and correct vi/en translations',
        );
        final imageUrl = vi.media
            .singleWhere((m) => m.url == graph['image'])
            .url;
        final image = await http.get(Uri.parse(imageUrl));
        expect(image.statusCode, 200);
        final codec = await ui.instantiateImageCodec(image.bodyBytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        expect(frame.image.height, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
        await record(
          'MB-06-decode',
          'Actual HTTP JPEG bytes decoded by Flutter engine; device display unverified',
        );

        final unique = DateTime.now().microsecondsSinceEpoch;
        final random = Random.secure();
        final password = List.generate(
          32,
          (_) => random.nextInt(16).toRadixString(16),
        ).join();
        final emailA = 'qa-a-$unique@example.com';
        final emailB = 'qa-b-$unique@example.com';
        final userA = await auth.register(email: emailA, password: password);
        await auth.register(email: emailB, password: password);
        final tokenA = await auth.login(email: emailA, password: password);
        final tokenB = await auth.login(email: emailB, password: password);
        final resolved = await resolver.resolve(
          proximityUuid: beacon['proximity_uuid'] as String,
          major: beacon['major'] as int,
          minor: beacon['minor'] as int,
          token: tokenA,
          languageCode: 'vi',
        );
        expect(resolved.artifactId, artifactId);
        expect(resolved.siteId, siteId);
        expect(resolved.title, vi.title);
        expect(
          (await api.loadVisits(token: tokenA, languageCode: 'vi')).items,
          isEmpty,
        );
        await record(
          'MB-08-client',
          'Beacon resolves Web mapping without recording an incidental visit',
        );
        await api.addFavorite(token: tokenA, artifactId: artifactId);
        final visit = await api.recordVisit(
          token: tokenA,
          artifactId: artifactId,
          beaconId: resolved.beaconId,
          rssi: -60,
        );
        expect(visit.wasCreated, true);
        receipt.addAll({
          'user_id': userA.id,
          'artifact_id': artifactId,
          'site_id': siteId,
          'visit_id': visit.id,
          'visited_at_utc': visit.visitedAt!.toUtc().toIso8601String(),
        });
        final replay = await api.recordVisit(
          token: tokenA,
          artifactId: artifactId,
          beaconId: resolved.beaconId,
        );
        expect(replay.wasCreated, false);
        expect(replay.id, visit.id);
        final relogin = await auth.login(email: emailA, password: password);
        final favorites = await api.loadFavorites(
          token: relogin,
          languageCode: 'vi',
        );
        final history = await api.loadVisits(
          token: relogin,
          languageCode: 'vi',
        );
        expect(favorites.items.single.artifactId, artifactId);
        expect(history.items.single.id, visit.id);
        expect(history.items.single.visitedAt!.isUtc, true);
        expect(
          (await api.loadFavorites(token: tokenB, languageCode: 'vi')).items,
          isEmpty,
        );
        expect(
          (await api.loadVisits(token: tokenB, languageCode: 'vi')).items,
          isEmpty,
        );
        await record(
          'FAV-HIST-01',
          'Favorite/History persist after re-login, replay is reused, user B has no private records',
        );
        await verifySql('favorite-added');
        await api.removeFavorite(token: relogin, artifactId: artifactId);
        expect(
          (await api.loadFavorites(token: relogin, languageCode: 'vi')).items,
          isEmpty,
        );
        await verifySql('favorite-removed');
        await expectLater(
          api.loadArtifact(
            artifactId: '00000000-0000-0000-0000-000000000000',
            languageCode: 'vi',
          ),
          throwsA(
            isA<VisitorApiException>().having(
              (e) => e.statusCode,
              'status',
              404,
            ),
          ),
        );
        await record(
          'MB-09-client',
          'Real 404 mapped to the expected client error; UI error rendering covered separately',
        );
      } finally {
        api.close();
        resolver.close();
        auth.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
