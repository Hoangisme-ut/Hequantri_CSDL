import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/auth/login_page.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  Future<void> openLogin(
    WidgetTester tester,
    _FakeAuthHttpClient client, {
    ValueChanged<AuthToken>? onAuthenticated,
    VoidCallback? onLoginSuccess,
    VoidCallback? onDemoContinue,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LoginPage(
          authService: AuthService(
            baseUrl: Uri.parse('https://example.test'),
            client: client,
          ),
          onAuthenticated: onAuthenticated,
          onLoginSuccess: onLoginSuccess,
          onDemoContinue: onDemoContinue,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submitLogin(WidgetTester tester) async {
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
  }

  testWidgets('passes the token without calling legacy navigation', (
    tester,
  ) async {
    final client = _FakeAuthHttpClient(
      const AuthHttpResponse(
        statusCode: 200,
        body: '{"access_token":"test-token","token_type":"bearer"}',
      ),
    );
    final received = <AuthToken>[];
    var legacyCalled = false;
    var demoCalled = false;

    await openLogin(
      tester,
      client,
      onAuthenticated: received.add,
      onLoginSuccess: () => legacyCalled = true,
      onDemoContinue: () => demoCalled = true,
    );
    await submitLogin(tester);

    expect(client.calls, 1);
    expect(received, hasLength(1));
    expect(received.single.accessToken, 'test-token');
    expect(received.single.tokenType, 'bearer');
    expect(legacyCalled, isFalse);
    expect(demoCalled, isFalse);
  });

  testWidgets('rejects an empty token before navigation', (tester) async {
    final client = _FakeAuthHttpClient(
      const AuthHttpResponse(
        statusCode: 200,
        body: '{"access_token":"","token_type":"bearer"}',
      ),
    );
    var authenticated = false;
    var navigated = false;

    await openLogin(
      tester,
      client,
      onAuthenticated: (_) => authenticated = true,
      onLoginSuccess: () => navigated = true,
    );
    await submitLogin(tester);

    expect(client.calls, 1);
    expect(authenticated, isFalse);
    expect(navigated, isFalse);
    expect(
      find.text('Máy chủ trả về thông tin đăng nhập không hợp lệ.'),
      findsOneWidget,
    );
  });

  testWidgets('demo does not request or emit an authentication token', (
    tester,
  ) async {
    final client = _FakeAuthHttpClient(
      const AuthHttpResponse(statusCode: 500, body: '{}'),
    );
    var authenticated = false;
    var demoCalled = false;

    await openLogin(
      tester,
      client,
      onAuthenticated: (_) => authenticated = true,
      onDemoContinue: () => demoCalled = true,
    );

    final demo = find.byKey(const Key('login-demo-preview'));
    await tester.ensureVisible(demo);
    await tester.pumpAndSettle();
    await tester.tap(demo);
    await tester.pumpAndSettle();

    expect(client.calls, 0);
    expect(authenticated, isFalse);
    expect(demoCalled, isTrue);
  });
}

class _FakeAuthHttpClient implements AuthHttpClient {
  _FakeAuthHttpClient(this.response);

  final AuthHttpResponse response;
  int calls = 0;

  @override
  Future<AuthHttpResponse> post(
    Uri requestUri, {
    required String contentType,
    required String body,
  }) async {
    calls++;
    return response;
  }
}
