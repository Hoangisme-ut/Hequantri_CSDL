/// Public API origin used by the mobile authentication client.
///
/// Override for a device or deployed environment with
/// `--dart-define=SMART_HERITAGE_API_BASE_URL=https://api.example.com`.
abstract final class AuthConfig {
  static const _configuredBaseUrl = String.fromEnvironment(
    'SMART_HERITAGE_API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static final Uri apiBaseUrl = Uri.parse(_configuredBaseUrl);
}
