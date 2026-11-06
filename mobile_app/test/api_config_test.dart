import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/auth/auth_config.dart';
import 'package:flutter_application_1/shared/config/api_config.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android uses the host loopback address for the emulator', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(ApiConfig.baseUrl, Uri.parse('http://10.0.2.2:8000'));
    expect(AuthConfig.apiBaseUrl, ApiConfig.baseUrl);
  });

  test('desktop default uses localhost and is shared with authentication', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    expect(ApiConfig.baseUrl, Uri.parse('http://localhost:8000'));
    expect(AuthConfig.apiBaseUrl, ApiConfig.baseUrl);
  });
}
