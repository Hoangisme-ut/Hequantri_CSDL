import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/auth/auth_session.dart';
import 'package:flutter_application_1/features/data/visitor_api_service.dart';
import 'package:flutter_application_1/features/home/main_navigation_scaffold.dart';
import 'package:flutter_application_1/features/home/profile_page.dart';
import 'package:flutter_application_1/l10n/app_strings.dart';
import 'package:flutter_application_1/l10n/locale_controller.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  const tokenA = AuthToken(accessToken: 'token-a', tokenType: 'bearer');
  const tokenB = AuthToken(accessToken: 'token-b', tokenType: 'bearer');

  const profileA = UserProfile(
    id: '11111111-1111-1111-1111-111111111111',
    email: 'quochung123@example.com',
    fullName: 'Quoc Hung',
    roleName: 'Visitor',
    isActive: true,
    isSuperuser: false,
  );

  const profileB = UserProfile(
    id: '22222222-2222-2222-2222-222222222222',
    email: 'admin@example.com',
    fullName: 'System Administrator',
    roleName: 'Admin',
    isActive: true,
    isSuperuser: true,
  );

  Widget buildTestApp({
    required AuthSession session,
    required UserApi userApi,
    Locale locale = const Locale('vi'),
    VoidCallback? onLogout,
    Widget? home,
  }) {
    return AuthSessionScope(
      session: session,
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        home:
            home ??
            ProfilePage(
              onLocaleChanged: (_) {},
              onLogout: onLogout,
              userApi: userApi,
            ),
      ),
    );
  }

  testWidgets('displays real user name, email, and role badge when logged in', (
    WidgetTester tester,
  ) async {
    final session = AuthSession();
    addTearDown(session.dispose);
    session.authenticate(tokenA);

    final fakeUserApi = _FakeUserApi(profiles: {'token-a': profileA});

    await tester.pumpWidget(
      buildTestApp(session: session, userApi: fakeUserApi),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-user-card')), findsOneWidget);
    expect(find.byKey(const Key('profile-user-name')), findsOneWidget);
    expect(find.text('Quoc Hung'), findsOneWidget);
    expect(find.text('quochung123@example.com'), findsOneWidget);
    expect(find.text('Khách tham quan'), findsOneWidget);
    expect(find.byKey(const Key('profile-logout-button')), findsOneWidget);

    // Hardcoded sample values must NOT be present
    expect(find.text('Nguyễn Văn A'), findsNothing);
    expect(find.text('nguyenvana@gmail.com'), findsNothing);
  });

  testWidgets('shows loading state while fetching profile from API', (
    WidgetTester tester,
  ) async {
    final session = AuthSession();
    addTearDown(session.dispose);
    session.authenticate(tokenA);

    final deferredApi = _DeferredUserApi(profile: profileA);

    await tester.pumpWidget(
      buildTestApp(session: session, userApi: deferredApi),
    );
    await tester.pump();

    expect(find.byKey(const Key('profile-loading-card')), findsOneWidget);
    expect(find.text('Đang tải thông tin...'), findsOneWidget);

    deferredApi.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-loading-card')), findsNothing);
    expect(find.byKey(const Key('profile-user-card')), findsOneWidget);
    expect(find.text('Quoc Hung'), findsOneWidget);
  });

  testWidgets('shows error card and retry button when API fails', (
    WidgetTester tester,
  ) async {
    final session = AuthSession();
    addTearDown(session.dispose);
    session.authenticate(tokenA);

    final failingApi = _FailingUserApi(
      error: const VisitorApiException('Máy chủ đang bận. Vui lòng thử lại.', statusCode: 500),
      fallbackProfile: profileA,
    );

    await tester.pumpWidget(
      buildTestApp(session: session, userApi: failingApi),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-error-card')), findsOneWidget);
    expect(find.text('Máy chủ đang bận. Vui lòng thử lại.'), findsOneWidget);
    expect(find.byKey(const Key('profile-retry-button')), findsOneWidget);

    // Tap retry button after fixing API state
    failingApi.shouldSucceed = true;
    await tester.tap(find.byKey(const Key('profile-retry-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-error-card')), findsNothing);
    expect(find.byKey(const Key('profile-user-card')), findsOneWidget);
    expect(find.text('Quoc Hung'), findsOneWidget);
  });

  testWidgets('displays Guest card and login button when unauthenticated', (
    WidgetTester tester,
  ) async {
    final session = AuthSession();
    addTearDown(session.dispose);
    // Unauthenticated session (guest)
    expect(session.isAuthenticated, isFalse);

    final fakeUserApi = _FakeUserApi(profiles: {});

    await tester.pumpWidget(
      buildTestApp(session: session, userApi: fakeUserApi),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-guest-title')), findsOneWidget);
    expect(find.text('Khách tham quan'), findsOneWidget);
    expect(find.byKey(const Key('profile-guest-badge')), findsOneWidget);
    expect(find.text('Chế độ khách'), findsOneWidget);
    expect(find.byKey(const Key('profile-guest-login-button')), findsOneWidget);
    expect(find.byKey(const Key('profile-bottom-login')), findsOneWidget);

    // Logout button must not be shown for guests
    expect(find.byKey(const Key('profile-logout-button')), findsNothing);

    // Fake demo account must NOT be shown
    expect(find.text('Nguyễn Văn A'), findsNothing);
    expect(find.text('nguyenvana@gmail.com'), findsNothing);
  });

  testWidgets('clears user info immediately on logout and does not retain old data', (
    WidgetTester tester,
  ) async {
    final session = AuthSession();
    addTearDown(session.dispose);
    session.authenticate(tokenA);

    final fakeUserApi = _FakeUserApi(profiles: {'token-a': profileA});

    var logoutCalled = false;
    await tester.pumpWidget(
      buildTestApp(
        session: session,
        userApi: fakeUserApi,
        onLogout: () {
          logoutCalled = true;
          session.clear();
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quoc Hung'), findsOneWidget);

    // Scroll down to tap logout button
    await tester.scrollUntilVisible(find.byKey(const Key('profile-logout-button')), 200);
    await tester.tap(find.byKey(const Key('profile-logout-button')));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?'), findsOneWidget);
    final confirmBtn = find.widgetWithText(FilledButton, 'Đăng xuất');
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    expect(logoutCalled, isTrue);
    expect(session.isAuthenticated, isFalse);

    // Profile page immediately renders guest view with old data cleared
    expect(find.text('Quoc Hung'), findsNothing);
    expect(find.text('quochung123@example.com'), findsNothing);
    expect(find.byKey(const Key('profile-guest-title')), findsOneWidget);
  });

  testWidgets('updates profile immediately when switching accounts', (
    WidgetTester tester,
  ) async {
    final session = AuthSession();
    addTearDown(session.dispose);
    session.authenticate(tokenA);

    final fakeUserApi = _FakeUserApi(profiles: {
      'token-a': profileA,
      'token-b': profileB,
    });

    await tester.pumpWidget(
      buildTestApp(session: session, userApi: fakeUserApi),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quoc Hung'), findsOneWidget);
    expect(find.text('quochung123@example.com'), findsOneWidget);

    // Switch account to Account B
    session.authenticate(tokenB);
    await tester.pumpAndSettle();

    // Account A's data must be replaced by Account B's data
    expect(find.text('Quoc Hung'), findsNothing);
    expect(find.text('quochung123@example.com'), findsNothing);

    expect(find.text('System Administrator'), findsOneWidget);
    expect(find.text('admin@example.com'), findsOneWidget);
    expect(find.text('Quản trị viên'), findsOneWidget);
  });

  testWidgets('opens personal information bottom sheet with complete details', (
    WidgetTester tester,
  ) async {
    final session = AuthSession();
    addTearDown(session.dispose);
    session.authenticate(tokenA);

    final fakeUserApi = _FakeUserApi(profiles: {'token-a': profileA});

    await tester.pumpWidget(
      buildTestApp(session: session, userApi: fakeUserApi),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thông tin cá nhân'));
    await tester.pumpAndSettle();

    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Quoc Hung'), findsWidgets);
    expect(find.text('quochung123@example.com'), findsWidgets);
    expect(find.text('11111111-1111-1111-1111-111111111111'), findsOneWidget);
    expect(find.text('Hoạt động'), findsOneWidget);
  });

  testWidgets('renders English localization correctly', (
    WidgetTester tester,
  ) async {
    final session = AuthSession();
    addTearDown(session.dispose);
    session.authenticate(tokenA);

    final fakeUserApi = _FakeUserApi(profiles: {'token-a': profileA});

    await tester.pumpWidget(
      buildTestApp(session: session, userApi: fakeUserApi, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile & Settings'), findsOneWidget);
    expect(find.text('Visitor'), findsOneWidget);
    expect(find.text('TOUR EXPERIENCE'), findsOneWidget);
    expect(find.text('ACCOUNT & PREFERENCES'), findsOneWidget);
    expect(find.text('SUPPORT & INFORMATION'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);
  });

  group('account profile editing and locale', () {
    const englishId = '33333333-3333-3333-3333-333333333333';
    const vietnameseId = '44444444-4444-4444-4444-444444444444';
    final locale = LocaleController.instance;
    final saveButton = find.byKey(const Key('profile-edit-save'));

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await locale.initialized;
      await locale.setLocale(const Locale('vi'));
    });

    HttpVisitorApi mockAccountApi({
      String? languageId,
      Future<http.Response> Function(http.Request)? patch,
    }) {
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/languages/') {
          expect(request.method, 'GET');
          return _jsonResponse({
            'data': [
              {'id': vietnameseId, 'code': 'vi'},
              {'id': englishId, 'code': 'en'},
            ],
          });
        }
        if (request.url.path != '/api/v1/users/me') {
          return _jsonResponse({'data': [], 'count': 0});
        }
        expect(request.headers['authorization'], 'Bearer token-a');
        if (request.method == 'PATCH') return patch!(request);
        expect(request.method, 'GET');
        return _jsonResponse({
          'id': profileA.id,
          'full_name': profileA.fullName,
          'email': profileA.email,
          'role_name': profileA.roleName,
          'language_id': languageId,
        });
      });
      addTearDown(client.close);
      return HttpVisitorApi(
        baseUrl: Uri.parse('https://api.example.test'),
        client: client,
      );
    }

    Future<void> openEditor(WidgetTester tester, UserApi api) async {
      final session = AuthSession()..authenticate(tokenA);
      addTearDown(session.dispose);
      await tester.pumpWidget(buildTestApp(session: session, userApi: api));
      await tester.pumpAndSettle();
      final editTile = find.text('Thông tin cá nhân');
      await tester.ensureVisible(editTile);
      await tester.tap(editTile);
      await tester.pumpAndSettle();
    }

    testWidgets('saves name, email and mapped language with a loading state', (
      tester,
    ) async {
      final response = Completer<http.Response>();
      final api = mockAccountApi(
        patch: (request) async {
          expect(request.headers['content-type'], contains('application/json'));
          expect(jsonDecode(request.body), {
            'full_name': 'Updated Name',
            'email': 'new@example.com',
            'language_id': englishId,
          });
          return response.future;
        },
      );
      await openEditor(tester, api);
      await tester.enterText(
        find.byKey(const Key('profile-edit-name')),
        'Updated Name',
      );
      await tester.enterText(
        find.byKey(const Key('profile-edit-email')),
        'new@example.com',
      );
      await tester.tap(find.byKey(const Key('profile-edit-language')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();

      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(locale.locale, const Locale('en'));

      response.complete(
        _jsonResponse({
          'id': profileA.id,
          'full_name': 'Updated Name',
          'email': 'new@example.com',
          'language_id': englishId,
        }),
      );
      await tester.pumpAndSettle();

      expect(saveButton, findsNothing);
      expect(find.text('Updated Name'), findsOneWidget);
      expect(find.text('new@example.com'), findsOneWidget);
      expect(find.text('Khách tham quan'), findsOneWidget);
      expect(find.text('Đã lưu hồ sơ.'), findsOneWidget);
    });

    for (final (name, respond, message) in [
      (
        'duplicate email',
        () => _jsonResponse({
          'detail': 'User with this email already exists',
        }, status: 409),
        'Email này đã được sử dụng.',
      ),
      (
        'network failure',
        () => throw http.ClientException('offline'),
        'Không thể kết nối máy chủ. Hãy kiểm tra mạng rồi thử lại.',
      ),
      (
        'expired session',
        () => _jsonResponse({'detail': 'Not authenticated'}, status: 401),
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      ),
    ]) {
      testWidgets('keeps the draft and reports $name', (tester) async {
        final api = mockAccountApi(
          patch: (request) async {
            expect(jsonDecode(request.body), {'email': 'new@example.com'});
            return respond();
          },
        );
        await openEditor(tester, api);
        await tester.enterText(
          find.byKey(const Key('profile-edit-email')),
          'new@example.com',
        );
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(find.text(message), findsOneWidget);
        expect(find.text('new@example.com'), findsOneWidget);
        expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
      });
    }

    testWidgets(
      'restores the server locale after login with profile offstage',
      (tester) async {
        final session = AuthSession();
        addTearDown(session.dispose);
        final api = mockAccountApi(languageId: englishId);
        await tester.pumpWidget(
          buildTestApp(
            session: session,
            userApi: api,
            home: MainNavigationScaffold(
              onLocaleChanged: (_) {},
              visitorApi: api,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(locale.locale, const Locale('vi'));

        session.authenticate(tokenA);
        await tester.pumpAndSettle();

        expect(locale.locale, const Locale('en'));
        await _expectPersistedLocale('en');
      },
    );

    testWidgets('keeps the language on device when PATCH rejects it', (
      tester,
    ) async {
      final session = AuthSession()..authenticate(tokenA);
      addTearDown(session.dispose);
      final api = mockAccountApi(
        patch: (request) async {
          expect(jsonDecode(request.body), {'language_id': englishId});
          return _jsonResponse({'detail': 'Language is inactive'}, status: 400);
        },
      );
      await tester.pumpWidget(buildTestApp(session: session, userApi: api));
      await tester.pumpAndSettle();
      final languageTile = find.text('Ngôn ngữ');
      await tester.ensureVisible(languageTile);
      await tester.tap(languageTile);
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(locale.locale, const Locale('en'));
      expect(
        find.text(
          'This language is no longer available for your account. '
          'Your language choice is saved on this device.',
        ),
        findsOneWidget,
      );
      await _expectPersistedLocale('en');
    });
  });
}

http.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Future<void> _expectPersistedLocale(String code) async {
  final preferences = await SharedPreferences.getInstance();
  expect(preferences.getString('app_locale'), code);
}

abstract class _ReadOnlyUserApi implements UserApi {
  @override
  Future<List<ProfileLanguage>> loadLanguages() async => const [];

  @override
  Future<UserProfile> updateCurrentUser({
    required AuthToken token,
    String? fullName,
    String? email,
    String? languageId,
  }) => throw UnsupportedError('Read-only test API');
}

class _FakeUserApi extends _ReadOnlyUserApi {
  _FakeUserApi({required this.profiles});

  final Map<String, UserProfile> profiles;

  @override
  Future<UserProfile> loadCurrentUser({required AuthToken token}) async {
    final profile = profiles[token.accessToken];
    if (profile == null) {
      throw const VisitorApiException('User not found', statusCode: 404);
    }
    return profile;
  }
}

class _DeferredUserApi extends _ReadOnlyUserApi {
  _DeferredUserApi({required this.profile});

  final UserProfile profile;
  bool _isDone = false;
  void Function(UserProfile)? _callback;

  void complete() {
    _isDone = true;
    _callback?.call(profile);
  }

  @override
  Future<UserProfile> loadCurrentUser({required AuthToken token}) {
    if (_isDone) return Future.value(profile);
    final comp = Future<UserProfile>.delayed(const Duration(milliseconds: 100), () => profile);
    return comp;
  }
}

class _FailingUserApi extends _ReadOnlyUserApi {
  _FailingUserApi({required this.error, required this.fallbackProfile});

  final Exception error;
  final UserProfile fallbackProfile;
  bool shouldSucceed = false;

  @override
  Future<UserProfile> loadCurrentUser({required AuthToken token}) async {
    if (!shouldSucceed) {
      throw error;
    }
    return fallbackProfile;
  }
}
