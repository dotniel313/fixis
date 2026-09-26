import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(Supabase.instance.client);
});

final myCustomerJobsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(customerRepositoryProvider).getMyJobs();
});

class CustomerRepository {
  final SupabaseClient _supabase;

  CustomerRepository(this._supabase);

  Future<List<Map<String, dynamic>>> getMyJobs() async {
    final customerId = _supabase.auth.currentUser?.id;
    if (customerId == null) return const [];
    final rows = await _supabase
        .from('jobs')
        .select()
        .eq('client_id', customerId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> createJob({
    required String title,
    required String category,
    required String address,
    String? description,
    String? addressReference,
    DateTime? requestedVisitAt,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _supabase.rpc(
        'create_job',
        params: {
          'p_title': title.trim(),
          'p_category': category.trim(),
          'p_address': address.trim(),
          'p_description': _blankToNull(description),
          'p_address_reference': _blankToNull(addressReference),
          'p_requested_visit_at': requestedVisitAt?.toUtc().toIso8601String(),
          'p_latitude': latitude,
          'p_longitude': longitude,
        },
      );
      return _asMap(response);
    } on PostgrestException catch (e) {
      throw CustomerActionException(_friendlyMessage(e.message));
    }
  }


  Stream<Map<String, dynamic>> watchJob(String jobId) {
    return _supabase
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('id', jobId)
        .map((rows) {
          if (rows.isEmpty) return <String, dynamic>{};
          return Map<String, dynamic>.from(rows.first);
        });
  }

  Stream<Map<String, dynamic>?> watchLiveLocation(String jobId) {
    return _supabase
        .from('professional_live_locations')
        .stream(primaryKey: ['id'])
        .eq('job_id', jobId)
        .map((rows) {
          if (rows.isEmpty) return null;
          return Map<String, dynamic>.from(rows.first);
        });
  }

  Future<Map<String, dynamic>?> getJob(String jobId) async {
    final customerId = _supabase.auth.currentUser?.id;
    if (customerId == null) return null;
    final row = await _supabase
        .from('jobs')
        .select()
        .eq('id', jobId)
        .eq('client_id', customerId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> getQuotesForJob(String jobId) async {
    final rows = await _supabase
        .from('quotes')
        .select()
        .eq('job_id', jobId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> acceptQuote(String quoteId) async {
    try {
      final response = await _supabase.rpc(
        'accept_quote_customer',
        params: {'p_quote_id': quoteId},
      );
      return _asMap(response);
    } on PostgrestException catch (e) {
      throw CustomerActionException(_friendlyMessage(e.message));
    }
  }

  Future<Map<String, dynamic>> acceptQuoteRevision(String quoteId) async {
    try {
      final response = await _supabase.rpc(
        'accept_quote_revision_customer',
        params: {'p_quote_id': quoteId},
      );
      return _asMap(response);
    } on PostgrestException catch (e) {
      throw CustomerActionException(_friendlyMessage(e.message));
    }
  }

  Future<Map<String, dynamic>> rejectQuoteRevision(String quoteId) async {
    try {
      final response = await _supabase.rpc(
        'reject_quote_revision_customer',
        params: {'p_quote_id': quoteId},
      );
      return _asMap(response);
    } on PostgrestException catch (e) {
      throw CustomerActionException(_friendlyMessage(e.message));
    }
  }

  Future<Map<String, dynamic>?> getPaymentForJob(String jobId) async {
    final customerId = _supabase.auth.currentUser?.id;
    if (customerId == null) return null;
    final row = await _supabase
        .from('payments')
        .select()
        .eq('job_id', jobId)
        .eq('customer_id', customerId)
        .maybeSingle();

    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> prepareJobPayment({
    required String jobId,
    required String paymentMethod,
  }) async {
    try {
      final response = await _supabase.rpc(
        'prepare_job_payment',
        params: {
          'p_job_id': jobId,
          'p_payment_method': paymentMethod,
        },
      );
      return _asMap(response);
    } on PostgrestException catch (e) {
      throw CustomerActionException(_friendlyMessage(e.message));
    }
  }

  Future<Map<String, dynamic>?> getActiveBankAccount() async {
    final row = await _supabase
        .from('payment_bank_accounts')
        .select()
        .eq('is_active', true)
        .order('priority', ascending: true)
        .order('created_at', ascending: true)
        .limit(1)
        .maybeSingle();

    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>?> getAcceptedQuoteForJob(String jobId) async {
    final job = await getJob(jobId);
    final quoteId = job?['accepted_quote_id']?.toString();

    if (quoteId == null || quoteId.isEmpty) return null;

    final row = await _supabase
        .from('quotes')
        .select()
        .eq('id', quoteId)
        .maybeSingle();

    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> uploadBankTransferEvidence({
    required String paymentId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
    double? declaredAmount,
    String? declaredBank,
    String? declaredReference,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const CustomerActionException('Tu sesión expiró.');
    }

    final safeExtension = extension.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final fileExtension = safeExtension.isEmpty ? 'jpg' : safeExtension;

    final storagePath =
        '$userId/$paymentId/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    try {
      await _supabase.storage.from('payment-evidence').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: false,
            ),
          );

      try {
        final response = await _supabase.rpc(
          'submit_bank_transfer_evidence',
          params: {
            'p_payment_id': paymentId,
            'p_storage_path': storagePath,
            'p_declared_amount': declaredAmount,
            'p_declared_bank': _blankToNull(declaredBank),
            'p_declared_reference': _blankToNull(declaredReference),
          },
        );
        return _asMap(response);
      } catch (_) {
        // Best-effort cleanup if database registration fails.
        try {
          await _supabase.storage
              .from('payment-evidence')
              .remove([storagePath]);
        } catch (_) {
          // The evidence bucket is private; an orphan does not confirm payment.
        }
        rethrow;
      }
    } on StorageException catch (e) {
      throw CustomerActionException(
        'No pudimos subir el comprobante: ${e.message}',
      );
    } on PostgrestException catch (e) {
      throw CustomerActionException(_friendlyMessage(e.message));
    }
  }

  Future<Map<String, dynamic>> uploadInitialJobPhoto({
    required String jobId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const CustomerActionException('Tu sesión expiró.');
    }

    final safeExtension = extension.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final ext = switch (safeExtension) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpg',
    };
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    if (bytes.isEmpty || bytes.length > 8388608) {
      throw const CustomerActionException('Cada foto debe pesar menos de 8 MB.');
    }

    final fileName = '${DateTime.now().microsecondsSinceEpoch}.$ext';
    final storagePath = '$userId/$jobId/issue_initial/$fileName';

    try {
      await _supabase.storage.from('job-evidence').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );

      try {
        final response = await _supabase.rpc(
          'register_job_attachment',
          params: {
            'p_job_id': jobId,
            'p_attachment_type': 'issue_initial',
            'p_storage_path': storagePath,
            'p_mime_type': contentType,
            'p_file_size_bytes': bytes.length,
          },
        );
        return _asMap(response);
      } catch (_) {
        try {
          await _supabase.storage.from('job-evidence').remove([storagePath]);
        } catch (_) {}
        rethrow;
      }
    } on StorageException catch (e) {
      throw CustomerActionException('No pudimos subir la foto: ${e.message}');
    } on PostgrestException catch (e) {
      throw CustomerActionException(_friendlyMessage(e.message));
    }
  }

  Future<List<Map<String, dynamic>>> getJobAttachments(String jobId) async {
    final rows = await _supabase
        .from('job_attachments')
        .select()
        .eq('job_id', jobId)
        .order('created_at', ascending: true);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<String> createJobAttachmentSignedUrl(String storagePath) {
    return _supabase.storage.from('job-evidence').createSignedUrl(storagePath, 900);
  }

  Map<String, dynamic> _asMap(dynamic response) {
    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);
    throw const CustomerActionException('Respuesta inesperada del servidor.');
  }

  String? _blankToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  String _friendlyMessage(String raw) {
    final message = raw.toUpperCase();
    if (message.contains('AUTHENTICATION_REQUIRED')) return 'Tu sesión expiró.';
    if (message.contains('NOT_A_CUSTOMER')) return 'Esta cuenta no está configurada como cliente.';
    if (message.contains('ACCOUNT_NOT_ACTIVE')) return 'Tu cuenta no está activa.';
    if (message.contains('TITLE_REQUIRED')) return 'Ingresa un título para la solicitud.';
    if (message.contains('CATEGORY_REQUIRED')) return 'Selecciona una categoría.';
    if (message.contains('ADDRESS_REQUIRED')) return 'Ingresa la dirección del servicio.';
    if (message.contains('ADDRESS_REFERENCE_TOO_LONG')) return 'La referencia es demasiado extensa.';
    if (message.contains('REQUESTED_VISIT_IN_PAST')) return 'Selecciona una fecha y hora futura.';
    if (message.contains('INITIAL_PHOTO_LIMIT_REACHED')) return 'Puedes adjuntar hasta 3 fotos iniciales.';
    if (message.contains('ATTACHMENT_TOO_LARGE')) return 'Cada foto debe pesar menos de 8 MB.';
    if (message.contains('JOB_NOT_OWNED_BY_CUSTOMER')) return 'No tienes permiso sobre este servicio.';
    if (message.contains('INVALID_JOB_STATE')) return 'El servicio cambió de estado. Actualiza e intenta nuevamente.';
    if (message.contains('INVALID_QUOTE_STATE')) return 'La cotización ya no está disponible.';
    if (message.contains('QUOTE_REVISION_PENDING')) return 'Hay una revisión de cotización pendiente.';
    if (message.contains('NOT_A_QUOTE_REVISION')) return 'La propuesta seleccionada no es una revisión.';
    if (message.contains('QUOTE_REVISION_PARENT_MISMATCH')) return 'La cotización original cambió. Actualiza el servicio.';
    if (message.contains('CURRENT_FINANCIAL_SNAPSHOT_REQUIRED')) return 'No encontramos el resumen financiero vigente.';
    if (message.contains('ANOTHER_QUOTE_ALREADY_ACCEPTED')) return 'Ya aceptaste otra cotización para este servicio.';
    if (message.contains('JOB_NOT_READY_FOR_PAYMENT')) return 'El servicio todavía no está listo para pago.';
    if (message.contains('FINANCIAL_SNAPSHOT_REQUIRED')) return 'No encontramos el resumen financiero del servicio.';
    if (message.contains('PAYMENT_NOT_FOUND')) return 'No encontramos el pago.';
    if (message.contains('PAYMENT_NOT_OWNED_BY_CUSTOMER')) return 'No tienes permiso sobre este pago.';
    if (message.contains('PAYMENT_METHOD_NOT_BANK_TRANSFER')) return 'Este pago no corresponde a una transferencia.';
    if (message.contains('INVALID_PAYMENT_STATE')) return 'El pago cambió de estado. Actualiza e intenta nuevamente.';
    if (message.contains('EVIDENCE_STORAGE_PATH_REQUIRED')) return 'Selecciona un comprobante válido.';
    return 'No fue posible completar la operación.';
  }
}

class CustomerActionException implements Exception {
  final String message;
  const CustomerActionException(this.message);
  @override
  String toString() => message;
}
