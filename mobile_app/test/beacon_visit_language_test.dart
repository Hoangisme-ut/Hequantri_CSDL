import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/beacon/beacon_content_controller.dart';
import 'package:flutter_application_1/features/beacon/beacon_content_service.dart';
import 'package:flutter_application_1/features/visits/visit_log_service.dart';

const _token = AuthToken(accessToken: 'visitor-token', tokenType: 'bearer');

const _uuid = 'FDA50693-A4E2-4FB1-AFCF-C6EB07647825';

class _FakeContents extends BeaconContentService {
  _FakeContents() : super(baseUrl: Uri.parse('http://localhost:8000'));

  final pending = <Completer<BeaconContent>>[];

  @override
  Future<BeaconContent> resolve({
    required String proximityUuid,
    required int major,
    required int minor,
    required AuthToken token,
    String? languageCode,
  }) {
    final completer = Completer<BeaconContent>();
    pending.add(completer);
    return completer.future;
  }
}

class _FakeVisits extends VisitLogService {
  _FakeVisits() : super(baseUrl: Uri.parse('http://localhost:8000'));

  final languages = <String?>[];
  final artifacts = <String>[];

  @override
  Future<VisitRecordResult> record({
    required String artifactId,
    required String beaconId,
    required AuthToken token,
    String? languageCode,
    int? rssi,
  }) async {
    artifacts.add(artifactId);
    languages.add(languageCode);

    return VisitRecordResult(
      visit: VisitRecord(
        id: 'visit-${artifacts.length}',
        artifactId: artifactId,
      ),
      alreadyRecorded: false,
    );
  }
}

void _receive(BeaconContentController controller, int minor) {
  controller.receiveBeacon(
    proximityUuid: _uuid,
    major: 1,
    minor: minor,
    languageCode: 'en',
  );
}

void main() {
  testWidgets('VisitLog stores displayed language including fallback', (
    tester,
  ) async {
    final contents = _FakeContents();
    final visits = _FakeVisits();

    final controller = BeaconContentController(
      service: contents,
      visitLogService: visits,
      readToken: () => _token,
      minRequestInterval: Duration.zero,
    );

    try {
      // Case 1: Display English content.
      _receive(controller, 1);

      contents.pending.last.complete(
        const BeaconContent(
          beaconId: 'beacon-1',
          artifactId: 'artifact-1',
          siteId: 'site-1',
          code: 'ART-1',
          title: 'English artifact',
          languageCode: 'en',
        ),
      );

      await tester.pump(Duration.zero);

      // Resolving a Beacon must not automatically record a visit.
      expect(visits.languages, isEmpty);

      await controller.recordDisplayedContent(controller.content!);

      expect(visits.languages, ['en']);

      // The same content must not create a duplicate visit.
      await controller.recordDisplayedContent(controller.content!);

      expect(visits.languages, ['en']);

      // Case 2: English requested, Vietnamese fallback displayed.
      _receive(controller, 2);

      await tester.pump(Duration.zero);

      contents.pending.last.complete(
        const BeaconContent(
          beaconId: 'beacon-2',
          artifactId: 'artifact-2',
          siteId: 'site-1',
          code: 'ART-2',
          title: 'Hiện vật tiếng Việt',
          languageCode: 'vi',
          isFallback: true,
        ),
      );

      await tester.pump(Duration.zero);

      expect(controller.content?.languageCode, 'vi');
      expect(controller.content?.isFallback, isTrue);

      await controller.recordDisplayedContent(controller.content!);

      expect(visits.languages, ['en', 'vi']);

      expect(visits.artifacts, ['artifact-1', 'artifact-2']);
    } finally {
      controller.dispose();
      contents.close();
      visits.close();
    }
  });
}
