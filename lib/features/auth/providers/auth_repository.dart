// FIXIS PRO v1.1.1 - Fast Auth Gate + control de acceso profesional
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

enum ProfessionalAccessStatus {
  allowed,
  unauthenticated,
  profileNotFound,
  notProfessional,
  pendingVerification,
  rejectedVerification,
  suspended,
  blocked,
  unknown,
}

class ProfessionalAccessDecision {
  final ProfessionalAccessStatus status;
  final Map<String, dynamic>? profile;

  const ProfessionalAccessDecision({
    required this.status,
    this.profile,
  });

  bool get isAllowed => status == ProfessionalAccessStatus.allowed;
}

class AuthFlowException implements Exception {
  final String message;
  final String? code;
  final bool deliveryUncertain;

  const AuthFlowException(
    this.message, {
    this.code,
    this.deliveryUncertain = false,
  });

  @override
  String toString() => message;
}

class AuthRepository {
  final SupabaseClient _supabase;

  Map<String, dynamic>? _cachedAccessProfile;
  ProfessionalAccessDecision? _cachedAccessDecision;
  String? _cachedAccessUserId;

  AuthRepository(this._supabase);

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;

  void clearAccessCache() {
    _cachedAccessProfile = null;
    _cachedAccessDecision = null;
    _cachedAccessUserId = null;
  }

  String normalizeEmail(String email) => email.trim().toLowerCase();

