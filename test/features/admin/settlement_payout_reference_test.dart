import 'dart:convert';

import 'package:fixis_pro/features/admin/providers/admin_payments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const settlementId = '11111111-1111-4111-8111-111111111111';

  test('sin referencia no se solicita marcar la liquidación pagada', () async {
    var requests = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((_) async {
        requests++;
        throw StateError('No se debe solicitar el pago');
      }),
    );
    addTearDown(client.dispose);
    final repository = AdminPaymentsRepository(client);

    for (final reference in <String?>[null, '', '  \n  ']) {
      await expectLater(
        repository.markSettlementPaid(
          settlementId: settlementId,
          payoutReference: reference,
        ),
        throwsA(
          isA<AdminPaymentException>().having(
            (error) => error.message,
            'mensaje',
            contains('referencia bancaria'),
          ),
        ),
      );
    }

    expect(requests, 0);
  });

  test('envía la referencia normalizada y las notas opcionales al RPC', () async {
    late http.Request captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'id': settlementId, 'status': 'paid'}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = AdminPaymentsRepository(client);

    final result = await repository.markSettlementPaid(
      settlementId: settlementId,
      payoutReference: '  REF-123  ',
      notes: '  ',
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/rest/v1/rpc/admin_mark_settlement_paid');
    expect(jsonDecode(captured.body), {
      'p_settlement_id': settlementId,
      'p_payout_reference': 'REF-123',
      'p_notes': null,
    });
    expect(result['status'], 'paid');
  });
}
