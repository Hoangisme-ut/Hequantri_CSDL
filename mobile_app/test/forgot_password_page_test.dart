import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/auth/forgot_password_page.dart';
import 'package:flutter_application_1/l10n/app_strings.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    FakeAuthHttpClient client, {
    Locale locale = const Locale('vi'),
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        home: ForgotPasswordPage(
          authService: AuthService(
            baseUrl: Uri.parse('https://api.example.test'),
            client: client,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submitEmail(WidgetTester tester, String email) async {
    await tester.enterText(
      find.byKey(const Key('forgot-password-email')),
      email,
    );
    await tester.tap(find.byKey(const Key('forgot-password-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('valid email submits and shows privacy-safe generic success', (
    tester,
  ) async {
    final client = FakeAuthHttpClient(
      const AuthHttpResponse(
        statusCode: 200,
        body: '{"message":"If that email is registered, we sent a password recovery link"}',
      ),
    );
    await pumpPage(tester, client);

    await submitEmail(tester, 'visitor@example.com');

    expect(client.requestCount, 1);
    expect(find.byKey(const Key('forgot-password-success')), findsOneWidget);
    expect(
      find.text(
        'Nếu email này đã đăng ký, hướng dẫn khôi phục sẽ được gửi đến bạn.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('ki?m tra h?p th?'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('forgot-password-submit')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('empty, malformed and phone input do not call the API', (
    tester,
  ) async {
    final client = FakeAuthHttpClient(
      const AuthHttpResponse(statusCode: 200, body: '{"message":"ok"}'),
    );
    await pumpPage(tester, client);

    await submitEmail(tester, '');
    expect(find.text('Vui lòng nhập email.'), findsOneWidget);
    await submitEmail(tester, 'not-an-email');
    expect(find.text('Email không hợp lệ.'), findsOneWidget);
    await submitEmail(tester, '0123456789');
    expect(find.text('Email không hợp lệ.'), findsOneWidget);
    expect(client.requestCount, 0);
    expect(find.byKey(const Key('forgot-password-success')), findsNothing);
  });

  testWidgets('server failure displays error and ends loading', (tester) async {
    final client = FakeAuthHttpClient(
      const AuthHttpResponse(statusCode: 503, body: '{"detail":"private"}'),
    );
    await pumpPage(tester, client);

    await submitEmail(tester, 'visitor@example.com');

    expect(client.requestCount, 1);
    expect(find.byKey(const Key('forgot-password-error')), findsOneWidget);
    expect(find.text('Lỗi từ phía máy chủ.'), findsOneWidget);
    expect(find.byKey(const Key('forgot-password-success')), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('forgot-password-submit')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('loading prevents duplicate requests', (tester) async {
    final client = FakeAuthHttpClient.pending();
    await pumpPage(tester, client);
    await tester.enterText(
      find.byKey(const Key('forgot-password-email')),
      'visitor@example.com',
    );
    await tester.tap(find.byKey(const Key('forgot-password-submit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('forgot-password-submit')));
    await tester.pump();

    expect(client.requestCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    client.completer!.complete(
      const AuthHttpResponse(statusCode: 200, body: '{"message":"generic"}'),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forgot-password-success')), findsOneWidget);
  });

  testWidgets('English success does not imply the email is registered', (
    tester,
  ) async {
    final client = FakeAuthHttpClient(
      const AuthHttpResponse(statusCode: 200, body: '{"message":"generic"}'),
    );
    await pumpPage(tester, client, locale: const Locale('en'));

    await submitEmail(tester, 'visitor@example.com');

    expect(
      find.text(
        'If an account uses this email, recovery instructions will be sent.',
      ),
      findsOneWidget,
    );
  });
}

class FakeAuthHttpClient implements AuthHttpClient {
  FakeAuthHttpClient(this.response) : completer = null;
  FakeAuthHttpClient.pending() : response = null, completer = Completer();

  final AuthHttpResponse? response;
  final Completer<AuthHttpResponse>? completer;
  int requestCount = 0;

  @override
  Future<AuthHttpResponse> post(
    Uri requestUri, {
    required String contentType,
    required String body,
  }) {
    requestCount++;
    return completer?.future ?? Future.value(response!);
  }
}