  Future<void> sendOtp(String email) async {
    final normalizedEmail = normalizeEmail(email);
    final stopwatch = Stopwatch()..start();

    try {
      clearAccessCache();
      await _supabase.auth.signInWithOtp(
        email: normalizedEmail,
        shouldCreateUser: false,
      );
      stopwatch.stop();
      debugPrint(
        '[AUTH] OTP requested successfully in ${stopwatch.elapsedMilliseconds} ms '
        'for ${_maskEmail(normalizedEmail)}',
      );
    } on AuthException catch (e) {
      stopwatch.stop();
      _logAuthFailure('sendOtp', e, stopwatch.elapsedMilliseconds);
      throw AuthFlowException(
        e.code == 'otp_disabled'
            ? 'No pudimos enviar el código. Revisa que el correo sea el de tu cuenta; si aún no tienes una, usa Crear cuenta cliente.'
            : _friendlyAuthMessage(e),
        code: e.code,
        deliveryUncertain: _isDeliveryUncertain(e),
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('[AUTH] sendOtp unexpected error after ${stopwatch.elapsedMilliseconds} ms: $e');
      throw const AuthFlowException(
        'No pudimos confirmar el envío. Si llega un código, introdúcelo; si no, solicita otro después de 60 segundos.',
        deliveryUncertain: true,
      );
    }
  }

  Future<void> sendCustomerSignupOtp({
    required String email,
    required String fullName,
    String? phone,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    final stopwatch = Stopwatch()..start();

    try {
      clearAccessCache();
      await _supabase.auth.signInWithOtp(
        email: normalizedEmail,
        shouldCreateUser: true,
        data: {
          'full_name': fullName.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        },
      );
      stopwatch.stop();
      debugPrint(
        '[AUTH] Customer OTP requested successfully in ${stopwatch.elapsedMilliseconds} ms '
        'for ${_maskEmail(normalizedEmail)}',
      );
    } on AuthException catch (e) {
      stopwatch.stop();
      _logAuthFailure('sendCustomerSignupOtp', e, stopwatch.elapsedMilliseconds);
      throw AuthFlowException(
        _friendlyAuthMessage(e),
        code: e.code,
        deliveryUncertain: _isDeliveryUncertain(e),
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('[AUTH] sendCustomerSignupOtp unexpected error after ${stopwatch.elapsedMilliseconds} ms: $e');
      throw const AuthFlowException(
        'No pudimos confirmar el envío. Si llega un código, introdúcelo; si no, solicita otro después de 60 segundos.',
        deliveryUncertain: true,
      );
    }
  }

  Future<AuthResponse> verifyOtp(String email, String code) async {
    final normalizedEmail = normalizeEmail(email);
    final normalizedCode = code.trim();
    final stopwatch = Stopwatch()..start();

    try {
      clearAccessCache();
      final response = await _supabase.auth.verifyOTP(
        type: OtpType.email,
        email: normalizedEmail,
        token: normalizedCode,
      );
      stopwatch.stop();
      debugPrint(
        '[AUTH] OTP verified successfully in ${stopwatch.elapsedMilliseconds} ms '
        'for ${_maskEmail(normalizedEmail)}',
      );
      return response;
    } on AuthException catch (e) {
      stopwatch.stop();
      _logAuthFailure('verifyOtp', e, stopwatch.elapsedMilliseconds);
      throw AuthFlowException(_friendlyAuthMessage(e), code: e.code);
    } catch (e) {
      stopwatch.stop();
      debugPrint('[AUTH] verifyOtp unexpected error after ${stopwatch.elapsedMilliseconds} ms: $e');
      throw const AuthFlowException(
        'No fue posible verificar el código. Inténtalo nuevamente.',
      );
    }
  }

  void _logAuthFailure(String operation, AuthException error, int elapsedMs) {
    debugPrint(
      '[AUTH] $operation failed after $elapsedMs ms '
      'status=${error.statusCode ?? '-'} code=${error.code ?? '-'} '
      'message=${error.message}',
    );
  }

  bool _isDeliveryUncertain(AuthException error) {
    final message = error.message.toLowerCase();
    return error.statusCode?.toString() == '504' ||
        error.code == 'request_timeout' ||
        message.contains('upstream request timeout') ||
        message.contains('gateway timeout');
  }

  String _friendlyAuthMessage(AuthException error) {
    final code = (error.code ?? '').toLowerCase();
    final message = error.message.toLowerCase();

    if (code == 'otp_expired' || message.contains('expired')) {
      return 'Este código expiró. Solicita uno nuevo y usa únicamente el correo más reciente.';
    }
    if (code == 'otp_disabled') {
      return 'No se pudo solicitar el código. El servicio de acceso por correo no está disponible en este momento.';
    }
    if (_isDeliveryUncertain(error)) {
      return 'El servicio de correo está tardando más de lo esperado. '
          'El código todavía puede llegar. Espera al menos 60 segundos '
          'y usa únicamente el correo más reciente antes de solicitar otro.';
    }
    if (code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        message.contains('rate limit')) {
      return 'Has solicitado varios códigos. Espera un momento antes de volver a intentarlo.';
    }
    if (code == 'user_not_found') {
      return 'No encontramos una cuenta asociada a este correo.';
    }
    if (code == 'email_not_confirmed') {
      return 'Este correo todavía no está confirmado.';
    }
    if (code == 'invalid_credentials' ||
        message.contains('invalid') ||
        message.contains('token')) {
      return 'El código no es válido. Si solicitaste otro código, usa únicamente el más reciente.';
    }

    return 'No fue posible completar la autenticación. Inténtalo nuevamente.';
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts.first.isEmpty) return '***';
    final local = parts.first;
    final visible = local.length <= 2 ? local.substring(0, 1) : local.substring(0, 2);
    return '$visible***@${parts.last}';
  }

  Future<void> signOut() async {
    clearAccessCache();
    await _supabase.auth.signOut();
  }

  /// Consulta mínima utilizada únicamente por el Auth Gate.
  /// Evita descargar el perfil financiero/operativo completo durante el login.
  Future<Map<String, dynamic>?> getAccessProfile({bool forceRefresh = false}) async {
    final user = currentUser;
    if (user == null) return null;

    if (!forceRefresh &&
        _cachedAccessProfile != null &&
        _cachedAccessUserId == user.id) {
      return _cachedAccessProfile;
    }

    try {
      // Keep the Auth Gate query intentionally minimal.
      // Do not request presentation/profile fields that are not required
      // to decide access.
      final profile = await _supabase
          .from('profiles')
          .select(
            'id, role, verification_status, account_status',
          )
          .eq('id', user.id)
          .maybeSingle();

      _cachedAccessProfile = profile;
      _cachedAccessUserId = user.id;

      debugPrint(
        '[AUTH] access profile loaded '
        'user=${user.id} '
        'role=${profile?['role']} '
        'account=${profile?['account_status']} '
        'verification=${profile?['verification_status']}',
      );

      return profile;
    } on PostgrestException catch (e) {
      debugPrint(
        '[AUTH] getAccessProfile PostgREST error '
        'code=${e.code} message=${e.message} details=${e.details}',
      );
      rethrow;
    } catch (e) {
      debugPrint('[AUTH] getAccessProfile unexpected error: $e');
      rethrow;
    }
  }

  /// Perfil completo. Se usa en pantallas que realmente necesitan esos datos,
  /// no en la puerta de entrada de la aplicación.
  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      return await _supabase
          .from('profiles')
          .select(
            'id, full_name, category, phone, rating, total_jobs, email, '
            'avatar_url, city, experience, bank, account_type, account_number, '
            'bio, role, verification_status, account_status, created_at',
          )
          .eq('id', user.id)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Future<ProfessionalAccessDecision> evaluateProfessionalAccess({
    bool forceRefresh = false,
  }) async {
    final user = currentUser;

    if (currentSession == null || user == null) {
      clearAccessCache();
      return const ProfessionalAccessDecision(
        status: ProfessionalAccessStatus.unauthenticated,
      );
    }

    if (!forceRefresh &&
        _cachedAccessDecision != null &&
        _cachedAccessUserId == user.id) {
      return _cachedAccessDecision!;
    }

    final profile = await getAccessProfile(forceRefresh: forceRefresh);

    late final ProfessionalAccessDecision decision;

    if (profile == null) {
      decision = const ProfessionalAccessDecision(
        status: ProfessionalAccessStatus.profileNotFound,
      );
    } else if (profile['role'] != 'professional') {
      decision = ProfessionalAccessDecision(
        status: ProfessionalAccessStatus.notProfessional,
        profile: profile,
      );
    } else {
      switch (profile['verification_status']) {
        case 'approved':
          break;
        case 'pending':
          decision = ProfessionalAccessDecision(
            status: ProfessionalAccessStatus.pendingVerification,
            profile: profile,
          );
          _cachedAccessDecision = decision;
          return decision;
        case 'rejected':
          decision = ProfessionalAccessDecision(
            status: ProfessionalAccessStatus.rejectedVerification,
            profile: profile,
          );
          _cachedAccessDecision = decision;
          return decision;
        default:
          decision = ProfessionalAccessDecision(
            status: ProfessionalAccessStatus.unknown,
            profile: profile,
          );
          _cachedAccessDecision = decision;
          return decision;
      }

      switch (profile['account_status']) {
        case 'active':
          decision = ProfessionalAccessDecision(
            status: ProfessionalAccessStatus.allowed,
            profile: profile,
          );
          break;
        case 'suspended':
          decision = ProfessionalAccessDecision(
            status: ProfessionalAccessStatus.suspended,
            profile: profile,
          );
          break;
        case 'blocked':
          decision = ProfessionalAccessDecision(
            status: ProfessionalAccessStatus.blocked,
            profile: profile,
          );
          break;
        default:
          decision = ProfessionalAccessDecision(
            status: ProfessionalAccessStatus.unknown,
            profile: profile,
          );
      }
    }

    _cachedAccessDecision = decision;
    return decision;
  }
}

final userProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getUserProfile();
});

