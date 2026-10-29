class ApiConfig {
  ApiConfig._();

  static const String _rawBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static Uri get baseUrl {
    final value = _rawBaseUrl.trim();

    if (value.isEmpty) {
      throw StateError(
        'Chưa cấu hình API_BASE_URL khi chạy ứng dụng.',
      );
    }

    final uri = Uri.tryParse(value);

    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw StateError(
        'API_BASE_URL phải là địa chỉ backend gồm '
        'http/https, tên máy và cổng; không thêm /api/v1.',
      );
    }

    return uri.replace(path: '/');
  }
}