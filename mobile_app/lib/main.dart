import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/auth/auth_config.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/auth_session.dart';
import 'features/auth/login_page.dart';
import 'features/beacon/beacon_tools_page.dart';
import 'features/home/main_navigation_scaffold.dart';
import 'features/welcome/welcome_page.dart';
import 'l10n/app_strings.dart';
import 'l10n/locale_controller.dart';
import 'theme/app_theme.dart';

export 'features/beacon/beacon_tools_page.dart'
    show AppShell, BeaconTestPage, BeaconTestPageState;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleController.instance.initialized;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    @visibleForTesting this.appShell,
    @visibleForTesting this.authService,
  });

  final AppShell? appShell;
  final AuthService? authService;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _session = AuthSession();

  late final AuthService _authService;
  late final bool _ownsAuthService;

  late Locale _locale;

  @override
  void initState() {
    super.initState();

    _ownsAuthService = widget.authService == null;
    _authService =
        widget.authService ??
        AuthService(baseUrl: AuthConfig.apiBaseUrl, client: IoAuthHttpClient());
    _locale = LocaleController.instance.locale;
    LocaleController.instance.addListener(_onLocaleControllerChanged);
  }

  @override
  void dispose() {
    LocaleController.instance.removeListener(_onLocaleControllerChanged);
    if (_ownsAuthService) {
      _authService.close();
    }
    _session.dispose();
    super.dispose();
  }

  void _onLocaleControllerChanged() {
    if (!mounted) return;
    setState(() => _locale = LocaleController.instance.locale);
  }

  void _changeLocale(Locale locale) {
    LocaleController.instance.setLocale(locale);
  }

  void _onAuthenticated(AuthToken token) {
    _session.authenticate(token);
    _enterMainApp();
  }

  void _enterMainApp() {
    final navigator = _navigatorKey.currentState;
    if (!mounted || navigator == null) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => MainNavigationScaffold(
          onLocaleChanged: _changeLocale,
          onLogout: _logout,
        ),
      ),
      (_) => false,
    );
  }

  void _logout() {
    _session.clear();

    final navigator = _navigatorKey.currentState;
    if (!mounted || navigator == null) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(
          onAuthenticated: _onAuthenticated,
          authService: _authService,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthSessionScope(
      session: _session,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Smart Heritage',
        navigatorKey: _navigatorKey,
        locale: _locale,
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home:
            widget.appShell ??
            WelcomePage(
              onLocaleChanged: _changeLocale,
              onAuthenticated: _onAuthenticated,
              authService: _authService,
            ),
      ),
    );
  }
}
