// FIXIS PRO v1.4.1 - Jobs, cotizaciones, snapshot financiero y finalización segura mediante RPC.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  return JobsRepository(Supabase.instance.client);
});

final myActiveJobsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    return Stream.value(const <Map<String, dynamic>>[]);
  }

  // v1.9.3.2:
  // `customer_approved` is a terminal historical state. It closes the
  // professional's operational lifecycle and must not remain in Active Jobs.
  // We intentionally keep the backend status unchanged because it is already
  // tied to the audited financial approval flow.
  const activeStatuses = <String>{
    'accepted',
    'quote_submitted',
    'authorized',
    'en_route',
    'arrived',
    'quote_revision_pending',
    'in_progress',
    'work_completed',
  };

  // v1.8.5.3: no usamos filtro Realtime por assigned_pro_id.
  // El backend ya limita las filas por RLS (professional = assigned self),
  // y filtramos nuevamente en cliente como defensa adicional. Esto evita
  // el error de suscripción Realtime P0001 "invalid column for filter".
  return Supabase.instance.client
      .from('jobs')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map(
        (rows) => rows
            .where(
              (job) =>
                  job['assigned_pro_id']?.toString() == user.id &&
                  activeStatuses.contains(job['status']?.toString()),
            )
            .toList(growable: false),
      );
});

enum JobActionErrorCode {
  authenticationRequired,
  profileNotFound,
  notProfessional,
  professionalNotApproved,
  accountNotActive,
  jobNotFound,
  jobAlreadyTaken,
  jobNotAssigned,
  invalidJobState,
  quoteNotFound,
  quoteNotOwnedByUser,
  invalidQuoteState,
  invalidQuoteAmount,
  quoteTotalMustBePositive,
  acceptedQuoteRequired,
  financialSnapshotRequired,
  professionalNotAvailable,
  professionalLocationRequired,
  categoryNotMatched,
  jobOutsideServiceRadius,
  jobAlreadyAssigned,
  liveLocationNotFound,
  liveLocationStale,
  locationAccuracyTooLow,
  arrivalTooFar,
  serviceLocationRequired,
  unknown,
}

class JobActionException implements Exception {
  final JobActionErrorCode code;
  final String message;

  const JobActionException(this.code, this.message);

  @override
  String toString() => message;
}

class JobsRepository {
  final SupabaseClient _supabase;

  JobsRepository(this._supabase);

