import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/auth_service.dart';
import 'package:flutter_application_1/features/auth/auth_session.dart';
import 'package:flutter_application_1/features/data/visitor_api_service.dart';
import 'package:flutter_application_1/features/home/profile_page.dart';
import 'package:flutter_application_1/l10n/app_strings.dart';
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
        home: ProfilePage(
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
}

class _FakeUserApi implements UserApi {
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

class _DeferredUserApi implements UserApi {
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

class _FailingUserApi implements UserApi {
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
