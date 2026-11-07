import 'dart:async';

import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import 'package:flutter/foundation.dart' as platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/beacon/beacon_content_service.dart';
import 'package:flutter_application_1/features/beacon/beacon_scanner.dart';
import 'package:flutter_application_1/features/beacon/beacon_tools_page.dart';

Beacon _a() => Beacon(
  proximityUUID: heritageBeaconUuid,
  major: 1,
  minor: 1,
  rssi: -55,
  accuracy: 1,
);

class _Scanner extends BeaconScanner {
  final source = StreamController<List<Beacon>>.broadcast();
  final bluetooth = StreamController<BluetoothState>.broadcast();
  final authorization = StreamController<AuthorizationStatus>.broadcast();

  String? problem;

  @override
  Future<void> prepare() => checkReady();

  @override
  Future<void> checkReady() async {
    if (problem != null) {
      throw BeaconScanException(problem!);
    }
  }

  @override
  Stream<List<Beacon>> get detections => source.stream;

  @override
  Stream<BluetoothState> get bluetoothChanges => bluetooth.stream;

  @override
  Stream<AuthorizationStatus> get authorizationChanges => authorization.stream;

  Future<void> close() async {
    await source.close();
    await bluetooth.close();
    await authorization.close();
  }
}

class _Content extends BeaconContentService {
  _Content() : super(baseUrl: Uri.parse('https://example.test'));

  int calls = 0;
  Completer<BeaconContent>? pending;

  final result = const BeaconContent(
    beaconId: 'beacon-a',
    artifactId: 'artifact-a',
    siteId: 'site',
    code: 'A',
    title: 'Nội dung A',
  );

  @override
  Future<BeaconContent> resolve({
    required String proximityUuid,
    required int major,
    required int minor,
    required AuthToken token,
    String? languageCode,
  }) async {
    calls++;
    return pending == null ? result : await pending!.future;
  }
}

Future<void> _open(
  WidgetTester tester,
  _Scanner scanner,
  _Content content,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BeaconTestPage(
        scanner: scanner,
        contentService: content,
        readToken: () =>
            const AuthToken(accessToken: 'test', tokenType: 'bearer'),
      ),
    ),
  );

  await tester.tap(find.text('Bắt đầu quét'));
  await tester.pump();
}

/// Trạng thái thông báo và bộ đếm nằm trong ExpansionTile.
/// Cần mở mục này trước khi kiểm tra các nội dung bên trong.
Future<void> _openTechnicalDetails(WidgetTester tester) async {
  final pageContext = tester.element(find.byType(BeaconTestPage));

  ScaffoldMessenger.of(pageContext).clearSnackBars();
  await tester.pumpAndSettle();

  final title = find.text('Thông tin kỹ thuật');

  final scrollable = find
      .descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      )
      .first;

  await tester.scrollUntilVisible(title, 120, scrollable: scrollable);
  await tester.pumpAndSettle();

  await Scrollable.ensureVisible(tester.element(title), alignment: 0.3);
  await tester.pumpAndSettle();

  final tile = find.widgetWithText(ExpansionTile, 'Thông tin kỹ thuật');

  final counter = find.descendant(
    of: tile,
    matching: find.textContaining('Lần báo mới:'),
  );

  // Nếu đang mở thì giữ nguyên, tránh bấm làm đóng lại.
  if (counter.evaluate().isEmpty) {
    expect(
      title.hitTestable(),
      findsOneWidget,
      reason: 'Tiêu đề Thông tin kỹ thuật phải nhận được thao tác bấm.',
    );

    await tester.tap(title.hitTestable());
    await tester.pumpAndSettle();
  }

  expect(
    counter,
    findsOneWidget,
    reason: 'Mục Thông tin kỹ thuật phải hiển thị bộ đếm.',
  );

  await tester.ensureVisible(counter);
  await tester.pumpAndSettle();
}

Future<void> _waitForStopped(WidgetTester tester, _Scanner scanner) async {
  final state = tester.state<BeaconTestPageState>(find.byType(BeaconTestPage));

  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(Duration.zero);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    if (!state.isBusy &&
        !scanner.source.hasListener &&
        !scanner.bluetooth.hasListener &&
        !scanner.authorization.hasListener) {
      await tester.pump(Duration.zero);
      return;
    }
  }

  fail('Scan cancellation did not complete.');
}

