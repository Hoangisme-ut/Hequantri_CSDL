import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/login_page.dart';

void main() {
  Future<void> pumpLoginPage(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blueGrey,
            secondary: Colors.amber,
            tertiary: Colors.teal,
          ),
          useMaterial3: true,
        ),
        home: const LoginPage(),
      ),
    );
  }

  bool passwordIsObscured(WidgetTester tester, Key key) {
    return tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(TextField),
          ),
        )
        .obscureText;
  }

  testWidgets('login page shows email, password and submit controls', (
    WidgetTester tester,
  ) async {
    await pumpLoginPage(tester);

    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(find.byKey(const Key('login-password')), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
  });

  testWidgets('login rejects empty and malformed email fields', (
    WidgetTester tester,
  ) async {
    await pumpLoginPage(tester);

    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập email.'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'not-an-email',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'password');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.text('Email không hợp lệ.'), findsOneWidget);
    expect(find.textContaining('chưa kết nối máy chủ'), findsNothing);
  });

  testWidgets('valid login form does not claim authentication success', (
    WidgetTester tester,
  ) async {
    await pumpLoginPage(tester);

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'visitor@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'password123',
    );
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();

    expect(
      find.text('Biểu mẫu hợp lệ. Đăng nhập chưa kết nối máy chủ.'),
      findsOneWidget,
    );
  });

  testWidgets('navigates from login to signup and back', (
    WidgetTester tester,
  ) async {
    await pumpLoginPage(tester);

    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('signup-title')), findsOneWidget);
    expect(find.byKey(const Key('signup-full-name')), findsOneWidget);
    expect(find.byKey(const Key('signup-email')), findsOneWidget);
    expect(find.byKey(const Key('signup-password')), findsOneWidget);
    expect(find.byKey(const Key('signup-confirm-password')), findsOneWidget);

    await tester.tap(find.text('Đã có tài khoản? Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email')), findsOneWidget);
  });

  testWidgets('password can be shown and hidden', (WidgetTester tester) async {
    await pumpLoginPage(tester);

    const passwordKey = Key('login-password');
    expect(passwordIsObscured(tester, passwordKey), isTrue);

    await tester.tap(find.byTooltip('Hiện mật khẩu'));
    await tester.pump();
    expect(passwordIsObscured(tester, passwordKey), isFalse);

    await tester.tap(find.byTooltip('Ẩn mật khẩu'));
    await tester.pump();
    expect(passwordIsObscured(tester, passwordKey), isTrue);
  });

  testWidgets('signup rejects mismatched password confirmation', (
    WidgetTester tester,
  ) async {
    await pumpLoginPage(tester);
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('signup-email')),
      'visitor@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('signup-password')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('signup-confirm-password')),
      'different123',
    );
    await tester.tap(find.byKey(const Key('signup-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
    expect(find.textContaining('chưa kết nối máy chủ'), findsNothing);
  });

  testWidgets('signup enforces password minimum length', (
    WidgetTester tester,
  ) async {
    await pumpLoginPage(tester);
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('signup-email')),
      'visitor@example.com',
    );
    await tester.enterText(find.byKey(const Key('signup-password')), 'short');
    await tester.enterText(
      find.byKey(const Key('signup-confirm-password')),
      'short',
    );
    await tester.tap(find.byKey(const Key('signup-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Mật khẩu phải có ít nhất 8 ký tự.'), findsOneWidget);
  });

  testWidgets('valid signup permits optional name without claiming success', (
    WidgetTester tester,
  ) async {
    await pumpLoginPage(tester);
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('signup-email')),
      'visitor@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('signup-password')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('signup-confirm-password')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('signup-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('Biểu mẫu hợp lệ. Đăng ký chưa kết nối máy chủ.'),
      findsOneWidget,
    );
  });

  testWidgets('auth pages scroll on a small viewport without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpLoginPage(tester);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);

    final signupLink = find.text('Chưa có tài khoản? Đăng ký');
    await tester.ensureVisible(signupLink);
    await tester.pumpAndSettle();
    await tester.tap(signupLink);
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
