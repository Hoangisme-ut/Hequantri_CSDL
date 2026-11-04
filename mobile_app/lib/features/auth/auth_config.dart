import '../../shared/config/api_config.dart';

/// Public backend origin shared by authentication and beacon requests.
///
/// Configure with:
/// --dart-define=API_BASE_URL=https://api.example.com
///
/// SMART_HERITAGE_API_BASE_URL remains supported for existing launch commands.
abstract final class AuthConfig {
  static Uri get apiBaseUrl => ApiConfig.baseUrl;
}