// v1.1.1: ya no es autoDispose. La decisión de acceso se conserva durante
// la sesión para evitar consultas repetidas al volver al Auth Gate.
final professionalAccessProvider =
    FutureProvider<ProfessionalAccessDecision>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.evaluateProfessionalAccess();
});


enum AppAccessType { unauthenticated, professional, customer, admin, restricted }

class AppAccessDecision {
  final AppAccessType type;
  final Map<String, dynamic>? profile;
  const AppAccessDecision(this.type, {this.profile});
}

final appAccessProvider = FutureProvider<AppAccessDecision>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  final user = repo.currentUser;
  if (repo.currentSession == null || user == null) {
    return const AppAccessDecision(AppAccessType.unauthenticated);
  }

  final profile = await repo.getAccessProfile(forceRefresh: true);
  if (profile == null) {
    debugPrint('[AUTH] access restricted: profile not found for ${user.id}');
    return const AppAccessDecision(AppAccessType.restricted);
  }

  final role = profile['role']?.toString();
  final account = profile['account_status']?.toString();
  final verification = profile['verification_status']?.toString();

  debugPrint(
    '[AUTH] evaluating access '
    'user=${user.id} role=$role account=$account verification=$verification',
  );

  if (account != 'active') {
    return AppAccessDecision(AppAccessType.restricted, profile: profile);
  }

  if (role == 'customer') {
    return AppAccessDecision(AppAccessType.customer, profile: profile);
  }

  if (role == 'admin') {
    return AppAccessDecision(AppAccessType.admin, profile: profile);
  }

  if (role == 'professional' && verification == 'approved') {
    return AppAccessDecision(AppAccessType.professional, profile: profile);
  }

  return AppAccessDecision(AppAccessType.restricted, profile: profile);
});
