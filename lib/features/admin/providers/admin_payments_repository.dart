import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final adminPaymentsRepositoryProvider = Provider<AdminPaymentsRepository>((ref) {
  return AdminPaymentsRepository(Supabase.instance.client);
});

class AdminPaymentsRepository {
  final SupabaseClient _supabase;

  AdminPaymentsRepository(this._supabase);

  Future<List<Map<String, dynamic>>> getPendingPayments() async {
    final paymentsRaw = await _supabase.rpc(
      'admin_get_payments_enriched',
      params: {
        'p_statuses': ['pending_verification', 'voucher_uploaded'],
        'p_limit': 100,
      },
    );

    final payments = List<Map<String, dynamic>>.from(paymentsRaw as List);

    if (payments.isEmpty) return const [];

    final ids = payments.map((e) => e['id'].toString()).toList();

    final evidenceRaw = await _supabase
        .from('payment_evidence')
        .select()
        .inFilter('payment_id', ids)
        .order('uploaded_at', ascending: false);

    final evidence = List<Map<String, dynamic>>.from(evidenceRaw);

    final latestEvidence = <String, Map<String, dynamic>>{};
    for (final row in evidence) {
      final paymentId = row['payment_id']?.toString();
      if (paymentId == null) continue;
      latestEvidence.putIfAbsent(paymentId, () => row);
    }

    return payments.map((payment) {
      final id = payment['id']?.toString();
      return {
        ...payment,
        'latest_evidence': id == null ? null : latestEvidence[id],
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getRecentResolvedPayments() async {
    final rows = await _supabase.rpc(
      'admin_get_payments_enriched',
      params: {
        'p_statuses': ['paid', 'rejected'],
        'p_limit': 30,
      },
    );

    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<String?> createVoucherSignedUrl(String storagePath) async {
    if (storagePath.trim().isEmpty) return null;

    return _supabase.storage
        .from('payment-evidence')
        .createSignedUrl(storagePath, 60 * 10);
  }

  Future<Map<String, dynamic>> verifyTransfer({
    required String paymentId,
    required double amount,
    String? bankReference,
    String? transactionId,
    String? notes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'admin_verify_bank_transfer',
        params: {
          'p_payment_id': paymentId,
          'p_amount_confirmed': amount,
          'p_bank_reference': _nullIfBlank(bankReference),
          'p_bank_transaction_id': _nullIfBlank(transactionId),
          'p_notes': _nullIfBlank(notes),
        },
      );

      return _asMap(response);
    } on PostgrestException catch (e) {
      throw AdminPaymentException(_friendly(e.message));
    }
  }

  Future<Map<String, dynamic>> rejectTransfer({
    required String paymentId,
    required String reason,
    String? notes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'admin_reject_bank_transfer',
        params: {
          'p_payment_id': paymentId,
          'p_reason': reason.trim(),
          'p_notes': _nullIfBlank(notes),
        },
      );

      return _asMap(response);
    } on PostgrestException catch (e) {
      throw AdminPaymentException(_friendly(e.message));
    }
  }




  Future<Map<String, dynamic>> getPlatformRevenueSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final response = await _supabase.rpc(
        'admin_get_platform_revenue_summary',
        params: {
          'p_from': from.toUtc().toIso8601String(),
          'p_to': to.toUtc().toIso8601String(),
        },
      );

      if (response is List && response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first as Map);
      }

      return const {};
    } on PostgrestException catch (e) {
      throw AdminPaymentException(_friendly(e.message));
    }
  }

  Future<List<Map<String, dynamic>>> getPlatformCommissionEntries({
    int limit = 100,
  }) async {
    try {
      final response = await _supabase.rpc(
        'admin_get_platform_commission_entries',
        params: {'p_limit': limit},
      );

      if (response is List) {
        return response
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      return const [];
    } on PostgrestException catch (e) {
      throw AdminPaymentException(_friendly(e.message));
    }
  }

  Future<List<Map<String, dynamic>>> getSettlementAudit({
    int limit = 50,
  }) async {
    try {
      final response = await _supabase.rpc(
        'admin_get_settlement_audit',
        params: {'p_limit': limit},
      );

      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      }

      return const [];
    } on PostgrestException catch (e) {
      throw AdminPaymentException(_friendly(e.message));
    }
  }

