import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/l10n/locale_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and persists the selected supported locale', () async {
    SharedPreferences.setMockInitialValues({'flutter.app_locale': 'en'});

    final controller = LocaleController.instance;
    await controller.initialized;
    expect(controller.locale, const Locale('en'));

    await controller.setLocale(const Locale('vi'));

    final preferences = await SharedPreferences.getInstance();
    expect(controller.locale, const Locale('vi'));
    expect(preferences.getString('app_locale'), 'vi');
  });
}
