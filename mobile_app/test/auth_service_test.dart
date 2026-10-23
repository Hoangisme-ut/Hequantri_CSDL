import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/auth/auth_service.dart';

void main() {
  const baseUrl = 'https://api.example.test';

  group('AuthService login', () {
    test(
      'posts form-urlencoded fields and parses the token response',
      () async {
        final client = FakeAuthHttpClient(
          const AuthHttpResponse(
            statusCode: 200,
            body: '{"access_token":"signed-token","token_type":"bearer"}',
          ),
        );
        final service = AuthService(
          baseUrl: Uri.parse(baseUrl),
          client: client,
        );

        final token = await service.login(
          email: 'visitor+test@example.com',
          password: 'space & symbols',
        );

        expect(client.method, 'POST');
        expect(client.uri, Uri.parse('$baseUrl/api/v1/login/access-token'));
        expect(client.contentType, 'application/x-www-form-urlencoded');
        expect(Uri.splitQueryString(client.body!), {
          'username': 'visitor+test@example.com',
          'password': 'space & symbols',
        });
        expect(token.accessToken, 'signed-token');
        expect(token.tokenType, 'bearer');
      },
    );

    test(
      'maps the tested HTTP 400 login rejection to a safe failure',
      () async {
        final client = FakeAuthHttpClient(
          const AuthHttpResponse(statusCode: 400, body: '{"detail":"private"}'),
        );
        final service = AuthService(
          baseUrl: Uri.parse(baseUrl),
          client: client,
        );

        await expectLater(
          service.login(email: 'visitor@example.com', password: 'wrong'),
          throwsA(
            isA<AuthServiceException>().having(
              (error) => error.failure,
              'failure',
              AuthFailure.loginRejected,
            ),
          ),
        );
      },
    );

    test('does not expose backend error details', () async {
      const privateDetail = 'do not expose this detail';
      final client = FakeAuthHttpClient(
        const AuthHttpResponse(
          statusCode: 400,
          body: '{"detail":"$privateDetail"}',
        ),
      );
      final service = AuthService(baseUrl: Uri.parse(baseUrl), client: client);

      try {
        await service.login(email: 'visitor@example.com', password: 'wrong');
        fail('Expected login to fail.');
      } on AuthServiceException catch (error) {
        expect(error.toString(), isNot(contains(privateDetail)));
      }
    });
  });

  group('AuthService register', () {
    test(
      'posts JSON and parses the public user without creating a token',
      () async {
        final client = FakeAuthHttpClient(
          const AuthHttpResponse(
            statusCode: 200,
            body: '''
            {
              "id": "user-id",
              "email": "visitor@example.com",
              "is_active": true,
              "is_superuser": false,
              "full_name": "Visitor",
              "created_at": "2026-10-23T10:00:00Z",
              "role_id": null,
              "language_id": null
            }
          ''',
          ),
        );
        final service = AuthService(
          baseUrl: Uri.parse(baseUrl),
          client: client,
        );

        final result = await service.register(
          email: 'visitor@example.com',
          password: 'password123',
          fullName: 'Visitor',
        );

        expect(client.method, 'POST');
        expect(client.uri, Uri.parse('$baseUrl/api/v1/users/signup'));
        expect(client.contentType, 'application/json');
        expect(jsonDecode(client.body!), {
          'email': 'visitor@example.com',
          'password': 'password123',
          'full_name': 'Visitor',
        });
        expect(result, isA<RegisteredUser>());
        expect(result.id, 'user-id');
        expect(result.email, 'visitor@example.com');
        expect(result.fullName, 'Visitor');
        expect(result.isActive, isTrue);
        expect(result.isSuperuser, isFalse);
        expect(result.createdAt, DateTime.utc(2026, 10, 23, 10));
        expect(result, isNot(isA<AuthToken>()));
      },
    );

    test('omits optional full_name when it is not supplied', () async {
      final client = FakeAuthHttpClient(
        const AuthHttpResponse(
          statusCode: 200,
          body: '{"id":"user-id","email":"visitor@example.com"}',
        ),
      );
      final service = AuthService(baseUrl: Uri.parse(baseUrl), client: client);

      final result = await service.register(
        email: 'visitor@example.com',
        password: 'password123',
      );

      expect(jsonDecode(client.body!), {
        'email': 'visitor@example.com',
        'password': 'password123',
      });
      expect(result.fullName, isNull);
    });

    test('maps the tested HTTP 400 duplicate email response', () async {
      final client = FakeAuthHttpClient(
        const AuthHttpResponse(
          statusCode: 400,
          body: '{"detail":"sensitive backend detail"}',
        ),
      );
      final service = AuthService(baseUrl: Uri.parse(baseUrl), client: client);

      await expectLater(
        service.register(email: 'visitor@example.com', password: 'password123'),
        throwsA(
          isA<AuthServiceException>().having(
            (error) => error.failure,
            'failure',
            AuthFailure.emailAlreadyRegistered,
          ),
        ),
      );
    });

    test('maps unclassified HTTP statuses to a safe server failure', () async {
      final client = FakeAuthHttpClient(
        const AuthHttpResponse(statusCode: 500, body: '{"detail":"hidden"}'),
      );
      final service = AuthService(baseUrl: Uri.parse(baseUrl), client: client);

      await expectLater(
        service.register(email: 'visitor@example.com', password: 'password123'),
        throwsA(
          isA<AuthServiceException>().having(
            (error) => error.failure,
            'failure',
            AuthFailure.server,
          ),
        ),
      );
    });
  });

  test(
    'maps transport failures without exposing the underlying error',
    () async {
      final client = FakeAuthHttpClient.withError(
        const SocketException('offline'),
      );
      final service = AuthService(baseUrl: Uri.parse(baseUrl), client: client);

      await expectLater(
        service.login(email: 'visitor@example.com', password: 'password123'),
        throwsA(
          isA<AuthServiceException>().having(
            (error) => error.failure,
            'failure',
            AuthFailure.network,
          ),
        ),
      );
    },
  );

  test('rejects malformed successful response bodies safely', () async {
    final client = FakeAuthHttpClient(
      const AuthHttpResponse(statusCode: 200, body: '{"access_token":'),
    );
    final service = AuthService(baseUrl: Uri.parse(baseUrl), client: client);

    await expectLater(
      service.login(email: 'visitor@example.com', password: 'password123'),
      throwsA(
        isA<AuthServiceException>().having(
          (error) => error.failure,
          'failure',
          AuthFailure.invalidResponse,
        ),
      ),
    );
  });

  test('rejects a base URL containing credentials or query parameters', () {
    expect(
      () => AuthService(
        baseUrl: Uri.parse('https://user:password@api.example.test'),
        client: FakeAuthHttpClient(
          const AuthHttpResponse(statusCode: 200, body: '{}'),
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => AuthService(
        baseUrl: Uri.parse('https://api.example.test?token=secret'),
        client: FakeAuthHttpClient(
          const AuthHttpResponse(statusCode: 200, body: '{}'),
        ),
      ),
      throwsArgumentError,
    );
  });
}

class FakeAuthHttpClient implements AuthHttpClient {
  FakeAuthHttpClient(AuthHttpResponse response) : this._(response: response);

  FakeAuthHttpClient.withError(Object error) : this._(error: error);

  FakeAuthHttpClient._({this.response, this.error});

  final AuthHttpResponse? response;
  final Object? error;
  String? method;
  Uri? uri;
  String? contentType;
  String? body;

  @override
  Future<AuthHttpResponse> post(
    Uri requestUri, {
    required String contentType,
    required String body,
  }) async {
    method = 'POST';
    uri = requestUri;
    this.contentType = contentType;
    this.body = body;

    if (error case final error?) {
      throw error;
    }
    return response!;
  }
}
