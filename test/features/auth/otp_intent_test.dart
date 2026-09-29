import 'dart:convert';

import 'package:fixis_pro/features/auth/providers/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('ingresar con OTP no solicita crear una cuenta nueva', () async {
    late http.Request captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    await AuthRepository(client).sendOtp('  TEST@EXAMPLE.COM  ');

    expect(captured.method, 'POST');
    expect(captured.url.path, '/auth/v1/otp');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['email'], 'test@example.com');
    expect(body['create_user'], false);
  });

  test('alta cliente solicita crear cuenta con nombre normalizado', () async {
    late http.Request captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    await AuthRepository(client).sendCustomerSignupOtp(
      email: '  TEST@EXAMPLE.COM  ',
      fullName: '  Cliente Prueba  ',
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/auth/v1/otp');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['email'], 'test@example.com');
    expect(body['create_user'], true);
    expect(body['data']['full_name'], 'Cliente Prueba');
  });
}
