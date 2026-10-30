class ApiConfig {
  ApiConfig._();

  static const String _primaryBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const String _legacyBaseUrl = String.fromEnvironment(
    'SMART_HERITAGE_API_BASE_URL',
  );

  static bool get isConfigured {
    return _primaryBaseUrl.trim().isNotEmpty ||
        _legacyBaseUrl.trim().isNotEmpty;
  }

  static Uri get baseUrl {
    final primary = _primaryBaseUrl.trim();
    final legacy = _legacyBaseUrl.trim();

    if (primary.isEmpty && legacy.isEmpty) {
      throw StateError('Chưa cấu hình API_BASE_URL khi chạy ứng dụng.');
    }

    final selected = _parseOrigin(primary.isNotEmpty ? primary : legacy);

    if (primary.isNotEmpty && legacy.isNotEmpty) {
      final legacyOrigin = _parseOrigin(legacy);

      if (selected != legacyOrigin) {
        throw StateError(
          'API_BASE_URL và SMART_HERITAGE_API_BASE_URL '
          'phải trỏ đến cùng một backend. '
          'Nên chỉ cấu hình API_BASE_URL.',
        );
      }
    }

    return selected;
  }

  static Uri _parseOrigin(String value) {
    final uri = Uri.tryParse(value);

    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw StateError(
        'Địa chỉ backend phải gồm http/https, tên máy và cổng; '
        'không thêm /api/v1, thông tin đăng nhập hoặc tham số.',
      );
    }

    return uri.replace(path: '/');
  }
}
