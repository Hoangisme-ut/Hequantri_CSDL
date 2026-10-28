import 'dart:convert';

import 'package:http/http.dart' as http;

/// Enum định nghĩa các loại lỗi xác thực chuẩn theo bộ test của nhóm
enum AuthFailure {
  loginRejected,
  emailAlreadyRegistered,
  server,
  network,
  invalidResponse,
}

/// Class Exception xử lý ngoại lệ cho AuthService
class AuthServiceException implements Exception {
  final AuthFailure failure;

  const AuthServiceException(this.failure);

  @override
  String toString() => 'AuthServiceException: $failure';
}

/// Class phản hồi HTTP
class AuthHttpResponse {
  final int statusCode;
  final String body;

  const AuthHttpResponse({required this.statusCode, required this.body});
}

/// Interface cho HTTP Client dùng trong kiểm thử
abstract class AuthHttpClient {
  Future<AuthHttpResponse> post(
    Uri requestUri, {
    required String contentType,
    required String body,
  });
}

/// Implementation mặc định của HTTP Client
class IoAuthHttpClient implements AuthHttpClient {
  final http.Client _client;

  IoAuthHttpClient([http.Client? client]) : _client = client ?? http.Client();

  @override
  Future<AuthHttpResponse> post(
    Uri requestUri, {
    required String contentType,
    required String body,
  }) async {
    final response = await _client
        .post(requestUri, headers: {'Content-Type': contentType}, body: body)
        .timeout(const Duration(seconds: 15));

    return AuthHttpResponse(
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  void close() {
    _client.close();
  }
}

/// Model Token sau khi đăng nhập thành công
class AuthToken {
  final String accessToken;
  final String tokenType;

  const AuthToken({required this.accessToken, required this.tokenType});

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('access_token') || !json.containsKey('token_type')) {
      throw const FormatException('Missing token fields');
    }
    return AuthToken(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
    );
  }
}

/// Model người dùng trả về sau khi đăng ký
class RegisteredUser {
  final String id;
  final String email;
  final String? fullName;
  final bool isActive;
  final bool isSuperuser;
  final DateTime? createdAt;

  const RegisteredUser({
    required this.id,
    required this.email,
    this.fullName,
    this.isActive = true,
    this.isSuperuser = false,
    this.createdAt,
  });

  factory RegisteredUser.fromJson(Map<String, dynamic> json) {
    return RegisteredUser(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isSuperuser: json['is_superuser'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

/// Service quản lý xác thực chính
class AuthService {
  final Uri baseUrl;
  final AuthHttpClient? client;

  AuthService({required Uri baseUrl, this.client}) : baseUrl = baseUrl {
    if (baseUrl.userInfo.isNotEmpty || baseUrl.hasQuery) {
      throw ArgumentError(
        'Base URL must not contain credentials or query parameters',
      );
    }
  }

  void close() {
    if (client is IoAuthHttpClient) {
      (client as IoAuthHttpClient).close();
    }
  }

  Future<void> requestPasswordRecovery({required String email}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  Future<AuthToken> login({
    required String email,
    required String password,
  }) async {
    final uri = baseUrl.replace(path: '/api/v1/login/access-token');
    final body = Uri(queryParameters: {'username': email, 'password': password})
        .query;

    try {
      final response = await client!.post(
        uri,
        contentType: 'application/x-www-form-urlencoded',
        body: body,
      );

      if (response.statusCode == 400) {
        throw const AuthServiceException(AuthFailure.loginRejected);
      }

      if (response.statusCode != 200) {
        throw const AuthServiceException(AuthFailure.server);
      }

      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return AuthToken.fromJson(json);
      } catch (_) {
        throw const AuthServiceException(AuthFailure.invalidResponse);
      }
    } on AuthServiceException {
      rethrow;
    } catch (_) {
      throw const AuthServiceException(AuthFailure.network);
    }
  }

  Future<RegisteredUser> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final uri = baseUrl.replace(path: '/api/v1/users/signup');
    final payload = <String, dynamic>{'email': email, 'password': password};
    if (fullName != null) {
      payload['full_name'] = fullName;
    }

    try {
      final response = await client!.post(
        uri,
        contentType: 'application/json',
        body: jsonEncode(payload),
      );

      if (response.statusCode == 400) {
        throw const AuthServiceException(AuthFailure.emailAlreadyRegistered);
      }

      if (response.statusCode != 200) {
        throw const AuthServiceException(AuthFailure.server);
      }

      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return RegisteredUser.fromJson(json);
      } catch (_) {
        throw const AuthServiceException(AuthFailure.invalidResponse);
      }
    } on AuthServiceException {
      rethrow;
    } catch (_) {
      throw const AuthServiceException(AuthFailure.network);
    }
  }
}