  Future<List<Map<String, dynamic>>> getOpenSettlements() async {
    final rows = await _supabase
        .from('settlements')
        .select()
        .inFilter('status', ['requested', 'processing'])
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> getRecentSettlements() async {
    final rows = await _supabase
        .from('settlements')
        .select()
        .inFilter('status', ['paid', 'rejected', 'cancelled'])
        .order('created_at', ascending: false)
        .limit(30);

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> createWeeklySettlements({
    required DateTime cutoffAt,
    required DateTime scheduledFor,
  }) async {
    try {
      final response = await _supabase.rpc(
        'admin_create_weekly_settlements',
        params: {
          'p_cutoff_at': cutoffAt.toUtc().toIso8601String(),
          'p_scheduled_for':
              '${scheduledFor.year.toString().padLeft(4, '0')}-'
              '${scheduledFor.month.toString().padLeft(2, '0')}-'
              '${scheduledFor.day.toString().padLeft(2, '0')}',
        },
      );

      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
      return const [];
    } on PostgrestException catch (e) {
      throw AdminPaymentException(_friendly(e.message));
    }
  }

  Future<Map<String, dynamic>> markSettlementProcessing(
    String settlementId,
  ) async {
    try {
      final response = await _supabase.rpc(
        'admin_mark_settlement_processing',
        params: {'p_settlement_id': settlementId},
      );
      return _asMap(response);
    } on PostgrestException catch (e) {
      throw AdminPaymentException(_friendly(e.message));
    }
  }

  Future<Map<String, dynamic>> markSettlementPaid({
    required String settlementId,
    String? payoutReference,
    String? notes,
  }) async {
    final reference = _nullIfBlank(payoutReference);
    if (reference == null) {
      throw const AdminPaymentException(
        'Ingresa la referencia bancaria del pago realizado.',
      );
    }
    try {
      final response = await _supabase.rpc(
        'admin_mark_settlement_paid',
        params: {
          'p_settlement_id': settlementId,
          'p_payout_reference': reference,
          'p_notes': _nullIfBlank(notes),
        },
      );
      return _asMap(response);
    } on PostgrestException catch (e) {
      throw AdminPaymentException(_friendly(e.message));
    }
  }

  Future<Map<String, dynamic>> rejectSettlement({
    required String settlementId,
    required String reason,
    String? notes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'admin_reject_settlement',
        params: {
          'p_settlement_id': settlementId,
          'p_reason': reason.trim(),
          'p_notes': _nullIfBlank(notes),
        },
      );
      return _asMap(response);
    } on PostgrestException catch (e) {
      throw AdminPaymentException(_friendly(e.message));
    }
  }

  Map<String, dynamic> _asMap(dynamic response) {
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    throw const AdminPaymentException('Respuesta inesperada del servidor.');
  }

  String? _nullIfBlank(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String _friendly(String message) {
    if (message.contains('ADMIN_REQUIRED')) {
      return 'Esta operación requiere una cuenta administradora.';
    }
    if (message.contains('ACCOUNT_NOT_ACTIVE')) {
      return 'La cuenta administradora no está activa.';
    }
    if (message.contains('PAYMENT_AMOUNT_MISMATCH')) {
      return 'El monto confirmado no coincide con el valor esperado.';
    }
    if (message.contains('PAYMENT_NOT_FOUND')) {
      return 'No encontramos el pago.';
    }
    if (message.contains('INVALID_PAYMENT_STATE')) {
      return 'El pago cambió de estado. Actualiza la bandeja.';
    }
    if (message.contains('FIXIS_REVENUE_ACCOUNT_NOT_FOUND')) {
      return 'No encontramos la cuenta contable de ingresos FIXIS.';
    }
    if (message.contains('INVALID_PERIOD')) {
      return 'El período seleccionado no es válido.';
    }
    if (message.contains('SETTLEMENT_NOT_FOUND')) {
      return 'No encontramos la liquidación.';
    }
    if (message.contains('INVALID_SETTLEMENT_STATE')) {
      return 'La liquidación cambió de estado. Actualiza la pantalla.';
    }
    if (message.contains('PAYOUT_REFERENCE_REQUIRED')) {
      return 'Ingresa la referencia bancaria del pago realizado.';
    }
    if (message.contains('REJECTION_REASON_REQUIRED')) {
      return 'Debes indicar un motivo para rechazar la liquidación.';
    }
    if (message.contains('SETTLEMENT_ALLOCATION_INCOMPLETE')) {
      return 'No se pudo asignar completamente el saldo a la liquidación.';
    }
    if (message.contains('PAID_PAYMENT_CANNOT_BE_REJECTED')) {
      return 'Un pago confirmado ya no puede rechazarse.';
    }
    return message;
  }
}

class AdminPaymentException implements Exception {
  final String message;
  const AdminPaymentException(this.message);

  @override
  String toString() => message;
}
