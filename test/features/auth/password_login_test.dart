import 'dart:convert';

import 'package:fixis_pro/features/auth/providers/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  SupabaseClient clientWithResponse(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
      httpClient: MockClient(handler),
    );
    addTearDown(client.dispose);
    return client;
  }

  test('password login normalizes email but preserves the exact password',
      () async {
    late http.Request captured;
    final client = clientWithResponse((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'code': 'invalid_credentials',
          'msg': 'Invalid login credentials',
        }),
        400,
        headers: {
          'content-type': 'application/json',
          'x-supabase-api-version': '2024-01-01',
        },
      );
    });

    await expectLater(
      AuthRepository(client).signInWithPassword(
        '  REVIEW@EXAMPLE.COM  ',
        ' password with spaces ',
      ),
      throwsA(isA<AuthFlowException>().having(
        (error) => error.message,
        'message',
        'El correo o la contraseña no son correctos.',
      )),
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/auth/v1/token');
    expect(captured.url.queryParameters['grant_type'], 'password');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['email'], 'review@example.com');
    expect(body['password'], ' password with spaces ');
    expect(body.containsKey('create_user'), false);
  });

  test('password login reports rate limiting without exposing response detail',
      () async {
    final client = clientWithResponse((request) async => http.Response(
          jsonEncode({
            'code': 'over_request_rate_limit',
            'msg': 'Internal sensitive detail',
          }),
          429,
          headers: {
          'content-type': 'application/json',
          'x-supabase-api-version': '2024-01-01',
        },
        ));

    await expectLater(
      AuthRepository(client).signInWithPassword('review@example.com', 'secret'),
      throwsA(isA<AuthFlowException>().having(
        (error) => error.message,
        'message',
        'Has realizado varios intentos. Espera antes de volver a ingresar.',
      )),
    );
  });

  test('network errors do not leak request or password details', () async {
    final client = clientWithResponse((request) async {
      throw http.ClientException('secret request detail');
    });

    await expectLater(
      AuthRepository(client).signInWithPassword('review@example.com', 'secret'),
      throwsA(isA<AuthFlowException>().having(
        (error) => error.message,
        'message',
        'No fue posible iniciar sesión. Inténtalo nuevamente.',
      )),
    );
  });
}
