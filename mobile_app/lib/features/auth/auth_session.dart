import 'package:flutter/material.dart';

import 'auth_service.dart';

/// Authentication state for the current app process.
class AuthSession extends ChangeNotifier {
  AuthToken? _token;
  bool _isDemoSession = false;

  bool get isAuthenticated => _token != null;
  bool get isDemoSession => _isDemoSession;

  AuthToken? readToken() => _token;

  void authenticate(AuthToken token) {
    final accessToken = token.accessToken.trim();
    final tokenType = token.tokenType.trim().toLowerCase();

    if (accessToken.isEmpty || tokenType != 'bearer') {
      throw ArgumentError('A non-empty Bearer token is required.');
    }

    _token = AuthToken(accessToken: accessToken, tokenType: tokenType);
    _isDemoSession = false;
    notifyListeners();
  }

  void enterDemo() {
    _token = null;
    _isDemoSession = true;
    notifyListeners();
  }

  void clear() {
    _token = null;
    _isDemoSession = false;
    notifyListeners();
  }
}

class AuthSessionScope extends InheritedNotifier<AuthSession> {
  const AuthSessionScope({
    super.key,
    required AuthSession session,
    required super.child,
  }) : super(notifier: session);

  static AuthSession? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AuthSessionScope>()
        ?.notifier;
  }

  static AuthSession of(BuildContext context) {
    final session = maybeOf(context);

    if (session == null) {
      throw StateError('AuthSessionScope was not found.');
    }

    return session;
  }
}