Future<void> _cleanup(
  WidgetTester tester,
  _Scanner scanner,
  _Content content,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await scanner.close();
  content.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('iOS ranging is restricted to the configured UUID', () {
    final ios = BeaconScanner.regions(isIOS: true).single;

    expect(ios.proximityUUID, heritageBeaconUuid);
    expect(ios.major, isNull);
    expect(ios.minor, isNull);
    expect(BeaconScanner.regions(isIOS: false).single.proximityUUID, isNull);
  });

  group('native preflight', () {
    const channel = MethodChannel('flutter_beacon');

    var authorized = 'ALLOWED';
    var bluetooth = 'STATE_ON';
    var location = true;

    final methods = <MethodCall>[];

    setUp(() {
      platform.debugDefaultTargetPlatformOverride =
          platform.TargetPlatform.android;

      authorized = 'ALLOWED';
      bluetooth = 'STATE_ON';
      location = true;
      methods.clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call);

            return switch (call.method) {
              'authorizationStatus' => authorized,
              'bluetoothState' => bluetooth,
              'checkLocationServicesIfEnabled' => location,
              'initializeAndCheck' => null,
              _ => true,
            };
          });
    });

    tearDown(() {
      platform.debugDefaultTargetPlatformOverride = null;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('denied permission prevents ranging initialization', () async {
      authorized = 'DENIED';

      await expectLater(
        BeaconScanner().prepare(),
        throwsA(isA<BeaconScanException>()),
      );

      expect(methods.any((call) => call.method == 'initialize'), isFalse);
    });

    test('Bluetooth off prevents ranging initialization', () async {
      bluetooth = 'STATE_OFF';

      await expectLater(
        BeaconScanner().prepare(),
        throwsA(isA<BeaconScanException>()),
      );

      expect(methods.any((call) => call.method == 'initialize'), isFalse);
    });

    test('Location Services off prevents ranging initialization', () async {
      location = false;

      await expectLater(
        BeaconScanner().prepare(),
        throwsA(isA<BeaconScanException>()),
      );

      expect(methods.any((call) => call.method == 'initialize'), isFalse);
    });

    test(
      'iOS requests foreground authorization and checks actual state',
      () async {
        platform.debugDefaultTargetPlatformOverride =
            platform.TargetPlatform.iOS;

        authorized = 'WHEN_IN_USE';

        await BeaconScanner().prepare();

        expect(methods.first.method, 'setLocationAuthorizationTypeDefault');
        expect(methods.first.arguments, 'WHEN_IN_USE');
        expect(
          methods.any((call) => call.method == 'initializeAndCheck'),
          isTrue,
        );
      },
    );
  });

  testWidgets('denied startup remains retryable and creates no API request', (
    tester,
  ) async {
    final scanner = _Scanner()..problem = 'Chưa được cấp quyền quét.';
    final content = _Content();

    try {
      await _open(tester, scanner, content);

      expect(find.text('Chưa được cấp quyền quét.'), findsOneWidget);
      expect(scanner.source.hasListener, isFalse);
      expect(content.calls, 0);

      scanner.problem = null;

      await tester.tap(find.text('Bắt đầu quét'));
      await tester.pump();

      expect(scanner.source.hasListener, isTrue);

      scanner.source.add([_a()]);
      await tester.pump();

      expect(content.calls, 1);
    } finally {
      await _cleanup(tester, scanner, content);
    }
  });

  testWidgets('Bluetooth off cancels scanning and ignores late content', (
    tester,
  ) async {
    final scanner = _Scanner();
    final content = _Content()..pending = Completer<BeaconContent>();

    try {
      await _open(tester, scanner, content);

      scanner.source.add([_a()]);
      await tester.pump();

      scanner.bluetooth.add(BluetoothState.stateOff);
      await _waitForStopped(tester, scanner);

      expect(scanner.source.hasListener, isFalse);
      expect(scanner.bluetooth.hasListener, isFalse);
      expect(scanner.authorization.hasListener, isFalse);
      expect(find.textContaining('Bluetooth chưa bật'), findsOneWidget);

      content.pending!.complete(content.result);
      await tester.pump();

      expect(find.text('Nội dung A'), findsNothing);

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Bắt đầu quét'),
            )
            .onPressed,
        isNotNull,
      );
    } finally {
      await _cleanup(tester, scanner, content);
    }
  });

  testWidgets('permission revoked ends an active scan', (tester) async {
    final scanner = _Scanner();
    final content = _Content();

    try {
      await _open(tester, scanner, content);

      scanner.authorization.add(AuthorizationStatus.denied);
      await _waitForStopped(tester, scanner);

      expect(scanner.source.hasListener, isFalse);
      expect(find.textContaining('Quyền quét đã bị thu hồi'), findsOneWidget);
      expect(content.calls, 0);
    } finally {
      await _cleanup(tester, scanner, content);
    }
  });

  testWidgets(
    'return from settings rechecks services without requesting permission',
    (tester) async {
      final scanner = _Scanner();
      final content = _Content();

      try {
        await _open(tester, scanner, content);

        scanner.problem = 'Vị trí đang tắt.';

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );

        await _waitForStopped(tester, scanner);

        expect(scanner.source.hasListener, isFalse);
        expect(find.text('Vị trí đang tắt.'), findsOneWidget);
      } finally {
        await _cleanup(tester, scanner, content);
      }
    },
  );

  testWidgets(
    'silent signal loss expires after ten seconds and allows reentry',
    (tester) async {
      final scanner = _Scanner();
      final content = _Content();

      try {
        await _open(tester, scanner, content);

        scanner.source.add([_a()]);
        await tester.pump();

        expect(find.text('Nội dung A'), findsOneWidget);

        await tester.pump(const Duration(seconds: 9));

        expect(find.text('Nội dung A'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Nội dung A'), findsNothing);
        expect(find.byType(SelectableText), findsNothing);

        await _openTechnicalDetails(tester);

        expect(find.textContaining('Đã mất tín hiệu beacon'), findsOneWidget);

        scanner.source.add([_a()]);
        await tester.pumpAndSettle();

        expect(content.calls, 2);
        expect(find.text('Nội dung A'), findsOneWidget);

        // Nội dung vừa tải lại có thể làm thay đổi vị trí mục kỹ thuật.
        await _openTechnicalDetails(tester);

        expect(
          find.text('Lần báo mới: 2 · lần lặp đã chặn: 0'),
          findsOneWidget,
        );
      } finally {
        await _cleanup(tester, scanner, content);
      }
    },
  );

  testWidgets(
    'brief signal gap retains selection and suppresses the repeated beacon',
    (tester) async {
      final scanner = _Scanner();
      final content = _Content();

      try {
        await _open(tester, scanner, content);

        scanner.source.add([_a()]);
        await tester.pump();

        scanner.source.add([]);
        await tester.pump();

        await tester.pump(const Duration(seconds: 8));

        scanner.source.add([_a()]);
        await tester.pump();

        await tester.pump(const Duration(seconds: 3));

        expect(find.text('Nội dung A'), findsOneWidget);
        expect(content.calls, 1);

        await _openTechnicalDetails(tester);

        expect(
          find.text('Lần báo mới: 1 · lần lặp đã chặn: 1'),
          findsOneWidget,
        );
        expect(find.textContaining('không báo lại'), findsOneWidget);
      } finally {
        await _cleanup(tester, scanner, content);
      }
    },
  );

  testWidgets('explicit stop retains raw readings and cancels expiry timers', (
    tester,
  ) async {
    final scanner = _Scanner();
    final content = _Content();

    try {
      await _open(tester, scanner, content);

      scanner.source.add([_a()]);
      await tester.pump();

      await tester.tap(find.text('Dừng quét'));
      await _waitForStopped(tester, scanner);

      await tester.pump(const Duration(seconds: 15));

      expect(
        find.text('Đã dừng quét — hiển thị dữ liệu lần nhận cuối'),
        findsOneWidget,
      );
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text('Nội dung A'), findsNothing);
      expect(scanner.source.hasListener, isFalse);
    } finally {
      await _cleanup(tester, scanner, content);
    }
  });

  testWidgets('ranging failure is recoverable and closes all listeners', (
    tester,
  ) async {
    final scanner = _Scanner();
    final content = _Content();

    try {
      await _open(tester, scanner, content);

      scanner.source.addError(StateError('scanner disconnected'));
      await _waitForStopped(tester, scanner);

      expect(scanner.source.hasListener, isFalse);
      expect(scanner.bluetooth.hasListener, isFalse);
      expect(scanner.authorization.hasListener, isFalse);

      await tester.tap(find.text('Bắt đầu quét'));
      await tester.pump();

      expect(scanner.source.hasListener, isTrue);

      scanner.source.add([_a()]);
      await tester.pump();

      expect(content.calls, 1);
    } finally {
      await _cleanup(tester, scanner, content);
    }
  });
}
