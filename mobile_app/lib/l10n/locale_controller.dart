import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  LocaleController._() : initialized = _loadInitialLocale();

  static final LocaleController instance = LocaleController._();

  final Future<void> initialized;

  Locale _locale = const Locale('vi');

  Locale get locale => _locale;
  bool get isEnglish => _locale.languageCode == 'en';

  static const String _preferenceKey = 'app_locale';

  static Future<void> _loadInitialLocale() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final code = preferences.getString(_preferenceKey);
      if (code == 'en' || code == 'vi') {
        instance._locale = Locale(code!);
      }
    } catch (_) {
      // Keep Vietnamese as the safe default when preferences are unavailable.
    }
  }

  Future<void> setLocale(Locale newLocale) async {
    if (newLocale.languageCode != 'vi' && newLocale.languageCode != 'en') {
      return;
    }
    if (_locale == newLocale) return;

    _locale = newLocale;
    notifyListeners();

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_preferenceKey, newLocale.languageCode);
    } catch (_) {
      // The in-memory locale remains usable if persistence is unavailable.
    }
  }

  Future<void> toggleLocale() async {
    final target = isEnglish ? const Locale('vi') : const Locale('en');
    await setLocale(target);
  }
}
