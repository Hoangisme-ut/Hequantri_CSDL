import '../../shared/config/api_config.dart';

/// Public backend origin shared by authentication and beacon requests.
///
/// Configure with:
/// --dart-define=API_BASE_URL=https://api.example.com
///
/// SMART_HERITAGE_API_BASE_URL remains supported for existing launch commands.
abstract final class AuthConfig {
  static Uri get apiBaseUrl {
    if (ApiConfig.isConfigured) {
      return ApiConfig.baseUrl;
    }

    // Preserve the existing authentication default when no URL is configured.
    return Uri.parse('http://localhost:8000');
  }
}
