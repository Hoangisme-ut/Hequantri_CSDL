import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter_application_1/features/auth/auth_widgets.dart';
import 'package:flutter_application_1/features/auth/login_page.dart';
import 'package:flutter_application_1/features/auth/signup_page.dart';
import 'package:flutter_application_1/l10n/app_strings.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

const _loginAccent = HeritagePalette.actionBlue;

void main() {
  Future<void> pumpLoginPage(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const LoginPage(),
      ),
    );
  }

  Future<void> pumpSignupPage(
    WidgetTester tester, {
    Locale locale = const Locale('vi'),
  }) {
    return tester.pumpWidget(
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
        darkTheme: AppTheme.dark(),
        home: const SignupPage(),
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

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enterTextVisible(
    WidgetTester tester,
    Finder finder,
    String text,
  ) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.enterText(finder, text);
  }

  testWidgets('login page shows email, password and submit controls', (
    WidgetTester tester,
  ) async {
    await pumpLoginPage(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(find.byKey(const Key('login-password')), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
    expect(find.text('SMART HERITAGE'), findsOneWidget);
    expect(find.byType(AuthBrandHeader), findsOneWidget);
  });

  testWidgets('login header content aligns to the card center on mobile', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in [const Size(390, 844), const Size(360, 800)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpLoginPage(tester);
      await tester.pumpAndSettle();

      final headerCenter = tester.getCenter(find.byType(AuthBrandHeader));
      final markCenter = tester.getCenter(find.byType(HeritageMark));
      final titleCenter = tester.getCenter(find.text('Đăng nhập tài khoản'));
      final subtitleCenter = tester.getCenter(
        find.text('Tiếp tục hành trình khám phá các di sản.'),
      );

      expect((markCenter.dx - headerCenter.dx).abs(), lessThan(1));
      expect((titleCenter.dx - headerCenter.dx).abs(), lessThan(1));
      expect((subtitleCenter.dx - headerCenter.dx).abs(), lessThan(1));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('login rejects empty and malformed email fields', (
    WidgetTester tester,
  ) async {
    await pumpLoginPage(tester);
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Đăng nhập'));
    expect(find.text('Vui lòng nhập email.'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu.'), findsOneWidget);

    await enterTextVisible(
      tester,
      find.byKey(const Key('login-email')),
      'not-an-email',
    );
    await enterTextVisible(
      tester,
      find.byKey(const Key('login-password')),
      'password',
    );
    await tapVisible(tester, find.text('Đăng nhập'));

    expect(find.text('Email không hợp lệ.'), findsOneWidget);
    expect(find.textContaining('chưa kết nối máy chủ'), findsNothing);
  });

  testWidgets('auth fields use shared focus and error theme tokens', (
    WidgetTester tester,
  ) async {
    await pumpLoginPage(tester);
    await tester.pumpAndSettle();

    final theme = Theme.of(
      tester.element(find.byKey(const Key('login-email'))),
    );
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, _loginAccent);
    expect(theme.colorScheme.secondary, _loginAccent);
    expect(theme.scaffoldBackgroundColor, HeritagePalette.authNavy);
    final focusedBorder =
        theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder;
    expect(focusedBorder.borderSide.color, _loginAccent);

    await tapVisible(tester, find.text('Đăng nhập'));

    expect(find.text('Vui lòng nhập email.'), findsOneWidget);
    expect(
      theme.inputDecorationTheme.errorStyle?.color,
      theme.colorScheme.error,
    );
  });

  testWidgets('dark theme applies shared heritage colors', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpLoginPage(tester);
    await tester.pumpAndSettle();

    final theme = Theme.of(
      tester.element(find.byKey(const Key('login-email'))),
    );
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.secondary, _loginAccent);
    expect(theme.scaffoldBackgroundColor, HeritagePalette.authNavy);
  });

  testWidgets('shared submit button exposes a disabled loading state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AuthSubmitButton(
            label: 'Continue',
            onPressed: () {},
            isLoading: true,
            backgroundColor: _loginAccent,
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(
      button.style!.backgroundColor!.resolve(const {WidgetState.disabled}),
      _loginAccent.withValues(alpha: 0.5),
    );
    expect(
      button.style!.foregroundColor!.resolve(const {WidgetState.disabled}),
      HeritagePalette.surface.withValues(alpha: 0.7),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('blue primary action uses a high-contrast label', (
    WidgetTester tester,
  ) async {
    await pumpLoginPage(tester);
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Đăng nhập'),
        matching: find.byType(FilledButton),
      ),
    );
    final style = button.style!;
    expect(
      style.backgroundColor!.resolve(const {WidgetState.selected}),
      _loginAccent,
    );
    expect(
      style.foregroundColor!.resolve(const {WidgetState.selected}),
      HeritagePalette.surface,
    );
    expect(
      style.shape!.resolve(const {WidgetState.selected}),
      isA<StadiumBorder>(),
    );
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
  });

  testWidgets('login buttons keep distinct colors across UI states', (
    WidgetTester tester,
  ) async {
    await pumpLoginPage(tester);
    await tester.pumpAndSettle();

    const normal = <WidgetState>{};
    const disabled = <WidgetState>{WidgetState.disabled};
    const focused = <WidgetState>{WidgetState.focused};

    final login = tester.widget<FilledButton>(
      find.byKey(const Key('login-submit')),
    );
    expect(login.style!.backgroundColor!.resolve(normal), _loginAccent);
    expect(
      login.style!.backgroundColor!.resolve(disabled),
      _loginAccent.withValues(alpha: 0.5),
    );
    expect(
      login.style!.foregroundColor!.resolve(normal),
      HeritagePalette.surface,
    );
    final loginPressedOverlay = login.style!.overlayColor!.resolve(const {
      WidgetState.pressed,
    });
    expect(loginPressedOverlay, isNotNull);
    expect(loginPressedOverlay!.r, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final google = tester.widget<OutlinedButton>(
      find.byKey(const Key('login-google')),
    );
    final googleStyle = google.style!;
    expect(googleStyle.backgroundColor!.resolve(normal), Colors.white);
    expect(googleStyle.backgroundColor!.resolve(disabled), Colors.white);
    expect(
      googleStyle.foregroundColor!.resolve(normal),
      HeritagePalette.primaryNavy,
    );
    expect(
      googleStyle.side!.resolve(focused),
      const BorderSide(color: Color(0xFF747775)),
    );
    final googlePressedOverlay = googleStyle.overlayColor!.resolve(const {
      WidgetState.pressed,
    });
    expect(googlePressedOverlay, isNotNull);
    expect(googlePressedOverlay!.r, HeritagePalette.primaryNavy.r);
    expect(googlePressedOverlay.g, HeritagePalette.primaryNavy.g);
    expect(googlePressedOverlay.b, HeritagePalette.primaryNavy.b);
    expect(find.byKey(const Key('login-google-mark')), findsOneWidget);

    final rememberMe = tester.widget<Checkbox>(
      find.descendant(
        of: find.byKey(const Key('login-remember-me')),
        matching: find.byType(Checkbox),
      ),
    );
    expect(rememberMe.activeColor, _loginAccent);

    for (final key in const [
      Key('login-forgot-password'),
      Key('login-signup'),
    ]) {
      final button = tester.widget<TextButton>(find.byKey(key));
      expect(button.style!.foregroundColor!.resolve(normal), _loginAccent);
    }
    expect(
      tester.widget<Text>(find.text('Quên mật khẩu?')).style!.color,
      _loginAccent,
    );
  });

  testWidgets('login and signup inputs and primary actions share sizing', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpLoginPage(tester);
    await tester.pumpAndSettle();
    final loginEmailHeight = tester
        .getSize(find.byKey(const Key('login-email')))
        .height;
    final loginButton = find.ancestor(
      of: find.text('Đăng nhập'),
      matching: find.byType(FilledButton),
    );
    final loginButtonHeight = tester.getSize(loginButton).height;

    await tapVisible(tester, find.text('Chưa có tài khoản? Đăng ký'));

    expect(
      tester.getSize(find.byKey(const Key('signup-email'))).height,
      loginEmailHeight,
    );
    expect(
      tester.getSize(find.byKey(const Key('signup-submit'))).height,
      loginButtonHeight,
    );
    expect(loginButtonHeight, 56);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signup primary button keeps its existing blue theme', (
    WidgetTester tester,
  ) async {
    await pumpSignupPage(tester);
    await tester.pumpAndSettle();

    final signup = tester.widget<FilledButton>(
      find.byKey(const Key('signup-submit')),
    );
    expect(
      signup.style!.backgroundColor!.resolve(const {}),
      HeritagePalette.authCta,
    );
  });

  testWidgets('valid login form does not claim authentication success', (
    WidgetTester tester,
  ) async {
    await pumpLoginPage(tester);
    await tester.pumpAndSettle();

    await enterTextVisible(
      tester,
      find.byKey(const Key('login-email')),
      'visitor@example.com',
    );
    await enterTextVisible(
      tester,
      find.byKey(const Key('login-password')),
      'password123',
    );
    await tapVisible(tester, find.text('Đăng nhập'));

    expect(
      find.text('Biểu mẫu hợp lệ. Đăng nhập chưa kết nối máy chủ.'),
      findsOneWidget,
    );
  });

  testWidgets('navigates from login to signup and back', (
    WidgetTester tester,
  ) async {
    await pumpLoginPage(tester);
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Chưa có tài khoản? Đăng ký'));
    expect(find.byKey(const Key('signup-title')), findsOneWidget);
    expect(find.byKey(const Key('signup-full-name')), findsOneWidget);
    expect(find.byKey(const Key('signup-email')), findsOneWidget);
    expect(find.byKey(const Key('signup-password')), findsOneWidget);
    expect(find.byKey(const Key('signup-confirm-password')), findsOneWidget);
    expect(find.text('SMART HERITAGE'), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_outlined), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('signup-title'))).style?.color,
      HeritagePalette.authText,
    );

    await tapVisible(tester, find.text('Đã có tài khoản? Đăng nhập'));
    expect(find.byKey(const Key('login-email')), findsOneWidget);
  });

  testWidgets('password can be shown and hidden', (WidgetTester tester) async {
    await pumpLoginPage(tester);
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Chưa có tài khoản? Đăng ký'));

    await enterTextVisible(
      tester,
      find.byKey(const Key('signup-email')),
      'visitor@example.com',
    );
    await enterTextVisible(
      tester,
      find.byKey(const Key('signup-password')),
      'password123',
    );
    await enterTextVisible(
      tester,
      find.byKey(const Key('signup-confirm-password')),
      'different123',
    );
    await tapVisible(tester, find.byKey(const Key('signup-submit')));

    expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
    expect(find.textContaining('chưa kết nối máy chủ'), findsNothing);
  });

  testWidgets('signup enforces password minimum length', (
    WidgetTester tester,
  ) async {
    await pumpLoginPage(tester);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Chưa có tài khoản? Đăng ký'));

    await enterTextVisible(
      tester,
      find.byKey(const Key('signup-email')),
      'visitor@example.com',
    );
    await enterTextVisible(
      tester,
      find.byKey(const Key('signup-password')),
      'short',
    );
    await enterTextVisible(
      tester,
      find.byKey(const Key('signup-confirm-password')),
      'short',
    );
    await tapVisible(tester, find.byKey(const Key('signup-submit')));

    expect(find.text('Mật khẩu phải có ít nhất 8 ký tự.'), findsOneWidget);
  });

  testWidgets('valid signup permits optional name without claiming success', (
    WidgetTester tester,
  ) async {
    await pumpLoginPage(tester);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Chưa có tài khoản? Đăng ký'));

    await enterTextVisible(
      tester,
      find.byKey(const Key('signup-email')),
      'visitor@example.com',
    );
    await enterTextVisible(
      tester,
      find.byKey(const Key('signup-password')),
      'password123',
    );
    await enterTextVisible(
      tester,
      find.byKey(const Key('signup-confirm-password')),
      'password123',
    );
    await tapVisible(tester, find.byKey(const Key('signup-submit')));

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
    await tester.pumpAndSettle();
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

  testWidgets('mobile auth layouts fit target sizes and keyboard insets', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    for (final size in [
      const Size(360, 800),
      const Size(360, 844),
      const Size(390, 800),
      const Size(390, 844),
      const Size(430, 800),
      const Size(430, 844),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.resetViewInsets();

      await pumpLoginPage(tester);
      await tester.pumpAndSettle();
      final loginForm = find.byType(Form);
      final loginTop = tester.getTopLeft(loginForm).dy;
      final loginBottom = tester.getBottomRight(loginForm).dy;
      expect(
        ((loginTop + loginBottom) / 2 - size.height / 2).abs(),
        lessThan(2),
      );
      expect(tester.takeException(), isNull);

      await tapVisible(tester, find.text('Chưa có tài khoản? Đăng ký'));
      final signupSubmit = find.byKey(const Key('signup-submit'));
      expect(signupSubmit, findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.ensureVisible(signupSubmit);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(signupSubmit).dy,
        lessThanOrEqualTo(size.height - 300),
      );
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byTooltip('Quay lại đăng nhập'));
    }
  });

  testWidgets('login and signup fit desktop layout without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpLoginPage(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AuthHeritageAside), findsOneWidget);
    expect(find.text('Di sản sống\ntrong từng hành trình.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tapVisible(tester, find.text('Chưa có tài khoản? Đăng ký'));
    expect(find.byKey(const Key('signup-submit')), findsOneWidget);
    expect(find.byType(AuthHeritageAside), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'signup renders all localized labels in English and checks terms validation',
    (WidgetTester tester) async {
      await pumpSignupPage(tester, locale: const Locale('en'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('signup-title')), findsOneWidget);
      expect(find.text('Account Information'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
      expect(find.byKey(const Key('signup-full-name')), findsOneWidget);
      expect(find.byKey(const Key('signup-email')), findsOneWidget);
      expect(find.byKey(const Key('signup-password')), findsOneWidget);
      expect(find.byKey(const Key('signup-confirm-password')), findsOneWidget);
      expect(find.textContaining('Terms of Service'), findsOneWidget);
      expect(find.textContaining('Privacy Policy'), findsOneWidget);

      // Uncheck terms of service
      await tapVisible(tester, find.byKey(const Key('signup-terms-agree')));
      await enterTextVisible(
        tester,
        find.byKey(const Key('signup-email')),
        'visitor@example.com',
      );
      await enterTextVisible(
        tester,
        find.byKey(const Key('signup-password')),
        'password123',
      );
      await enterTextVisible(
        tester,
        find.byKey(const Key('signup-confirm-password')),
        'password123',
      );
      await tapVisible(tester, find.byKey(const Key('signup-submit')));

      expect(
        find.text('Please agree to the Terms of Service and Privacy Policy.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('signup in Vietnamese checks terms checkbox validation', (
    WidgetTester tester,
  ) async {
    await pumpSignupPage(tester, locale: const Locale('vi'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('signup-title')), findsOneWidget);
    expect(find.text('Thông tin tài khoản'), findsOneWidget);
    expect(find.text('Đăng ký'), findsOneWidget);

    // Uncheck terms of service
    await tapVisible(tester, find.byKey(const Key('signup-terms-agree')));
    await enterTextVisible(
      tester,
      find.byKey(const Key('signup-email')),
      'visitor@example.com',
    );
    await enterTextVisible(
      tester,
      find.byKey(const Key('signup-password')),
      'password123',
    );
    await enterTextVisible(
      tester,
      find.byKey(const Key('signup-confirm-password')),
      'password123',
    );
    await tapVisible(tester, find.byKey(const Key('signup-submit')));

    expect(
      find.text(
        'Vui lòng đồng ý với Điều khoản sử dụng và Chính sách bảo mật.',
      ),
      findsOneWidget,
    );
  });
}
