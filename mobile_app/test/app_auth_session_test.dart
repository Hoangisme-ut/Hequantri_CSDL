import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/auth/auth_session.dart';
import 'package:flutter_application_1/features/auth/login_page.dart';
import 'package:flutter_application_1/features/home/main_navigation_scaffold.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  const token = AuthToken(accessToken: 'test-token', tokenType: 'bearer');

  test('demo clears the authenticated token', () {
    final session = AuthSession();
    addTearDown(session.dispose);

    session.authenticate(token);

    expect(session.readToken()?.accessToken, 'test-token');
    expect(session.isAuthenticated, isTrue);

    session.enterDemo();

    expect(session.readToken(), isNull);
    expect(session.isAuthenticated, isFalse);
    expect(session.isDemoSession, isTrue);
  });

  test('logout clears authentication and demo state', () {
    final session = AuthSession();
    addTearDown(session.dispose);

    session.authenticate(token);
    session.clear();

    expect(session.readToken(), isNull);
    expect(session.isAuthenticated, isFalse);
    expect(session.isDemoSession, isFalse);

    session.enterDemo();
    session.clear();

    expect(session.isDemoSession, isFalse);
  });

  test('invalid tokens cannot create an authenticated session', () {
    final session = AuthSession();
    addTearDown(session.dispose);

    expect(
      () => session.authenticate(
        const AuthToken(accessToken: '', tokenType: 'bearer'),
      ),
      throwsArgumentError,
    );

    expect(
      () => session.authenticate(
        const AuthToken(accessToken: 'test-token', tokenType: 'unknown'),
      ),
      throwsArgumentError,
    );

    expect(session.readToken(), isNull);
  });

  testWidgets('welcome login logout and demo share the correct session', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _FakeAuthHttpClient();

    try {
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

      final mainPage = find.byType(MainNavigationScaffold);

      expect(mainPage, findsOneWidget);
      expect(client.calls, 1);

      final session = AuthSessionScope.of(tester.element(mainPage));

      expect(session.readToken()?.accessToken, 'test-token');
      expect(session.isAuthenticated, isTrue);
      expect(session.isDemoSession, isFalse);

      tester.widget<MainNavigationScaffold>(mainPage).onLogout!();
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(session.readToken(), isNull);
      expect(session.isDemoSession, isFalse);

      final demo = find.byKey(const Key('login-demo-preview'));
      await tester.ensureVisible(demo);
      await tester.pumpAndSettle();
      await tester.tap(demo);
      await tester.pumpAndSettle();

      expect(find.byType(MainNavigationScaffold), findsOneWidget);
      expect(session.readToken(), isNull);
      expect(session.isDemoSession, isTrue);
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