  Future<String> uploadEvidence(
    File imageFile,
    String jobId,
    String type,
  ) async {
    try {
      final fileName =
          '${jobId}_${type}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$jobId/$fileName';

      await _supabase.storage.from('evidencias_pro').upload(
            path,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      return path;
    } catch (e) {
      throw Exception('Error al subir la imagen $type: $e');
    }
  }

  Future<Map<String, dynamic>> updateProfessionalPresence({
    required bool isAvailable,
    double? latitude,
    double? longitude,
    double? serviceRadiusKm,
  }) async {
    try {
      final response = await _supabase.rpc(
        'update_professional_presence',
        params: {
          'p_is_available': isAvailable,
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_service_radius_km': serviceRadiusKm,
        },
      );
      return _asMap(response);
    } on PostgrestException catch (e) {
      throw _mapRpcException(e);
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyJobs() async {
    try {
      final response = await _supabase.rpc('get_nearby_jobs');
      if (response is! List) return const <Map<String, dynamic>>[];
      return response
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw _mapRpcException(e);
    }
  }

  Future<Map<String, dynamic>> acceptNearbyJob(String jobId) async {
    try {
      final response = await _supabase.rpc(
        'accept_nearby_job',
        params: {'p_job_id': jobId},
      );
      return _asMap(response);
    } on PostgrestException catch (e) {
      throw _mapRpcException(e);
    } catch (e) {
      if (e is JobActionException) rethrow;
      throw const JobActionException(
        JobActionErrorCode.unknown,
        'No fue posible aceptar esta oportunidad.',
      );
    }
  }

  Future<Map<String, dynamic>> createOrUpdateQuote({
    required String jobId,
    required double laborAmount,
    required double materialsAmount,
    required double otherAmount,
    String? notes,
    DateTime? expiresAt,
  }) async {
    try {
      final response = await _supabase.rpc(
        'create_quote',
        params: {
          'p_job_id': jobId,
          'p_labor_amount': laborAmount,
          'p_materials_amount': materialsAmount,
          'p_other_amount': otherAmount,
          'p_notes': _nullIfBlank(notes),
          'p_expires_at': expiresAt?.toUtc().toIso8601String(),
        },
      );

      return _asMap(response);
    } on PostgrestException catch (e) {
      throw _mapRpcException(e);
    } catch (e) {
      if (e is JobActionException) rethrow;
      throw const JobActionException(
        JobActionErrorCode.unknown,
        'No fue posible guardar la cotización.',
      );
    }
  }

  Future<Map<String, dynamic>> submitQuote(String quoteId) async {
    try {
      final response = await _supabase.rpc(
        'submit_quote',
        params: {'p_quote_id': quoteId},
      );

      return _asMap(response);
    } on PostgrestException catch (e) {
      throw _mapRpcException(e);
    } catch (e) {
      if (e is JobActionException) rethrow;
      throw const JobActionException(
        JobActionErrorCode.unknown,
        'No fue posible enviar la cotización.',
      );
    }
  }

  Future<Map<String, dynamic>?> getQuoteForJob(String jobId) async {
    try {
      final job = await getJobById(jobId);
      final preferredQuoteId =
          job?['pending_quote_revision_id']?.toString() ??
          job?['accepted_quote_id']?.toString();

      if (preferredQuoteId != null && preferredQuoteId.isNotEmpty) {
        final preferred = await _supabase
            .from('quotes')
            .select()
            .eq('id', preferredQuoteId)
            .maybeSingle();
        if (preferred != null) {
          return Map<String, dynamic>.from(preferred);
        }
      }

      final rows = await _supabase
          .from('quotes')
          .select()
          .eq('job_id', jobId)
          .order('revision_number', ascending: false)
          .order('created_at', ascending: false)
          .limit(1);

      if ((rows as List).isEmpty) return null;
      return Map<String, dynamic>.from(rows.first as Map);
    } on PostgrestException catch (e) {
      throw _mapRpcException(e);
    }
  }

  Future<List<Map<String, dynamic>>> getQuotesForJob(String jobId) async {
    try {
      final rows = await _supabase
          .from('quotes')
          .select()
          .eq('job_id', jobId)
          .order('revision_number', ascending: false)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw _mapRpcException(e);
    }
  }

  Future<Map<String, dynamic>> submitQuoteRevision({
    required String jobId,
    required double laborAmount,
    required double materialsAmount,
    required double otherAmount,
    required String revisionReason,
    String? notes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'submit_quote_revision',
        params: {
          'p_job_id': jobId,
          'p_labor_amount': laborAmount,
          'p_materials_amount': materialsAmount,
          'p_other_amount': otherAmount,
          'p_revision_reason': revisionReason.trim(),
          'p_notes': _nullIfBlank(notes),
        },
      );
      return _asMap(response);
    } on PostgrestException catch (e) {
      throw _mapRpcException(e);
    }
  }

  Future<Map<String, dynamic>> cancelQuoteRevision(String quoteId) async {
    try {
      final response = await _supabase.rpc(
        'cancel_quote_revision',
        params: {'p_quote_id': quoteId},
      );
      return _asMap(response);
    } on PostgrestException catch (e) {
      throw _mapRpcException(e);
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

  Future<Map<String, dynamic>?> getJobById(String jobId) async {
    try {
      final response = await _supabase
          .from('jobs')
          .select()
          .eq('id', jobId)
          .maybeSingle();

      if (response == null) return null;
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      throw _mapRpcException(e);
    }
  }

  Future<List<Map<String, dynamic>>> getJobAttachments(String jobId) async {
    try {
      final rows = await _supabase
          .from('job_attachments')
          .select()
          .eq('job_id', jobId)
          .order('created_at', ascending: true);
      return (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw _mapRpcException(e);
    }
  }

  Future<String> createJobAttachmentSignedUrl(String storagePath) {
    return _supabase.storage.from('job-evidence').createSignedUrl(storagePath, 900);
  }

  Future<Map<String, dynamic>?> getFinancialSnapshotForJob(String jobId) async {
    try {
      final response = await _supabase
          .from('job_financial_snapshots')
          .select()
          .eq('job_id', jobId)
          .eq('is_current', true)
          .maybeSingle();

      if (response == null) return null;
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      throw _mapRpcException(e);
    }
  }


  Future<Map<String, dynamic>> startRoute({
    required String jobId,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    double? accuracy,
  }) async {
    try {
      final response = await _supabase.rpc(
        'start_route',
        params: {
          'p_job_id': jobId,
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_heading': heading,
          'p_speed': speed,
          'p_accuracy': accuracy,
        },
      );
      return _asMap(response);
    } on PostgrestException catch (e) {
      throw _mapRpcException(e);
    }
  }

  Future<Map<String, dynamic>> updateLiveLocation({
    required String jobId,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    double? accuracy,
  }) async {
    try {
      final response = await _supabase.rpc(
        'update_live_location',
        params: {
          'p_job_id': jobId,
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_heading': heading,
          'p_speed': speed,
          'p_accuracy': accuracy,
        },
      );
      return _asMap(response);
    } on PostgrestException catch (e) {
      throw _mapRpcException(e);
    }
  }

  Future<Map<String, dynamic>> markArrived(String jobId) async {
    try {
      final response = await _supabase.rpc(
        'mark_arrived',
        params: {'p_job_id': jobId},
      );
      return _asMap(response);
    } on PostgrestException catch (e) {
      throw _mapRpcException(e);
    }
  }

  Future<Map<String, dynamic>> startJob(String jobId) async {
    try {
      final response = await _supabase.rpc(
        'start_job',
        params: {'p_job_id': jobId},
      );

      return _asMap(response);
    } on PostgrestException catch (e) {
      throw _mapRpcException(e);
    } catch (e) {
      if (e is JobActionException) rethrow;
      throw const JobActionException(
        JobActionErrorCode.unknown,
        'No fue posible iniciar el servicio.',
      );
    }
  }

  Future<Map<String, dynamic>> finishJob(String jobId) async {
    try {
      final response = await _supabase.rpc(
        'finish_job',
        params: {'p_job_id': jobId},
      );

      return _asMap(response);
    } on PostgrestException catch (e) {
      throw _mapRpcException(e);
    } catch (e) {
      if (e is JobActionException) rethrow;
      throw const JobActionException(
        JobActionErrorCode.unknown,
        'No fue posible finalizar el trabajo.',
      );
    }
  }

  Map<String, dynamic> _asMap(dynamic response) {
    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);
    throw const JobActionException(
      JobActionErrorCode.unknown,
      'El servidor devolvió una respuesta inesperada.',
    );
  }

  String? _nullIfBlank(String? value) {
    final normalized = value?.trim();
    return (normalized == null || normalized.isEmpty) ? null : normalized;
  }

  JobActionException _mapRpcException(PostgrestException error) {
    final message = error.message.toUpperCase();

    if (message.contains('AUTHENTICATION_REQUIRED')) {
      return const JobActionException(
        JobActionErrorCode.authenticationRequired,
        'Tu sesión expiró. Vuelve a iniciar sesión.',
      );
    }
    if (message.contains('PROFILE_NOT_FOUND')) {
      return const JobActionException(
        JobActionErrorCode.profileNotFound,
        'No encontramos tu perfil profesional.',
      );
    }
    if (message.contains('NOT_A_PROFESSIONAL')) {
      return const JobActionException(
        JobActionErrorCode.notProfessional,
        'Esta cuenta no está registrada como FIXI.',
      );
    }
    if (message.contains('PROFESSIONAL_NOT_APPROVED')) {
      return const JobActionException(
        JobActionErrorCode.professionalNotApproved,
        'Tu perfil todavía no está aprobado.',
      );
    }
    if (message.contains('ACCOUNT_NOT_ACTIVE')) {
      return const JobActionException(
        JobActionErrorCode.accountNotActive,
        'Tu cuenta no está activa para operar.',
      );
    }
    if (message.contains('JOB_NOT_FOUND')) {
      return const JobActionException(
        JobActionErrorCode.jobNotFound,
        'El trabajo ya no existe.',
      );
    }
    if (message.contains('JOB_ALREADY_TAKEN')) {
      return const JobActionException(
        JobActionErrorCode.jobAlreadyTaken,
        'Otro FIXI ya tomó este trabajo.',
      );
    }
    if (message.contains('PROFESSIONAL_NOT_AVAILABLE')) {
      return const JobActionException(
        JobActionErrorCode.professionalNotAvailable,
        'Activa tu disponibilidad para recibir oportunidades.',
      );
    }
    if (message.contains('PROFESSIONAL_LOCATION_REQUIRED') ||
        message.contains('LOCATION_REQUIRED')) {
      return const JobActionException(
        JobActionErrorCode.professionalLocationRequired,
        'Necesitamos tu ubicación para activar el radar.',
      );
    }
    if (message.contains('CATEGORY_NOT_MATCHED')) {
      return const JobActionException(
        JobActionErrorCode.categoryNotMatched,
        'Esta oportunidad no coincide con tu categoría profesional.',
      );
    }
    if (message.contains('JOB_OUTSIDE_SERVICE_RADIUS')) {
      return const JobActionException(
        JobActionErrorCode.jobOutsideServiceRadius,
        'La oportunidad está fuera de tu radio de servicio.',
      );
    }
    if (message.contains('JOB_ALREADY_ASSIGNED')) {
      return const JobActionException(
        JobActionErrorCode.jobAlreadyAssigned,
        'Otro FIXI ya aceptó esta oportunidad.',
      );
    }
    if (message.contains('JOB_NOT_ASSIGNED_TO_PROFESSIONAL') ||
        message.contains('JOB_NOT_ASSIGNED')) {
      return const JobActionException(
        JobActionErrorCode.jobNotAssigned,
        'Este trabajo no está asignado a tu cuenta.',
      );
    }
    if (message.contains('QUOTE_NOT_FOUND')) {
      return const JobActionException(
        JobActionErrorCode.quoteNotFound,
        'No encontramos la cotización.',
      );
    }
    if (message.contains('QUOTE_NOT_OWNED_BY_USER')) {
      return const JobActionException(
        JobActionErrorCode.quoteNotOwnedByUser,
        'Esta cotización no pertenece a tu cuenta.',
      );
    }
    if (message.contains('INVALID_QUOTE_STATE')) {
      return const JobActionException(
        JobActionErrorCode.invalidQuoteState,
        'La cotización ya no puede modificarse o enviarse.',
      );
    }
    if (message.contains('INVALID_QUOTE_AMOUNT')) {
      return const JobActionException(
        JobActionErrorCode.invalidQuoteAmount,
        'Los valores de la cotización no son válidos.',
      );
    }
    if (message.contains('QUOTE_TOTAL_MUST_BE_POSITIVE')) {
      return const JobActionException(
        JobActionErrorCode.quoteTotalMustBePositive,
        'El total de la cotización debe ser mayor que cero.',
      );
    }
    if (message.contains('ACCEPTED_QUOTE_REQUIRED')) {
      return const JobActionException(
        JobActionErrorCode.acceptedQuoteRequired,
        'El servicio necesita una cotización aceptada antes de iniciar.',
      );
    }
    if (message.contains('FINANCIAL_SNAPSHOT_REQUIRED')) {
      return const JobActionException(
        JobActionErrorCode.financialSnapshotRequired,
        'No existe el snapshot financiero requerido para iniciar el servicio.',
      );
    }
    if (message.contains('PROFESSIONAL_MUST_ARRIVE_FIRST')) {
      return const JobActionException(
        JobActionErrorCode.invalidJobState,
        'Primero debes marcar que llegaste al lugar del servicio.',
      );
    }
    if (message.contains('JOB_NOT_EN_ROUTE')) {
      return const JobActionException(
        JobActionErrorCode.invalidJobState,
        'El servicio ya no está en estado En camino.',
      );
    }
    if (message.contains('CLIENT_REQUIRED_FOR_LIVE_TRACKING')) {
      return const JobActionException(
        JobActionErrorCode.invalidJobState,
        'Este trabajo no tiene un cliente asociado para compartir ubicación.',
      );
    }
    if (message.contains('LIVE_LOCATION_NOT_FOUND')) {
      return const JobActionException(
        JobActionErrorCode.liveLocationNotFound,
        'Necesitamos una ubicación reciente antes de registrar tu llegada.',
      );
    }
    if (message.contains('LIVE_LOCATION_STALE')) {
      return const JobActionException(
        JobActionErrorCode.liveLocationStale,
        'Tu ubicación está desactualizada. Espera unos segundos e intenta otra vez.',
      );
    }
    if (message.contains('LOCATION_ACCURACY_TOO_LOW')) {
      return const JobActionException(
        JobActionErrorCode.locationAccuracyTooLow,
        'La precisión del GPS es insuficiente. Acércate al lugar y vuelve a intentar.',
      );
    }
    if (message.contains('ARRIVAL_TOO_FAR')) {
      return const JobActionException(
        JobActionErrorCode.arrivalTooFar,
        'Aún estás demasiado lejos de la ubicación del servicio para registrar la llegada.',
      );
    }
    if (message.contains('SERVICE_LOCATION_REQUIRED')) {
      return const JobActionException(
        JobActionErrorCode.serviceLocationRequired,
        'Este servicio no tiene una ubicación válida para verificar la llegada.',
      );
    }
    if (message.contains('QUOTE_REVISION_ALREADY_PENDING')) {
      return const JobActionException(
        JobActionErrorCode.invalidQuoteState,
        'Ya existe una revisión pendiente de respuesta del cliente.',
      );
    }
    if (message.contains('QUOTE_REVISION_ONLY_AFTER_ARRIVAL')) {
      return const JobActionException(
        JobActionErrorCode.invalidJobState,
        'Solo puedes revisar la cotización después de registrar tu llegada.',
      );
    }
    if (message.contains('REVISION_REASON_REQUIRED')) {
      return const JobActionException(
        JobActionErrorCode.invalidQuoteState,
        'Explica brevemente por qué cambió el alcance del trabajo.',
      );
    }
    if (message.contains('QUOTE_REVISION_PAYMENT_ALREADY_EXISTS') ||
        message.contains('QUOTE_REVISION_LEDGER_ALREADY_EXISTS')) {
      return const JobActionException(
        JobActionErrorCode.invalidQuoteState,
        'Este servicio ya tiene movimiento financiero y no puede revisarse.',
      );
    }
    if (message.contains('QUOTE_REVISION_PENDING')) {
      return const JobActionException(
        JobActionErrorCode.invalidJobState,
        'Espera la respuesta del cliente a la cotización revisada.',
      );
    }
    if (message.contains('INVALID_JOB_STATE')) {
      return const JobActionException(
        JobActionErrorCode.invalidJobState,
        'El trabajo no se encuentra en un estado válido para esta operación.',
      );
    }

    return JobActionException(
      JobActionErrorCode.unknown,
      'Error de servidor: ${error.message}',
    );
  }
}

