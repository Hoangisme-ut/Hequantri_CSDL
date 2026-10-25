import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum AuthFailure {
  loginRejected,
  emailAlreadyRegistered,
  network,
  server,
  invalidResponse,
}

class AuthServiceException implements Exception {
  const AuthServiceException(this.failure);

  final AuthFailure failure;

  @override
  String toString() => 'AuthServiceException: ${failure.name}';
}

class AuthToken {
  const AuthToken({required this.accessToken, required this.tokenType});

  final String accessToken;
  final String tokenType;

  factory AuthToken.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const AuthServiceException(AuthFailure.invalidResponse);
    }

    final accessToken = value['access_token'];
    final tokenType = value['token_type'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        (tokenType != null && tokenType is! String)) {
      throw const AuthServiceException(AuthFailure.invalidResponse);
    }

    return AuthToken(
      accessToken: accessToken,
      tokenType: tokenType as String? ?? 'bearer',
    );
  }
}

class RegisteredUser {
  const RegisteredUser({
    required this.id,
    required this.email,
    required this.isActive,
    required this.isSuperuser,
    this.fullName,
    this.createdAt,
    this.roleId,
    this.languageId,
  });

  final String id;
  final String email;
  final bool isActive;
  final bool isSuperuser;
  final String? fullName;
  final DateTime? createdAt;
  final String? roleId;
  final String? languageId;

  factory RegisteredUser.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const AuthServiceException(AuthFailure.invalidResponse);
    }

    final id = value['id'];
    final email = value['email'];
    final isActive = value['is_active'];
    final isSuperuser = value['is_superuser'];
    final fullName = value['full_name'];
    final createdAt = value['created_at'];
    final roleId = value['role_id'];
    final languageId = value['language_id'];
    final parsedCreatedAt = createdAt is String
        ? DateTime.tryParse(createdAt)
        : null;

    if (id is! String ||
        email is! String ||
        (isActive != null && isActive is! bool) ||
        (isSuperuser != null && isSuperuser is! bool) ||
        (fullName != null && fullName is! String) ||
        (createdAt != null && createdAt is! String) ||
        (createdAt != null && parsedCreatedAt == null) ||
        (roleId != null && roleId is! String) ||
        (languageId != null && languageId is! String)) {
      throw const AuthServiceException(AuthFailure.invalidResponse);
    }

    return RegisteredUser(
      id: id,
      email: email,
      isActive: isActive as bool? ?? true,
      isSuperuser: isSuperuser as bool? ?? false,
      fullName: fullName as String?,
      createdAt: parsedCreatedAt,
      roleId: roleId as String?,
      languageId: languageId as String?,
    );
  }
}

class AuthHttpResponse {
  const AuthHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

abstract interface class AuthHttpClient {
  Future<AuthHttpResponse> post(
    Uri uri, {
    required String contentType,
    required String body,
  });
}

class IoAuthHttpClient implements AuthHttpClient {
  IoAuthHttpClient({HttpClient? client}) : this._(client ?? HttpClient());

  IoAuthHttpClient._(this._client);

  final HttpClient _client;

  @override
  Future<AuthHttpResponse> post(
    Uri uri, {
    required String contentType,
    required String body,
  }) async {
    final request = await _client.postUrl(uri);
    request.headers.set(HttpHeaders.contentTypeHeader, contentType);
    request.add(utf8.encode(body));

    final response = await request.close();
    final responseBody = await utf8.decoder.bind(response).join();
    return AuthHttpResponse(
      statusCode: response.statusCode,
      body: responseBody,
    );
  }

  void close({bool force = false}) {
    _client.close(force: force);
  }
}

class AuthService {
  factory AuthService({required Uri baseUrl, required AuthHttpClient client}) {
    return AuthService._(baseUrl: _normalizeBaseUrl(baseUrl), client: client);
  }

  AuthService._({required this._baseUrl, required this._client});

  final Uri _baseUrl;
  final AuthHttpClient _client;

  static Uri _normalizeBaseUrl(Uri baseUrl) {
    if ((baseUrl.scheme != 'http' && baseUrl.scheme != 'https') ||
        baseUrl.host.isEmpty ||
        baseUrl.userInfo.isNotEmpty ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'Must be an HTTP(S) origin or base path without credentials or query.',
      );
    }

    final path = baseUrl.path.endsWith('/') ? baseUrl.path : '${baseUrl.path}/';
    return baseUrl.replace(path: path);
  }

  Uri _endpoint(String path) => _baseUrl.resolve(path);

  Future<AuthToken> login({
    required String email,
    required String password,
  }) async {
    final formBody = Uri(
      queryParameters: {'username': email, 'password': password},
    ).query;

    final response = await _post(
      _endpoint('api/v1/login/access-token'),
      contentType: 'application/x-www-form-urlencoded',
      body: formBody,
    );

    if (response.statusCode != 200) {
      throw AuthServiceException(
        response.statusCode == 400
            ? AuthFailure.loginRejected
            : AuthFailure.server,
      );
    }

    return AuthToken.fromJson(_decodeJson(response.body));
  }

  Future<RegisteredUser> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final requestBody = <String, Object?>{
      'email': email,
      'password': password,
      'full_name': ?fullName,
    };

    final response = await _post(
      _endpoint('api/v1/users/signup'),
      contentType: 'application/json',
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw AuthServiceException(
        response.statusCode == 400
            ? AuthFailure.emailAlreadyRegistered
            : AuthFailure.server,
      );
    }

    return RegisteredUser.fromJson(_decodeJson(response.body));
  }

  Future<AuthHttpResponse> _post(
    Uri uri, {
    required String contentType,
    required String body,
  }) async {
    try {
      return await _client
          .post(uri, contentType: contentType, body: body)
          .timeout(const Duration(seconds: 20));
    } on SocketException {
      throw const AuthServiceException(AuthFailure.network);
    } on HttpException {
      throw const AuthServiceException(AuthFailure.network);
    } on TimeoutException {
      throw const AuthServiceException(AuthFailure.network);
    }
  }

  Object? _decodeJson(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const AuthServiceException(AuthFailure.invalidResponse);
    }
  }
}
