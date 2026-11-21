import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/home/home_page.dart';
import 'package:flutter_application_1/features/home/profile_page.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  Future<void> openLogin(
    WidgetTester tester,
    _FakeAuthHttpClient client,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MyApp(
        authService: AuthService(
          baseUrl: Uri.parse('https://example.test'),
          client: client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('welcome-skip')));
    await tester.pumpAndSettle();
  }

  Future<void> goBackFromBeaconTools(WidgetTester tester) async {
    final backButton = find
        .descendant(
          of: find.byType(AppShell),
          matching: find.byType(BackButton),
        )
        .hitTestable();

    expect(backButton, findsOneWidget);

    await tester.tap(backButton);
    await tester.pumpAndSettle();
  }

  testWidgets('Home and Profile open real iBeacon scanner', (
    WidgetTester tester,
  ) async {
    final client = _FakeAuthHttpClient();

    try {
      await openLogin(tester, client);

      await tester.enterText(
        find.byKey(const Key('login-email')),
        'visitor@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'password123',
      );

      final submit = find.byKey(const Key('login-submit'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Thuyết minh iBeacon'));
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(BeaconTestPage), findsOneWidget);
      expect(find.text('Bắt đầu quét'), findsOneWidget);

      // Simulation mode must not appear in the interface.
      expect(find.text('SIMULATION MODE'), findsNothing);
      expect(find.text('Mô phỏng'), findsNothing);
      expect(find.byIcon(Icons.science_outlined), findsNothing);

      await goBackFromBeaconTools(tester);

      expect(find.byType(HomePage), findsOneWidget);

      final banner = find.text('Trải nghiệm Smart Heritage');
      await tester.ensureVisible(banner);
      await tester.pumpAndSettle();
      await tester.tap(banner);
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(BeaconTestPage), findsOneWidget);

      await goBackFromBeaconTools(tester);

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();

      expect(find.byType(ProfilePage), findsOneWidget);

      final profileEntry = find.text('Thuyết minh iBeacon tự động');
      await tester.ensureVisible(profileEntry);
      await tester.pumpAndSettle();
      await tester.tap(profileEntry);
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(BeaconTestPage), findsOneWidget);

      await goBackFromBeaconTools(tester);

      expect(find.byType(ProfilePage), findsOneWidget);
      expect(client.calls, 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('Real iBeacon scanner receives login token', (
    WidgetTester tester,
  ) async {
    final client = _FakeAuthHttpClient();

    try {
      await openLogin(tester, client);

      await tester.enterText(
        find.byKey(const Key('login-email')),
        'visitor@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'password123',
      );

      final submit = find.byKey(const Key('login-submit'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Thuyết minh iBeacon'));
      await tester.pumpAndSettle();

      final scanner = tester.widget<BeaconTestPage>(
        find.byType(BeaconTestPage),
      );

      expect(scanner.readToken, isNotNull);
      expect(scanner.readToken!()?.accessToken, 'test-token');
      expect(scanner.languageCode, 'vi');
      expect(client.calls, 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

class _FakeAuthHttpClient implements AuthHttpClient {
  int calls = 0;

  @override
  Future<AuthHttpResponse> post(
    Uri requestUri, {
    required String contentType,
    required String body,
  }) async {
    calls++;

    return const AuthHttpResponse(
      statusCode: 200,
      body: '{"access_token":"test-token","token_type":"bearer"}',
    );
  }
}
